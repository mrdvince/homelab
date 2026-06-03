#!/usr/bin/env bash
set -euo pipefail

env_name="${ENV_NAME:-aion}"
output_dir="${RENDERED_MANIFEST_DIR:-/tmp/rendered-manifests}"
rendered_image_list="${RENDERED_IMAGE_LIST:-imagelist.txt}"
child_pipeline_file="${CHILD_PIPELINE_FILE:-rendered-pipeline.yml}"
rendered_template="${RENDERED_TEMPLATE:-ci/includes/imagegate.yml}"
dest_registry="${DEST_REGISTRY:-registry.home.mrdvince.me}"
map_dir="${IMAGE_MAP_DIR:-infrastructure/images/images}"
build_dir="${IMAGE_BUILD_DIR:-infrastructure/images/builds}"
severity_threshold="${SEVERITY_THRESHOLD:-CRITICAL,HIGH}"
scan_images="${SCAN_IMAGES:-true}"
sync_images="${SYNC_IMAGES:-true}"
fail_on_vulnerabilities="${FAIL_ON_IMAGE_VULNERABILITIES:-false}"
allow_upstream_rendered_images="${ALLOW_UPSTREAM_RENDERED_IMAGES:-false}"
registry_map=""
local_image_map=""
image_ref_map=""
scan_failure_list=""

usage() {
  cat <<'EOF'
usage: ci/mirror.sh [run|render|images|sync|sync-one|pipeline]

environment overrides:
  ENV_NAME                         helmfile environment, default: aion
  HELMFILE_PATHS                   optional space-separated helmfiles to render
  RENDERED_MANIFEST_DIR            rendered manifest output directory
  RENDERED_IMAGE_LIST              extracted image list path
  CHILD_PIPELINE_FILE              generated rendered image child pipeline path
  RENDERED_TEMPLATE                generated child pipeline include path
  DEST_REGISTRY                    required rendered image registry
  IMAGE_MAP_DIR                    yaml registry mapping directory
  IMAGE_BUILD_DIR                  yaml local build mapping directory
  SCAN_IMAGES                      true/false, run trivy before sync
  SYNC_IMAGES                      true/false, copy images to DEST_REGISTRY
  FAIL_ON_IMAGE_VULNERABILITIES    true/false, fail on high/critical findings
  ALLOW_UPSTREAM_RENDERED_IMAGES   true/false, permit rendered upstream images
EOF
}

load_helmfiles() {
  if [ -n "${HELMFILE_PATHS:-}" ]; then
    read -r -a helmfiles <<<"${HELMFILE_PATHS}"
  else
    mapfile -t helmfiles < <(find apps -name 'helmfile.yaml.gotmpl' -print | sort)
  fi
}

render_helmfiles() {
  local helmfiles=()
  local helmfile_path output_name output_path

  mkdir -p "${output_dir}"
  load_helmfiles

  if [ "${#helmfiles[@]}" -eq 0 ]; then
    echo "no helmfiles found" >&2
    exit 1
  fi

  for helmfile_path in "${helmfiles[@]}"; do
    if [ ! -f "${helmfile_path}" ]; then
      echo "helmfile not found: ${helmfile_path}" >&2
      exit 1
    fi

    output_name="${helmfile_path//\//__}.yaml"
    output_path="${output_dir}/${output_name}"

    echo "rendering ${helmfile_path}"
    helmfile -f "${helmfile_path}" -e "${env_name}" list --skip-charts --output json \
      | yq -r '.[] | "release \(.namespace)/\(.name): \(.chart)@\(.version)"'
    helmfile -f "${helmfile_path}" -e "${env_name}" repos >/dev/null
    helmfile -f "${helmfile_path}" -e "${env_name}" template --include-crds --skip-tests -q >"${output_path}"
  done
}

extract_images() {
  local rendered_files=()

  mapfile -t rendered_files < <(find "${output_dir}" -maxdepth 1 -type f -name '*.yaml' -print | sort)

  if [ "${#rendered_files[@]}" -eq 0 ]; then
    echo "no rendered manifests found in ${output_dir}" >&2
    exit 1
  fi

  yq -N -r '.. | select(tag == "!!map" and has("image")) | .image | select(tag == "!!str") | select(test("^[^[:space:]]+$"))' "${rendered_files[@]}" \
    | sed '/^$/d' \
    | sort -u >"${rendered_image_list}"

  if [ ! -s "${rendered_image_list}" ]; then
    echo "no rendered images found" >&2
    exit 1
  fi
}

build_registry_map() {
  local map_file build_file

  registry_map="$(mktemp)"
  local_image_map="$(mktemp)"
  trap 'rm -f "${registry_map}" "${local_image_map}" "${image_ref_map:-}" "${scan_failure_list:-}"' EXIT

  for map_file in "${map_dir}"/*.yaml; do
    [ -f "${map_file}" ] || continue
    yq -r '.. | select(tag == "!!map" and has("registry") and has("image")) | select(.registry != null and .image != null) | [.image, .registry] | @tsv' "${map_file}"
  done | sort -u >"${registry_map}"

  for map_file in "${map_dir}"/*.yaml; do
    [ -f "${map_file}" ] || continue
    yq -r '.. | select(tag == "!!map" and has("image")) | select(.image != null) | select((has("registry") | not) or .registry == null) | .image' "${map_file}"
  done >"${local_image_map}"

  for build_file in "${build_dir}"/*.yaml; do
    [ -f "${build_file}" ] || continue
    yq -r '.. | select(tag == "!!map" and has("image")) | select(.image != null) | .image' "${build_file}"
  done >>"${local_image_map}"

  sort -u "${local_image_map}" -o "${local_image_map}"

  if [ ! -s "${registry_map}" ]; then
    echo "no image registry mappings found in ${map_dir}" >&2
    exit 1
  fi
}

lookup_registry() {
  local repository="$1"

  awk -v repository="${repository}" '
    BEGIN { FS = "\t" }
    $1 == repository { print $2; found = 1; exit }
    END { if (!found) exit 1 }
  ' "${registry_map}"
}

is_local_image() {
  local repository="$1"

  grep -Fxq "${repository}" "${local_image_map}"
}

normalize_ref() {
  local image="$1"
  local image_without_registry repository reference source_registry

  if [[ "${image}" != "${dest_registry}/"* ]]; then
    if [ "${allow_upstream_rendered_images}" = "true" ]; then
      echo "${image}"
      return
    fi

    echo "rendered image does not use ${dest_registry}: ${image}" >&2
    exit 1
  fi

  image_without_registry="${image#${dest_registry}/}"

  if [[ "${image_without_registry}" == *@* ]]; then
    repository="${image_without_registry%@*}"
    reference="@${image_without_registry#*@}"
  elif [[ "${image_without_registry}" == *:* ]]; then
    repository="${image_without_registry%:*}"
    reference=":${image_without_registry##*:}"
  else
    repository="${image_without_registry}"
    reference=":latest"
  fi

  source_registry="$(lookup_registry "${repository}")" || {
    if is_local_image "${repository}"; then
      echo "${image}"
      return
    fi

    echo "no upstream registry mapping for rendered image repository: ${repository}" >&2
    echo "add ${repository} to ${map_dir} with its upstream registry" >&2
    exit 1
  }

  echo "${source_registry}/${repository}${reference}"
}

vulnerability_gate_enabled() {
  local pipeline_source

  pipeline_source="${CI_PIPELINE_SOURCE:-${PARENT_PIPELINE_SOURCE:-}}"
  [ "${fail_on_vulnerabilities}" = "true" ] || [ "${pipeline_source}" = "merge_request_event" ]
}

prepare_image_refs() {
  local rendered_image source_image

  image_ref_map="$(mktemp)"

  while IFS= read -r rendered_image; do
    [ -n "${rendered_image}" ] || continue
    source_image="$(normalize_ref "${rendered_image}")"
    printf '%s\t%s\n' "${rendered_image}" "${source_image}" >>"${image_ref_map}"
  done <"${rendered_image_list}"

  if [ ! -s "${image_ref_map}" ]; then
    echo "no image refs prepared" >&2
    exit 1
  fi
}

scan_image_refs() {
  local source_image scan_failed

  if [ "${scan_images}" != "true" ]; then
    return
  fi

  scan_failed="false"
  scan_failure_list="$(mktemp)"

  while IFS= read -r source_image; do
    [ -n "${source_image}" ] || continue

    echo "scanning ${source_image}"
    if ! trivy image --exit-code 1 --severity "${severity_threshold}" "${source_image}"; then
      echo "warning: critical/high vulnerabilities or scan errors found in ${source_image}"
      printf '%s\n' "${source_image}" >>"${scan_failure_list}"
      scan_failed="true"
    fi
  done < <(cut -f2 "${image_ref_map}" | sort -u)

  if [ "${scan_failed}" != "true" ]; then
    return
  fi

  echo "rendered image scan found problems in these source images:" >&2
  sed 's/^/- /' "${scan_failure_list}" >&2

  if vulnerability_gate_enabled; then
    echo "failing rendered image mirror because vulnerability gating is enabled" >&2
    exit 1
  fi

  echo "continuing anyway - review recommended" >&2
}

sync_image_ref() {
  local rendered_image="$1"
  local source_image="$2"
  local source_ref dest_ref

  if [ "${sync_images}" != "true" ]; then
    return
  fi

  source_ref="docker://${source_image}"
  dest_ref="docker://${rendered_image}"

  if [ "${source_image}" = "${rendered_image}" ]; then
    if skopeo inspect --raw "${dest_ref}" >/dev/null 2>&1; then
      echo "skipping ${rendered_image} - local build already exists in registry"
      return
    fi

    echo "rendered image ${rendered_image} is built locally but is missing from registry" >&2
    echo "run the image build pipeline for this image before rendered image sync" >&2
    exit 1
  fi

  if skopeo inspect --raw "${dest_ref}" >/dev/null 2>&1; then
    echo "skipping ${rendered_image} - already exists in registry"
    return
  fi

  echo "syncing ${source_ref} -> ${dest_ref}"
  skopeo copy --all "${source_ref}" "${dest_ref}"
}

yaml_quote() {
  local value="$1"

  printf "'%s'" "${value//\'/\'\'}"
}

job_name_for_image() {
  local index="$1"
  local image="$2"
  local normalized

  normalized="$(printf '%s' "${image}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' \
    | cut -c1-70)"

  printf 'image-%03d-%s' "${index}" "${normalized}"
}

write_pipeline_header() {
  cat >"${child_pipeline_file}" <<EOF
include:
  - local: ${rendered_template}

stages:
  - scan
  - sync
EOF
}

append_scan_job() {
  local job_name="$1"
  local source_image="$2"

  cat >>"${child_pipeline_file}" <<EOF

scan-${job_name}:
  stage: scan
  extends: .rendered-image-scan
  variables:
    SOURCE_IMAGE: $(yaml_quote "${source_image}")
EOF
}

append_sync_job() {
  local job_name="$1"
  local rendered_image="$2"
  local source_image="$3"

  cat >>"${child_pipeline_file}" <<EOF

sync-${job_name}:
  stage: sync
  extends: .rendered-image-sync
  needs:
    - job: scan-${job_name}
  variables:
    SOURCE_IMAGE: $(yaml_quote "${source_image}")
    RENDERED_IMAGE: $(yaml_quote "${rendered_image}")
EOF
}

generate_pipeline() {
  local rendered_image source_image job_name index

  build_registry_map
  prepare_image_refs
  write_pipeline_header

  index=0
  while IFS=$'\t' read -r rendered_image source_image; do
    index=$((index + 1))
    job_name="$(job_name_for_image "${index}" "${rendered_image}")"
    append_scan_job "${job_name}" "${source_image}"

    if [ "${sync_images}" = "true" ]; then
      append_sync_job "${job_name}" "${rendered_image}" "${source_image}"
    fi
  done <"${image_ref_map}"

  echo "generated rendered image child pipeline:"
  cat "${child_pipeline_file}"
}

mirror_images() {
  local rendered_image source_image

  build_registry_map
  prepare_image_refs
  scan_image_refs

  if [ "${sync_images}" = "true" ]; then
    printf '%s' "${REGISTRY_PASSWORD}" | skopeo login -u "${REGISTRY_USER}" --password-stdin "${dest_registry}"
  fi

  while IFS=$'\t' read -r rendered_image source_image; do
    sync_image_ref "${rendered_image}" "${source_image}"
  done <"${image_ref_map}"
}

sync_one_image() {
  local rendered_image source_image

  rendered_image="${RENDERED_IMAGE:-}"
  source_image="${SOURCE_IMAGE:-}"

  if [ -z "${rendered_image}" ]; then
    echo "RENDERED_IMAGE is required" >&2
    exit 1
  fi

  if [ -z "${source_image}" ]; then
    echo "SOURCE_IMAGE is required" >&2
    exit 1
  fi

  sync_images="true"
  sync_image_ref "${rendered_image}" "${source_image}"
}

run_all() {
  render_helmfiles
  extract_images
  mirror_images
}

run_pipeline() {
  render_helmfiles
  extract_images
  generate_pipeline
}

case "${1:-run}" in
  run)
    run_all
    ;;
  render)
    render_helmfiles
    ;;
  images)
    extract_images
    ;;
  sync)
    mirror_images
    ;;
  sync-one)
    sync_one_image
    ;;
  pipeline)
    run_pipeline
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
