#!/usr/bin/env nu

use std/assert
use ../lib/images.nu [destination-for extract-images local-image-rows]
use ../lib/select.nu [all-build-rows]

def main [] {
  let cfg = {
    dest_registry: registry.example.test
    rendered_dir: /tmp/unused
    local_image_dir: ci/tests/fixtures/local
    build_dir: ci/tests/fixtures/builds
  }

  assert equal (
    extract-images ci/tests/fixtures/manifest.yaml
  ) [
    docker.io/example/sidecar:v4
    ghcr.io/example/direct:v5
    quay.io/example/operator:v1.2.3
  ]

  assert equal (
    destination-for $cfg docker.io/example/service:v1
  ) registry.example.test/example/service:v1
  assert equal (
    destination-for $cfg example/service:v1
  ) registry.example.test/example/service:v1
  assert equal (
    destination-for $cfg "docker.io/example/service:v1@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  ) registry.example.test/example/service:v1

  let local = (local-image-rows $cfg | first)
  assert equal $local.image ghcr.io/example/service:v4.5.6
  assert equal $local.source_file ci/tests/fixtures/local/example.yaml

  let build = (all-build-rows $cfg | first)
  assert equal $build.name example
  assert equal $build.image homelab/example
  assert equal $build.tag "1.2.3"
}
