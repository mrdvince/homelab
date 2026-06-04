#!/bin/sh
set -eu

image_root="${IMAGE_ROOT:-infrastructure/images}"
output_file="${CHILD_PIPELINE_FILE:-child-pipeline.yml}"
sync_template="${SYNC_TEMPLATE:-infrastructure/images/templates/sync.yml}"
build_template="${BUILD_TEMPLATE:-infrastructure/images/templates/build.yml}"

usage() {
  cat <<'EOF'
usage: ci/images.sh [pipeline|retag-local-builds]

environment overrides:
  IMAGE_ROOT           image config root, default: infrastructure/images
  CHILD_PIPELINE_FILE  generated child pipeline path, default: child-pipeline.yml
  SYNC_TEMPLATE        sync template include path
  BUILD_TEMPLATE       build template include path
EOF
}

target_branch="${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-${CI_DEFAULT_BRANCH:-main}}"
source_branch="${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:-}"

has_changed() {
  path="$1"

  git diff --name-only "origin/${target_branch}...HEAD" | grep -Fxq "${path}"
}

tag_for_dockerfile() {
  dockerfile="$1"
  date_part="$(git log -1 --format=%cd --date=format:%Y.%m.%d -- "${dockerfile}")"
  hash_part="$(git hash-object "${dockerfile}" | cut -c1-8)"

  printf '%s-%s' "${date_part}" "${hash_part}"
}

update_image_map_tag() {
  image="$1"
  tag="$2"
  file="$3"

  if yq -e ".. | select(tag == \"!!map\" and .image == \"${image}\")" "${file}" >/dev/null 2>&1; then
    yq -i "(.. | select(tag == \"!!map\" and .image == \"${image}\").tag) = \"${tag}\"" "${file}"
  fi
}

retag_local_builds() {
  if [ -z "${source_branch}" ]; then
    echo "not a merge request pipeline, nothing to retag"
    return
  fi

  git fetch origin "${target_branch}:refs/remotes/origin/${target_branch}"

  for build_file in "${image_root}"/builds/*.yaml; do
    [ -f "${build_file}" ] || continue

    for key in $(yq 'keys | .[]' "${build_file}"); do
      dockerfile="$(yq ".${key}.dockerfile" "${build_file}")"
      [ "${dockerfile}" != "null" ] || continue
      [ -n "${dockerfile}" ] || continue

      if ! has_changed "${dockerfile}"; then
        continue
      fi

      image="$(yq ".${key}.image" "${build_file}")"
      tag="$(tag_for_dockerfile "${dockerfile}")"

      echo "setting ${image} tag to ${tag} because ${dockerfile} changed"
      yq -i ".${key}.tag = \"${tag}\"" "${build_file}"

      for image_file in "${image_root}"/images/*.yaml; do
        [ -f "${image_file}" ] || continue
        update_image_map_tag "${image}" "${tag}" "${image_file}"
      done
    done
  done

  if git diff --quiet -- "${image_root}/builds" "${image_root}/images"; then
    echo "local build tags already match changed Dockerfiles"
    return
  fi

  if [ -z "${RENOVATE_TOKEN:-}" ]; then
    echo "RENOVATE_TOKEN is required to push local build tag updates" >&2
    exit 1
  fi

  git config user.name "renovate-bot"
  git config user.email "renovate-bot@home.mrdvince.me"
  git add "${image_root}/builds" "${image_root}/images"
  git commit -m "Update local build image tags"
  git push "https://oauth2:${RENOVATE_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git" "HEAD:${source_branch}"
}

write_header() {
  cat >"${output_file}" <<EOF
include:
  - local: ${sync_template}
  - local: ${build_template}

stages:
  - images
EOF
}

append_sync_job() {
  file="$1"
  name="$(basename "${file}" .yaml)"

  cat >>"${output_file}" <<EOF

sync-${name}:
  stage: images
  extends: .sync-images
  variables:
    IMAGE_FILE: "${file}"
  rules:
    - if: \$PARENT_PIPELINE_SOURCE == "web"
    - if: \$SYNC_ALL == "true"
    - if: \$PARENT_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - ${file}
        - ${sync_template}
    - changes:
        - ${file}
        - ${sync_template}
EOF
}

dockerfile_changes() {
  file="$1"

  yq e '.. | .dockerfile? | select(.)' "${file}" \
    | sed '/^$/d' \
    | sort -u \
    | sed 's|^|        - |'
}

append_build_job() {
  file="$1"
  name="$(basename "${file}" .yaml)"
  changes="$(dockerfile_changes "${file}")"

  cat >>"${output_file}" <<EOF

build-${name}:
  stage: images
  extends: .build-images
  variables:
    BUILD_FILE: "${file}"
  rules:
    - if: \$PARENT_PIPELINE_SOURCE == "web"
    - if: \$BUILD_ALL == "true"
    - if: \$PARENT_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - ${file}
        - ${build_template}
${changes}
    - changes:
        - ${file}
        - ${build_template}
${changes}
EOF
}

generate_pipeline() {
  write_header

  for file in "${image_root}"/images/*.yaml; do
    [ -f "${file}" ] || continue
    append_sync_job "${file}"
  done

  for file in "${image_root}"/builds/*.yaml; do
    [ -f "${file}" ] || continue
    append_build_job "${file}"
  done

  echo "generated child pipeline:"
  cat "${output_file}"
}

case "${1:-pipeline}" in
  pipeline)
    generate_pipeline
    ;;
  retag-local-builds)
    retag_local_builds
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
