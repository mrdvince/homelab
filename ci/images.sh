#!/bin/sh
set -eu

image_root="${IMAGE_ROOT:-infrastructure/images}"
output_file="${CHILD_PIPELINE_FILE:-child-pipeline.yml}"
sync_template="${SYNC_TEMPLATE:-infrastructure/images/templates/sync.yml}"
build_template="${BUILD_TEMPLATE:-infrastructure/images/templates/build.yml}"

usage() {
  cat <<'EOF'
usage: ci/images.sh [pipeline]

environment overrides:
  IMAGE_ROOT           image config root, default: infrastructure/images
  CHILD_PIPELINE_FILE  generated child pipeline path, default: child-pipeline.yml
  SYNC_TEMPLATE        sync template include path
  BUILD_TEMPLATE       build template include path
EOF
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
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
