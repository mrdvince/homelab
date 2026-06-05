#!/bin/sh
set -eu

env_name="${ENV_NAME:-aion}"
dest_registry="${DEST_REGISTRY:-registry.home.mrdvince.me}"
rendered_dir="${RENDERED_MANIFEST_DIR:-.rendered-manifests}"
image_list="${IMAGE_LIST:-imagelist.txt}"
chart_pipeline="${CHART_IMAGE_PIPELINE:-chart-images.yml}"

require_safe_render_dir() {
  case "${rendered_dir}" in
    ""|"/"|".")
      echo "unsafe RENDERED_MANIFEST_DIR: ${rendered_dir}" >&2
      exit 1
      ;;
  esac
}

helmfile_paths() {
  if [ -n "${HELMFILE_PATHS:-}" ]; then
    printf '%s\n' ${HELMFILE_PATHS}
  else
    find apps -name 'helmfile.yaml.gotmpl' -print | sort
  fi
}

render_upstream_manifests() {
  require_safe_render_dir

  rm -rf "${rendered_dir}"
  mkdir -p "${rendered_dir}"

  helmfile_paths | while IFS= read -r helmfile_path; do
    [ -n "${helmfile_path}" ] || continue
    output_name="$(printf '%s' "${helmfile_path}" | sed 's#[/ ]#__#g').yaml"

    echo "rendering ${helmfile_path}"
    helmfile -f "${helmfile_path}" -e "${env_name}" repos >/dev/null
    helmfile -f "${helmfile_path}" -e "${env_name}" template --include-crds --skip-tests -q --state-values-set renderStockImages=true >"${rendered_dir}/${output_name}"
  done
}

extract_rendered_images() {
  yq -N -r '.. | select(tag == "!!str")' "${rendered_dir}"/*.yaml \
    | sed '/^$/d' \
    | grep -v '://' \
    | grep -E '^[[:alnum:]_.-]+(:[0-9]+)?/[[:alnum:]_.@:/-]+$' \
    | grep -E '(:[[:alnum:]_][[:alnum:]_.-]*(@sha256:[[:xdigit:]]{64})?$|@sha256:[[:xdigit:]]{64}$)' \
    | sort -u >"${image_list}"

  image_count="$(wc -l <"${image_list}" | tr -d ' ')"
  echo "rendered images extracted: ${image_count}"
}

destination_for() {
  image="${1}"
  first_part="${image%%/*}"

  case "${first_part}" in
    *.*|*:*|localhost) destination="${dest_registry}/${image#*/}" ;;
    *) destination="${dest_registry}/${image}" ;;
  esac

  case "${image}" in
    *@*) destination="${destination%@*}" ;;
  esac

  printf '%s\n' "${destination}"
}

source_for() {
  image="${1}"
  source="${image}"

  case "${image}" in
    *@*)
      image_without_digest="${image%@*}"
      digest="${image#*@}"
      image_tail="${image_without_digest##*/}"
      case "${image_tail}" in
        *:*) source="${image_without_digest%:*}@${digest}" ;;
      esac
      ;;
  esac

  printf '%s\n' "${source}"
}

login_to_destination_registry() {
  if [ -z "${REGISTRY_USER:-}" ] || [ -z "${REGISTRY_PASSWORD:-}" ]; then
    echo "REGISTRY_USER and REGISTRY_PASSWORD are required to sync images" >&2
    exit 1
  fi

  printf '%s' "${REGISTRY_PASSWORD}" | skopeo login -u "${REGISTRY_USER}" --password-stdin "${dest_registry}"
}

sync_one_image() {
  image="${1}"

  case "${image}" in
    "${dest_registry}"/*)
      echo "skipping ${image} - already rendered with ${dest_registry}"
      return
      ;;
  esac

  destination="$(destination_for "${image}")"
  source="$(source_for "${image}")"

  if skopeo inspect --raw "docker://${destination}" >/dev/null 2>&1; then
    echo "skipping ${destination} - already exists"
    return
  fi

  echo "syncing docker://${source} -> docker://${destination}"
  skopeo copy --all "docker://${source}" "docker://${destination}"
}

safe_job_name() {
  printf '%s' "${1}" \
    | sed 's#^[^/]*/##' \
    | sed 's#@sha256:.*##' \
    | sed 's#[^[:alnum:]]#-#g' \
    | sed 's#--*#-#g' \
    | sed 's#^-##; s#-$##' \
    | cut -c 1-72
}

write_chart_pipeline() {
  {
    echo "stages:"
    echo "  - sync"
    echo ""
  } >"${chart_pipeline}"

  count=0
  while IFS= read -r image; do
    [ -n "${image}" ] || continue

    count=$((count + 1))
    job_name="$(safe_job_name "${image}")"
    job_id="$(printf '%03d' "${count}")"

    {
      echo "chart-${job_id}-${job_name}:"
      echo "  stage: sync"
      echo "  image:"
      echo "    name: ${BUILDER_IMAGE:-registry.home.mrdvince.me/homelab/builder:1.4.1}"
      echo "    entrypoint: [\"\"]"
      echo "  variables:"
      echo "    CHART_IMAGE: \"${image}\""
      echo "  script:"
      echo "    - sh ci/images.sh chart-sync-one \"\${CHART_IMAGE}\""
      echo ""
    } >>"${chart_pipeline}"
  done <"${image_list}"

  if [ "${count}" -eq 0 ]; then
    {
      echo "chart-images-current:"
      echo "  stage: sync"
      echo "  image:"
      echo "    name: ${BUILDER_IMAGE:-registry.home.mrdvince.me/homelab/builder:1.4.1}"
      echo "    entrypoint: [\"\"]"
      echo "  script:"
      echo "    - echo \"no chart images found\""
      echo ""
    } >>"${chart_pipeline}"
  fi

  echo "chart image jobs generated: ${count}"
}

write_chart_plan() {
  while IFS= read -r image; do
    [ -n "${image}" ] || continue

    case "${image}" in
      "${dest_registry}"/*)
        echo "skip ${image} - already rendered with ${dest_registry}"
        continue
        ;;
    esac

    destination="$(destination_for "${image}")"
    source="$(source_for "${image}")"

    echo "skopeo copy --all docker://${source} docker://${destination}"
  done <"${image_list}"
}

main() {
  command="${1:-}"

  case "${command}" in
    chart-list)
      render_upstream_manifests
      extract_rendered_images
      ;;
    chart-pipeline)
      render_upstream_manifests
      extract_rendered_images
      write_chart_pipeline
      ;;
    chart-plan)
      render_upstream_manifests
      extract_rendered_images
      write_chart_pipeline
      write_chart_plan
      ;;
    chart-sync-one)
      if [ -z "${2:-}" ]; then
        echo "usage: $0 chart-sync-one IMAGE" >&2
        exit 1
      fi
      login_to_destination_registry
      sync_one_image "${2}"
      ;;
    *)
      echo "usage: $0 [chart-list|chart-pipeline|chart-plan|chart-sync-one]" >&2
      exit 1
      ;;
  esac
}

main "$@"
