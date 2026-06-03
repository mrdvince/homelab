#!/bin/sh
set -eu

chart_root="${CHART_ROOT:-charts}"
chart_registry_url="${CHART_REGISTRY_URL:-${CI_API_V4_URL:-}/projects/${CI_PROJECT_ID:-}/packages/helm/api/stable/charts}"
publish_charts_enabled="${PUBLISH_CHARTS:-true}"

usage() {
  cat <<'EOF'
usage: ci/charts.sh [publish]

environment overrides:
  CHART_ROOT          chart root, default: charts
  CHART_REGISTRY_URL  target GitLab Helm registry URL
  PUBLISH_CHARTS      true/false, default: true
EOF
}

validate_registry_config() {
  if [ "${publish_charts_enabled}" != "true" ]; then
    return
  fi

  if [ -z "${CI_JOB_TOKEN:-}" ] || [ -z "${chart_registry_url}" ]; then
    echo "CI_JOB_TOKEN and CHART_REGISTRY_URL or GitLab CI API variables are required to publish" >&2
    exit 1
  fi
}

publish_chart() {
  chart="$1"
  dir="$(dirname "${chart}")"
  name="$(yq -r '.name' "${chart}")"
  version="$(yq -r '.version' "${chart}")"
  package="${name}-${version}.tgz"

  if [ "${name}" = "null" ] || [ "${version}" = "null" ]; then
    echo "chart metadata missing in ${chart}" >&2
    exit 1
  fi

  echo "packaging ${name}"
  helm dependency update "${dir}"
  helm package "${dir}" --destination .

  if [ ! -f "${package}" ]; then
    echo "failed to package ${name}" >&2
    exit 1
  fi

  if [ "${publish_charts_enabled}" = "true" ]; then
    echo "pushing ${package} to Helm registry"
    curl --fail-with-body --user "gitlab-ci-token:${CI_JOB_TOKEN}" \
      --form "chart=@${package}" \
      "${chart_registry_url}"
  else
    echo "skipping publish for ${package}"
  fi

  rm -f "${package}"
}

publish_charts() {
  found=false

  validate_registry_config

  for chart in "${chart_root}"/*/Chart.yaml; do
    [ -f "${chart}" ] || continue
    found=true
    publish_chart "${chart}"
  done

  if [ "${found}" = "false" ]; then
    echo "no charts found in ${chart_root}" >&2
    exit 1
  fi
}

case "${1:-publish}" in
  publish)
    publish_charts
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
