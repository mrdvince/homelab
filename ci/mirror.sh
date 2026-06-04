#!/usr/bin/env bash
set -euo pipefail

env_name="${ENV_NAME:-aion}"
output_dir="${RENDERED_MANIFEST_DIR:-/tmp/rendered-manifests}"
rendered_image_list="${RENDERED_IMAGE_LIST:-imagelist.txt}"
child_pipeline_file="${CHILD_PIPELINE_FILE:-rendered-pipeline.yml}"
rendered_template="${RENDERED_TEMPLATE:-ci/includes/imagegate.yml}"
parent_pipeline_source="${PARENT_PIPELINE_SOURCE:-${CI_PIPELINE_SOURCE:-}}"
dest_registry="${DEST_REGISTRY:-registry.home.mrdvince.me}"
map_dir="${IMAGE_MAP_DIR:-infrastructure/images/images}"
build_dir="${IMAGE_BUILD_DIR:-infrastructure/images/builds}"
severity_threshold="${SEVERITY_THRESHOLD:-CRITICAL,HIGH}"
trivy_report="${TRIVY_REPORT:-trivy-report.json}"
trivy_error_log="${TRIVY_ERROR_LOG:-trivy-error.log}"
trivy_summary_limit="${TRIVY_SUMMARY_LIMIT:-25}"
trivy_timeout="${TRIVY_TIMEOUT:-20m}"
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
usage: ci/mirror.sh [run|render|images|scan-one|sync|sync-one|pipeline]

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
  TRIVY_REPORT                     per-image json report path, default: trivy-report.json
  TRIVY_ERROR_LOG                  per-image trivy stderr path, default: trivy-error.log
  TRIVY_SUMMARY_LIMIT              max findings printed in scan-one logs, default: 25
  TRIVY_TIMEOUT                    per-image trivy timeout, default: 20m
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

  while IFS= read -r map_file; do
    [ -f "${map_file}" ] || continue
    yq -r '.. | select(tag == "!!map" and has("registry") and has("image")) | select(.registry != null and .image != null) | [.image, .registry] | @tsv' "${map_file}"
  done < <(find "${map_dir}" -type f -name '*.yaml' -print | sort) | sort -u >"${registry_map}"

  while IFS= read -r map_file; do
    [ -f "${map_file}" ] || continue
    yq -r '.. | select(tag == "!!map" and has("image")) | select(.image != null) | select((has("registry") | not) or .registry == null) | .image' "${map_file}"
  done < <(find "${map_dir}" -type f -name '*.yaml' -print | sort) >"${local_image_map}"

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
  local image_without_registry image_without_digest repository reference digest source_registry

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
    image_without_digest="${image_without_registry%@*}"
    digest="@${image_without_registry#*@}"
  else
    image_without_digest="${image_without_registry}"
    digest=""
  fi

  if [[ "${image_without_digest}" == *:* ]]; then
    repository="${image_without_digest%:*}"
    reference=":${image_without_digest##*:}${digest}"
  elif [ -n "${digest}" ]; then
    repository="${image_without_digest}"
    reference="${digest}"
  else
    repository="${image_without_digest}"
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

copy_destination_ref() {
  local image="$1"

  if [[ "${image}" == *@* ]]; then
    echo "${image%@*}"
  else
    echo "${image}"
  fi
}

vulnerability_gate_enabled() {
  local pipeline_source

  pipeline_source="${PARENT_PIPELINE_SOURCE:-${CI_PIPELINE_SOURCE:-}}"
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
    if ! trivy image --timeout "${trivy_timeout}" --exit-code 1 --severity "${severity_threshold}" "${source_image}"; then
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

scan_one_image() {
  local source_image critical_count high_count total_count fixed_count unfixed_count
  local trivy_status trivy_auth_args=()

  source_image="${SOURCE_IMAGE:-}"

  if [ -z "${source_image}" ]; then
    echo "SOURCE_IMAGE is required" >&2
    exit 1
  fi

  if [[ "${source_image}" == "${dest_registry}/"* ]] && [ -n "${REGISTRY_USER:-}" ] && [ -n "${REGISTRY_PASSWORD:-}" ]; then
    trivy_auth_args=(--username "${REGISTRY_USER}" --password-stdin)
  fi

  echo "scanning ${source_image}"
  trivy_status=0
  if [ "${#trivy_auth_args[@]}" -gt 0 ]; then
    printf '%s' "${REGISTRY_PASSWORD}" | trivy image \
      --quiet \
      --skip-version-check \
      --scanners vuln \
      --format json \
      --severity "${severity_threshold}" \
      --timeout "${trivy_timeout}" \
      --output "${trivy_report}" \
      "${trivy_auth_args[@]}" \
      "${source_image}" 2>"${trivy_error_log}" || trivy_status=$?
  else
    trivy image \
      --quiet \
      --skip-version-check \
      --scanners vuln \
      --format json \
      --severity "${severity_threshold}" \
      --timeout "${trivy_timeout}" \
      --output "${trivy_report}" \
      "${source_image}" 2>"${trivy_error_log}" || trivy_status=$?
  fi

  if [ "${trivy_status}" -ne 0 ] && [ ! -s "${trivy_report}" ]; then
    echo "trivy scan failed before producing ${trivy_report}"
    if [ -s "${trivy_error_log}" ]; then
      echo "trivy error output:"
      tail -n 40 "${trivy_error_log}"
    fi

    printf '{}\n' >"${trivy_report}"

    if vulnerability_gate_enabled; then
      echo "failing rendered image scan because vulnerability gating is enabled" >&2
      exit "${trivy_status}"
    fi

    echo "continuing anyway - review recommended" >&2
    return
  fi

  critical_count="$(yq -r '[.Results[].Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "${trivy_report}")"
  high_count="$(yq -r '[.Results[].Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "${trivy_report}")"
  total_count=$((critical_count + high_count))

  echo "scan summary for ${source_image}"
  echo "critical: ${critical_count}"
  echo "high: ${high_count}"

  if [ "${total_count}" -eq 0 ]; then
    echo "no ${severity_threshold} vulnerabilities found"
    return
  fi

  fixed_count="$(yq -r '[.Results[].Vulnerabilities[]? | select(.FixedVersion != null and .FixedVersion != "")] | length' "${trivy_report}")"
  unfixed_count=$((total_count - fixed_count))

  echo "fixed version available: ${fixed_count}"
  echo "no fixed version listed: ${unfixed_count}"
  echo "showing top ${trivy_summary_limit} findings:"
  yq -r '
    .Results[] |
    select(.Vulnerabilities != null) |
    .Target as $target |
    .Vulnerabilities[] |
    [
      .Severity,
      .PkgName,
      .VulnerabilityID,
      (.InstalledVersion // "-"),
      (.FixedVersion // "-"),
      $target
    ] |
    @tsv
  ' "${trivy_report}" \
    | sort \
    | head -n "${trivy_summary_limit}" \
    | while IFS="$(printf '\t')" read -r severity package cve installed fixed target; do
        printf -- '- %s %s %s installed=%s fixed=%s target=%s\n' "${severity}" "${package}" "${cve}" "${installed}" "${fixed}" "${target}"
      done

  echo "full trivy json report written to ${trivy_report}"

  if vulnerability_gate_enabled; then
    echo "failing rendered image scan because vulnerability gating is enabled" >&2
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
  dest_ref="docker://$(copy_destination_ref "${rendered_image}")"

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

login_destination_registry() {
  if [ -z "${REGISTRY_USER:-}" ] || [ -z "${REGISTRY_PASSWORD:-}" ]; then
    echo "REGISTRY_USER and REGISTRY_PASSWORD are required when syncing images" >&2
    exit 1
  fi

  printf '%s' "${REGISTRY_PASSWORD}" | skopeo login -u "${REGISTRY_USER}" --password-stdin "${dest_registry}"
}

rendered_image_exists() {
  local rendered_image="$1"

  skopeo inspect --raw "docker://${rendered_image}" >/dev/null 2>&1
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

workflow:
  rules:
    - when: always

stages:
  - scan
  - sync

variables:
  PARENT_PIPELINE_SOURCE: $(yaml_quote "${parent_pipeline_source}")
  FAIL_ON_IMAGE_VULNERABILITIES: $(yaml_quote "${fail_on_vulnerabilities}")
EOF
}

write_noop_pipeline() {
  cat >"${child_pipeline_file}" <<'EOF'
workflow:
  rules:
    - when: always

stages:
  - scan

rendered-images-current:
  stage: scan
  image:
    name: registry.home.mrdvince.me/homelab/builder:1.4.1
    entrypoint: [""]
  script:
    - echo "all rendered images already exist in the destination registry"
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
  local rendered_image source_image job_name index scan_count sync_count skipped_count

  build_registry_map
  prepare_image_refs
  write_pipeline_header

  if [ "${sync_images}" = "true" ]; then
    login_destination_registry
  fi

  index=0
  scan_count=0
  sync_count=0
  skipped_count=0
  while IFS=$'\t' read -r rendered_image source_image; do
    index=$((index + 1))
    job_name="$(job_name_for_image "${index}" "${rendered_image}")"

    if [ "${sync_images}" = "true" ] && rendered_image_exists "${rendered_image}"; then
      echo "skipping ${rendered_image} - already exists in registry"
      skipped_count=$((skipped_count + 1))

      if [ "${parent_pipeline_source}" != "merge_request_event" ]; then
        continue
      fi

      append_scan_job "${job_name}" "${source_image}"
      scan_count=$((scan_count + 1))
      continue
    fi

    append_scan_job "${job_name}" "${source_image}"
    scan_count=$((scan_count + 1))

    if [ "${sync_images}" = "true" ]; then
      append_sync_job "${job_name}" "${rendered_image}" "${source_image}"
      sync_count=$((sync_count + 1))
    fi
  done <"${image_ref_map}"

  if [ "${scan_count}" -eq 0 ] && [ "${sync_count}" -eq 0 ]; then
    write_noop_pipeline
  fi

  echo "rendered image scan jobs generated: ${scan_count}"
  echo "rendered image sync jobs generated: ${sync_count}"
  echo "rendered images skipped because they already exist: ${skipped_count}"
  echo "generated rendered image child pipeline:"
  cat "${child_pipeline_file}"
}

mirror_images() {
  local rendered_image source_image

  build_registry_map
  prepare_image_refs
  scan_image_refs

  if [ "${sync_images}" = "true" ]; then
    login_destination_registry
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
  scan-one)
    scan_one_image
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
