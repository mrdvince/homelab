#!/bin/sh
set -eu

env_name="${ENV_NAME:-aion}"
dest_registry="${DEST_REGISTRY:-registry.home.mrdvince.me}"
rendered_dir="${RENDERED_MANIFEST_DIR:-.rendered-manifests}"
image_list="${IMAGE_LIST:-imagelist.txt}"
chart_pipeline="${CHART_IMAGE_PIPELINE:-chart-images.yml}"
local_image_dir="${LOCAL_IMAGE_DIR:-infrastructure/images/images/local}"
local_image_list="${LOCAL_IMAGE_LIST:-local-imagelist.txt}"
local_pipeline="${LOCAL_IMAGE_PIPELINE:-local-images.yml}"
build_dir="${BUILD_DIR:-infrastructure/images/builds}"
build_list="${BUILD_LIST:-build-images.txt}"
build_pipeline="${BUILD_PIPELINE:-build-images.yml}"

require_safe_render_dir() {
  case "${rendered_dir}" in
    ""|"/"|".")
      echo "unsafe RENDERED_MANIFEST_DIR: ${rendered_dir}" >&2
      exit 1
      ;;
  esac
}

changed_files() {
  if [ -n "${CHANGED_FILES:-}" ]; then
    printf '%s\n' ${CHANGED_FILES}
    return
  fi

  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi

  head="${CI_COMMIT_SHA:-HEAD}"
  base=""

  if [ -n "${CI_MERGE_REQUEST_DIFF_BASE_SHA:-}" ]; then
    base="${CI_MERGE_REQUEST_DIFF_BASE_SHA}"
  elif [ -n "${CI_COMMIT_BEFORE_SHA:-}" ] && [ "${CI_COMMIT_BEFORE_SHA}" != "0000000000000000000000000000000000000000" ]; then
    base="${CI_COMMIT_BEFORE_SHA}"
  fi

  [ -n "${base}" ] || return 1
  git diff --name-only "${base}" "${head}"
}

all_local_image_files() {
  find "${local_image_dir}" -maxdepth 1 -name '*.yaml' -print | sort
}

local_image_files() {
  if [ -n "${LOCAL_IMAGE_FILES:-}" ]; then
    printf '%s\n' ${LOCAL_IMAGE_FILES}
    return
  fi

  if [ "${SYNC_LOCAL_IMAGES:-}" = "true" ]; then
    all_local_image_files
    return
  fi

  changed_file_list="${TMPDIR:-/tmp}/homelab-changed-files-local.$$"
  if changed_files >"${changed_file_list}"; then
    if grep -qx 'ci/images.sh' "${changed_file_list}"; then
      all_local_image_files
    else
      grep -E "^${local_image_dir}/[^/]+\\.yaml$" "${changed_file_list}" | sort || true
    fi
  else
    all_local_image_files
  fi
  rm -f "${changed_file_list}"
}

all_build_rows() {
  yq -N -r '
    filename as $file
    | to_entries[]
    | select(.value.dockerfile and .value.image and .value.tag)
    | [
        $file,
        .key,
        (.value.repo // "-"),
        (.value.commit // "-"),
        .value.dockerfile,
        .value.image,
        (.value.tag | tostring)
      ]
    | @tsv
  ' "${build_dir}"/*.yaml | sort
}

build_rows() {
  if [ "${BUILD_IMAGES:-}" = "true" ]; then
    all_build_rows
    return
  fi

  changed_file_list="${TMPDIR:-/tmp}/homelab-changed-files-build.$$"
  all_build_rows_file="${TMPDIR:-/tmp}/homelab-build-rows.$$"

  if ! changed_files >"${changed_file_list}"; then
    all_build_rows
    rm -f "${changed_file_list}" "${all_build_rows_file}"
    return
  fi

  all_build_rows >"${all_build_rows_file}"

  if grep -qx 'ci/images.sh' "${changed_file_list}"; then
    cat "${all_build_rows_file}"
  else
    awk -F '\t' '
      NR == FNR {
        changed[$0] = 1
        next
      }
      changed[$1] || changed[$5]
    ' "${changed_file_list}" "${all_build_rows_file}" | sort
  fi

  rm -f "${changed_file_list}" "${all_build_rows_file}"
}

helmfile_paths() {
  if [ -n "${HELMFILE_PATHS:-}" ]; then
    printf '%s\n' ${HELMFILE_PATHS}
    return
  fi

  if [ "${SYNC_UPSTREAM_IMAGES:-}" = "true" ]; then
    all_helmfile_paths
    return
  fi

  changed_file_list="${TMPDIR:-/tmp}/homelab-changed-files-chart.$$"
  selected_helmfiles="${TMPDIR:-/tmp}/homelab-selected-helmfiles.$$"

  if changed_files >"${changed_file_list}"; then
    if grep -qx 'ci/images.sh' "${changed_file_list}" || grep -qx 'infrastructure/images/config.yaml' "${changed_file_list}"; then
      all_helmfile_paths
    else
      : >"${selected_helmfiles}"
      while IFS= read -r changed_file; do
        case "${changed_file}" in
          apps/*) select_helmfile_for_changed_file "${changed_file}" >>"${selected_helmfiles}" ;;
        esac
      done <"${changed_file_list}"
      sort -u "${selected_helmfiles}"
      rm -f "${selected_helmfiles}"
    fi
  else
    all_helmfile_paths
  fi

  rm -f "${changed_file_list}"
}

all_helmfile_paths() {
  find apps -name 'helmfile.yaml.gotmpl' -print | sort
}

select_helmfile_for_changed_file() {
  path="${1}"
  dir="${path%/*}"

  while [ "${dir}" != "." ] && [ "${dir}" != "/" ] && [ -n "${dir}" ]; do
    if [ -f "${dir}/helmfile.yaml.gotmpl" ]; then
      printf '%s\n' "${dir}/helmfile.yaml.gotmpl"
      return
    fi
    dir="${dir%/*}"
  done
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
  if ! ls "${rendered_dir}"/*.yaml >/dev/null 2>&1; then
    : >"${image_list}"
    echo "rendered images extracted: 0"
    return
  fi

  yq -N -r '.. | select(tag == "!!str")' "${rendered_dir}"/*.yaml \
    | sed '/^$/d' \
    | grep -v '://' \
    | awk '{
        gsub(/[[:space:],;"(){}]+/, "\n")
        gsub(/=/, "\n")
        gsub(/\[/, "\n")
        gsub(/\]/, "\n")
        print
      }' \
    | grep -E '^[[:alnum:]_.-]+(:[0-9]+)?/[[:alnum:]_.@:/-]+$' \
    | grep -E '(:[[:alnum:]_][[:alnum:]_.-]*(@sha256:[[:xdigit:]]{64})?$|@sha256:[[:xdigit:]]{64}$)' \
    | sort -u >"${image_list}"

  image_count="$(wc -l <"${image_list}" | tr -d ' ')"
  echo "rendered images extracted: ${image_count}"
}

extract_local_images() {
  local_files="${TMPDIR:-/tmp}/homelab-local-image-files.$$"
  local_image_files >"${local_files}"

  if [ -s "${local_files}" ]; then
    yq -N -r '.. | select(tag == "!!map" and has("registry") and has("image") and has("tag")) | .registry + "/" + .image + ":" + (.tag | tostring)' $(cat "${local_files}") \
      | sort -u >"${local_image_list}"
  else
    : >"${local_image_list}"
  fi
  rm -f "${local_files}"

  image_count="$(wc -l <"${local_image_list}" | tr -d ' ')"
  echo "local images extracted: ${image_count}"
}

extract_build_images() {
  build_rows >"${build_list}"

  image_count="$(wc -l <"${build_list}" | tr -d ' ')"
  echo "build images extracted: ${image_count}"
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

login_to_destination_registry_if_available() {
  if [ -n "${REGISTRY_USER:-}" ] && [ -n "${REGISTRY_PASSWORD:-}" ]; then
    printf '%s' "${REGISTRY_PASSWORD}" | skopeo login -u "${REGISTRY_USER}" --password-stdin "${dest_registry}" >/dev/null
  fi
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

optional_value() {
  case "${1}" in
    "-") printf '%s\n' "" ;;
    *) printf '%s\n' "${1}" ;;
  esac
}

write_image_pipeline() {
  list_file="${1}"
  pipeline_file="${2}"
  job_prefix="${3}"
  sync_command="${4}"
  empty_message="${5}"

  {
    echo "stages:"
    echo "  - sync"
    echo ""
  } >"${pipeline_file}"

  login_to_destination_registry_if_available

  count=0
  skipped=0
  while IFS= read -r image; do
    [ -n "${image}" ] || continue

    case "${image}" in
      "${dest_registry}"/*)
        echo "skipping ${image} - already rendered with ${dest_registry}"
        skipped=$((skipped + 1))
        continue
        ;;
    esac

    destination="$(destination_for "${image}")"
    if skopeo inspect --raw "docker://${destination}" >/dev/null 2>&1; then
      echo "skipping ${destination} - already exists"
      skipped=$((skipped + 1))
      continue
    fi

    count=$((count + 1))
    job_name="$(safe_job_name "${image}")"
    job_id="$(printf '%03d' "${count}")"

    {
      echo "${job_prefix}-${job_id}-${job_name}:"
      echo "  stage: sync"
      echo "  image:"
      echo "    name: ${BUILDER_IMAGE:-registry.home.mrdvince.me/homelab/builder:1.4.1}"
      echo "    entrypoint: [\"\"]"
      echo "  variables:"
      echo "    IMAGE_TO_SYNC: \"${image}\""
      echo "  script:"
      echo "    - sh ci/images.sh ${sync_command} \"\${IMAGE_TO_SYNC}\""
      echo ""
    } >>"${pipeline_file}"
  done <"${list_file}"

  if [ "${count}" -eq 0 ]; then
    {
      echo "${job_prefix}-images-current:"
      echo "  stage: sync"
      echo "  image:"
      echo "    name: ${BUILDER_IMAGE:-registry.home.mrdvince.me/homelab/builder:1.4.1}"
      echo "    entrypoint: [\"\"]"
      echo "  script:"
      echo "    - echo \"${empty_message}\""
      echo ""
    } >>"${pipeline_file}"
  fi

  echo "${job_prefix} image jobs generated: ${count}"
  echo "${job_prefix} images skipped: ${skipped}"
}

write_chart_pipeline() {
  write_image_pipeline "${image_list}" "${chart_pipeline}" "chart" "chart-sync-one" "no chart images found"
}

write_local_pipeline() {
  write_image_pipeline "${local_image_list}" "${local_pipeline}" "local" "local-sync-one" "no local images found"
}

write_build_pipeline() {
  {
    echo "stages:"
    echo "  - build"
    echo ""
  } >"${build_pipeline}"

  count=0
  while IFS="$(printf '\t')" read -r source_file name repo commit dockerfile image tag; do
    [ -n "${name}" ] || continue

    count=$((count + 1))
    job_name="$(safe_job_name "${image}:${tag}")"
    job_id="$(printf '%03d' "${count}")"

    {
      echo "build-${job_id}-${job_name}:"
      echo "  stage: build"
      echo "  image:"
      echo "    name: ${BUILDER_BOOTSTRAP_IMAGE:-registry.home.mrdvince.me/homelab/builder:1.4.1}"
      echo "    entrypoint: [\"\"]"
      echo "  services:"
      echo "    - name: docker:29-dind"
      echo "      alias: docker"
      echo "      command: [\"--tls=false\"]"
      echo "  variables:"
      echo "    DOCKER_TLS_CERTDIR: \"\""
      echo "    DOCKER_HOST: tcp://docker:2375"
      echo "    DOCKER_BUILDKIT: \"1\""
      echo "    BUILD_NAME: \"${name}\""
      echo "    BUILD_REPO: \"$(optional_value "${repo}")\""
      echo "    BUILD_COMMIT: \"$(optional_value "${commit}")\""
      echo "    BUILD_DOCKERFILE: \"${dockerfile}\""
      echo "    BUILD_IMAGE: \"${image}\""
      echo "    BUILD_TAG: \"${tag}\""
      echo "  before_script:"
      echo "    - |"
      echo "      echo \"waiting for docker daemon\""
      echo "      docker_ready=false"
      echo "      for i in \$(seq 1 30); do"
      echo "        if docker info >/dev/null 2>&1; then"
      echo "          echo \"docker daemon ready\""
      echo "          docker_ready=true"
      echo "          break"
      echo "        fi"
      echo "        sleep 2"
      echo "      done"
      echo "      if [ \"\${docker_ready}\" != \"true\" ]; then"
      echo "        docker info"
      echo "        exit 1"
      echo "      fi"
      echo "  script:"
      echo "    - sh ci/images.sh build-one"
      echo ""
    } >>"${build_pipeline}"
  done <"${build_list}"

  if [ "${count}" -eq 0 ]; then
    {
      echo "build-images-current:"
      echo "  stage: build"
      echo "  image: docker:29"
      echo "  script:"
      echo "    - echo \"no build images found\""
      echo ""
    } >>"${build_pipeline}"
  fi

  echo "build image jobs generated: ${count}"
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

write_local_plan() {
  while IFS= read -r image; do
    [ -n "${image}" ] || continue

    destination="$(destination_for "${image}")"
    source="$(source_for "${image}")"

    echo "skopeo copy --all docker://${source} docker://${destination}"
  done <"${local_image_list}"
}

write_build_plan() {
  while IFS="$(printf '\t')" read -r source_file name repo commit dockerfile image tag; do
    [ -n "${name}" ] || continue

    repo="$(optional_value "${repo}")"
    commit="$(optional_value "${commit}")"

    if [ -n "${repo}" ]; then
      echo "docker build -f ${dockerfile} -t ${dest_registry}/${image}:${tag} <clone ${repo}@${commit}>"
    else
      echo "docker build -f ${dockerfile} -t ${dest_registry}/${image}:${tag} ."
    fi
    echo "docker push ${dest_registry}/${image}:${tag}"
  done <"${build_list}"
}

build_one_image() {
  if [ -z "${REGISTRY_USER:-}" ] || [ -z "${REGISTRY_PASSWORD:-}" ]; then
    echo "REGISTRY_USER and REGISTRY_PASSWORD are required to build images" >&2
    exit 1
  fi

  if [ -z "${BUILD_DOCKERFILE:-}" ] || [ -z "${BUILD_IMAGE:-}" ] || [ -z "${BUILD_TAG:-}" ]; then
    echo "BUILD_DOCKERFILE, BUILD_IMAGE, and BUILD_TAG are required" >&2
    exit 1
  fi

  destination="${dest_registry}/${BUILD_IMAGE}:${BUILD_TAG}"
  context_dir="${CI_PROJECT_DIR:-$(pwd)}"

  printf '%s' "${REGISTRY_PASSWORD}" | docker login -u "${REGISTRY_USER}" --password-stdin "${dest_registry}"

  if [ -n "${BUILD_REPO:-}" ]; then
    context_dir="${CI_PROJECT_DIR:-$(pwd)}/.build/${BUILD_NAME:-source}"
    rm -rf "${context_dir}"
    mkdir -p "$(dirname "${context_dir}")"
    git clone --filter=blob:none "${BUILD_REPO}" "${context_dir}"
    if [ -n "${BUILD_COMMIT:-}" ]; then
      git -C "${context_dir}" checkout --detach "${BUILD_COMMIT}"
    fi
  fi

  docker build -f "${CI_PROJECT_DIR:-$(pwd)}/${BUILD_DOCKERFILE}" -t "${destination}" "${context_dir}"
  docker push "${destination}"
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
    local-list)
      extract_local_images
      ;;
    local-pipeline)
      extract_local_images
      write_local_pipeline
      ;;
    local-plan)
      extract_local_images
      write_local_pipeline
      write_local_plan
      ;;
    local-sync-one)
      if [ -z "${2:-}" ]; then
        echo "usage: $0 local-sync-one IMAGE" >&2
        exit 1
      fi
      login_to_destination_registry
      sync_one_image "${2}"
      ;;
    build-list)
      extract_build_images
      ;;
    build-pipeline)
      extract_build_images
      write_build_pipeline
      ;;
    build-plan)
      extract_build_images
      write_build_pipeline
      write_build_plan
      ;;
    build-one)
      build_one_image
      ;;
    *)
      echo "usage: $0 [chart-list|chart-pipeline|chart-plan|chart-sync-one|local-list|local-pipeline|local-plan|local-sync-one|build-list|build-pipeline|build-plan|build-one]" >&2
      exit 1
      ;;
  esac
}

main "$@"
