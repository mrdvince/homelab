#!/usr/bin/env nu

use lib/config.nu [settings]
use lib/images.nu [
  extract-local-images
  extract-rendered-images
  login-to-destination-registry
  render-upstream-manifests
  sync-one-image
]
use lib/pipeline.nu [
  write-chart-pipeline
  write-chart-plan
  write-local-pipeline
  write-local-plan
]
use lib/build.nu [
  build-one-image
  extract-build-images
  write-build-pipeline
  write-build-plan
]

def main [] {
  print "usage: nu ci/images.nu <command>"
  print "common: chart-pipeline | local-pipeline | build-pipeline"
  print "run `nu ci/images.nu --help` for all subcommands"
}

def "main chart-list" [] {
  let cfg = (settings)
  render-upstream-manifests $cfg
  extract-rendered-images $cfg
}

def "main chart-pipeline" [] {
  let cfg = (settings)
  render-upstream-manifests $cfg
  extract-rendered-images $cfg
  write-chart-pipeline $cfg
}

def "main chart-plan" [] {
  let cfg = (settings)
  render-upstream-manifests $cfg
  extract-rendered-images $cfg
  write-chart-pipeline $cfg
  write-chart-plan $cfg
}

def "main chart-sync-one" [image: string] {
  let cfg = (settings)
  login-to-destination-registry $cfg
  sync-one-image $cfg $image
}

def "main local-list" [] {
  let cfg = (settings)
  extract-local-images $cfg
}

def "main local-pipeline" [] {
  let cfg = (settings)
  extract-local-images $cfg
  write-local-pipeline $cfg
}

def "main local-plan" [] {
  let cfg = (settings)
  extract-local-images $cfg
  write-local-pipeline $cfg
  write-local-plan $cfg
}

def "main local-sync-one" [image: string] {
  let cfg = (settings)
  login-to-destination-registry $cfg
  sync-one-image $cfg $image
}

def "main build-list" [] {
  let cfg = (settings)
  extract-build-images $cfg
}

def "main build-pipeline" [] {
  let cfg = (settings)
  extract-build-images $cfg
  write-build-pipeline $cfg
}

def "main build-plan" [] {
  let cfg = (settings)
  extract-build-images $cfg
  write-build-pipeline $cfg
  write-build-plan $cfg
}

def "main build-one" [] {
  let cfg = (settings)
  build-one-image $cfg
}
