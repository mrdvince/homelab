#!/usr/bin/env bash
set -euo pipefail

env_name="${ENV_NAME:-aion}"
output_dir="${RENDERED_MANIFEST_DIR:-/tmp/rendered-manifests}"
rendered_image_list="${RENDERED_IMAGE_LIST:-imagelist.txt}"
dest_registry="${DEST_REGISTRY:-registry.home.mrdvince.me}"
map_dir="${IMAGE_MAP_DIR:-infrastructure/images/images}"
severity_threshold="${SEVERITY_THRESHOLD:-CRITICAL,HIGH}"
scan_images="${SCAN_IMAGES:-true}"
sync_images="${SYNC_IMAGES:-true}"
fail_on_vulnerabilities="${FAIL_ON_IMAGE_VULNERABILITIES:-false}"
allow_upstream_rendered_images="${ALLOW_UPSTREAM_RENDERED_IMAGES:-false}"
registry_map=""

usage() {
  cat <<'EOF'
usage: ci/mirror.sh [run|render|images|sync]

environment overrides:
  ENV_NAME                         helmfile environment, default: aion
  HELMFILE_PATHS                   optional space-separated helmfiles to render
  RENDERED_MANIFEST_DIR            rendered manifest output directory
  RENDERED_IMAGE_LIST              extracted image list path
  DEST_REGISTRY                    required rendered image registry
  IMAGE_MAP_DIR                    yaml registry mapping directory
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
    helmfile -f "${helmfile_path}" -e "${env_name}" repos >/dev/null
    helmfile -f "${helmfile_path}" -e "${env_name}" template --include-crds -q >"${output_path}"
  done
}

extract_images() {
  local rendered_files=()

  mapfile -t rendered_files < <(find "${output_dir}" -maxdepth 1 -type f -name '*.yaml' -print | sort)

  if [ "${#rendered_files[@]}" -eq 0 ]; then
    echo "no rendered manifests found in ${output_dir}" >&2
    exit 1
  fi

  yq -N -r '.. | select(tag == "!!map" and has("image")) | .image | select(. != null)' "${rendered_files[@]}" \
    | sed '/^$/d' \
    | sort -u >"${rendered_image_list}"

  if [ ! -s "${rendered_image_list}" ]; then
    echo "no rendered images found" >&2
    exit 1
  fi
}

build_registry_map() {
  local map_file

  registry_map="$(mktemp)"
  trap 'rm -f "${registry_map}"' EXIT

  for map_file in "${map_dir}"/*.yaml; do
    [ -f "${map_file}" ] || continue
    yq -r '.. | select(tag == "!!map" and has("registry") and has("image")) | select(.registry != null and .image != null) | [.image, .registry] | @tsv' "${map_file}"
  done | sort -u >"${registry_map}"

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
    echo "no upstream registry mapping for rendered image repository: ${repository}" >&2
    echo "add ${repository} to ${map_dir} with its upstream registry" >&2
    exit 1
  }

  echo "${source_registry}/${repository}${reference}"
}

process_image() {
  local rendered_image="$1"
  local source_image source_ref dest_ref pipeline_source

  [ -n "${rendered_image}" ] || return

  source_image="$(normalize_ref "${rendered_image}")"
  source_ref="docker://${source_image}"
  dest_ref="docker://${rendered_image}"
  pipeline_source="${CI_PIPELINE_SOURCE:-${PARENT_PIPELINE_SOURCE:-}}"

  if [ "${scan_images}" = "true" ]; then
    echo "scanning ${source_image}"
    if ! trivy image --exit-code 1 --severity "${severity_threshold}" "${source_image}"; then
      echo "warning: critical/high vulnerabilities found in ${source_image}"

      if [ "${fail_on_vulnerabilities}" = "true" ] || [ "${pipeline_source}" = "merge_request_event" ]; then
        echo "failing rendered image mirror because vulnerability gating is enabled"
        exit 1
      fi

      echo "continuing anyway - review recommended"
    fi
  fi

  if [ "${sync_images}" != "true" ]; then
    return
  fi

  if skopeo inspect --raw "${dest_ref}" >/dev/null 2>&1; then
    echo "skipping ${rendered_image} - already exists in registry"
    return
  fi

  echo "syncing ${source_ref} -> ${dest_ref}"
  skopeo copy --all "${source_ref}" "${dest_ref}"
}

mirror_images() {
  local image

  build_registry_map

  if [ "${sync_images}" = "true" ]; then
    printf '%s' "${REGISTRY_PASSWORD}" | skopeo login -u "${REGISTRY_USER}" --password-stdin "${dest_registry}"
  fi

  while IFS= read -r image; do
    process_image "${image}"
  done <"${rendered_image_list}"
}

run_all() {
  render_helmfiles
  extract_images
  mirror_images
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
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
