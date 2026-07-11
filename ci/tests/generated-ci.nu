#!/usr/bin/env nu

use std/assert
use ../lib/generated.nu [pipeline-record]

def main [] {
  let builds = [
    {
      source_file: infrastructure/images/builds/builder.yaml
      name: builder
      repo: "-"
      commit: "-"
      dockerfile: infrastructure/images/dockerfiles/builder/Dockerfile
      image: homelab/builder
      tag: "1.4.4"
    }
  ]
  let charts = [
    {
      image: "docker.io/example/controller:v1.2.3"
      source_file: apps/core/example/helmfile.yaml.gotmpl
    }
    {
      image: "docker.io/example/controller:v1.2.3"
      source_file: apps/services/example/helmfile.yaml.gotmpl
    }
  ]
  let locals = [
    {
      image: "ghcr.io/example/service:v4.5.6"
      source_file: infrastructure/images/images/local/example.yaml
    }
  ]

  let pipeline = (pipeline-record $builds $charts $locals)
  let job_names = ($pipeline | columns)

  assert equal $job_names [
    build:builder
    sync:chart:docker-io-example-controller-v1-2-3
    sync:local:ghcr-io-example-service-v4-5-6
  ]
  assert equal ($pipeline | get build:builder | get variables.BUILD_NAME) builder
  assert equal ($pipeline | get build:builder | get rules | first | get if) '$BUILD_IMAGE == "builder"'
  assert equal ($pipeline | get sync:chart:docker-io-example-controller-v1-2-3 | get extends) .sync-chart-image
  assert equal ($pipeline | get sync:local:ghcr-io-example-service-v4-5-6 | get extends) .sync-local-image
  assert equal ($pipeline | get sync:chart:docker-io-example-controller-v1-2-3 | get variables.IMAGE_TO_SYNC) "docker.io/example/controller:v1.2.3"
  assert equal (
    $pipeline
    | get sync:chart:docker-io-example-controller-v1-2-3
    | get rules
    | first
    | get if
  ) '$SYNC_UPSTREAM_IMAGE == "docker.io/example/controller:v1.2.3"'
  assert equal (
    $pipeline
    | get sync:chart:docker-io-example-controller-v1-2-3
    | get rules
    | get if
    | get 1
  ) '$CI_PIPELINE_SOURCE == "push" && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_COMMIT_MESSAGE =~ /sync-upstream:docker-io-example-controller-v1-2-3/'
  assert equal (
    $pipeline
    | get sync:local:ghcr-io-example-service-v4-5-6
    | get rules
    | first
    | get if
  ) '$SYNC_LOCAL_IMAGE == "ghcr.io/example/service:v4.5.6"'
  assert equal (
    $pipeline
    | get sync:local:ghcr-io-example-service-v4-5-6
    | get rules
    | get if
    | get 1
  ) '$CI_PIPELINE_SOURCE == "push" && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_COMMIT_MESSAGE =~ /sync-local:ghcr-io-example-service-v4-5-6/'
  assert equal (
    $pipeline
    | get sync:chart:docker-io-example-controller-v1-2-3
    | get rules
    | get if
    | any {|rule| $rule == '$SYNC_UPSTREAM_BLOCK == "example"' }
  ) true
  assert equal (
    $pipeline
    | get sync:local:ghcr-io-example-service-v4-5-6
    | get rules
    | get if
    | any {|rule| $rule == '$SYNC_LOCAL_BLOCK == "example"' }
  ) true
  assert equal (
    $pipeline
    | get sync:chart:docker-io-example-controller-v1-2-3
    | get rules
    | get if
    | any {|rule| $rule =~ 'sync-upstream:example/' }
  ) true
  assert equal (
    $pipeline
    | get sync:chart:docker-io-example-controller-v1-2-3
    | get rules
    | last
    | get changes
    | first 2
  ) [apps/core/example/**/* apps/services/example/**/*]
  assert equal ($pipeline | get sync:local:ghcr-io-example-service-v4-5-6 | get rules | last | get changes | first) infrastructure/images/images/local/example.yaml

  let yaml = ($pipeline | to yaml)
  assert not ($yaml =~ 'trigger:')
}
