#!/usr/bin/env nu

use lib/build.nu [build-image wait-for-docker]
use lib/config.nu [settings]
use lib/generated.nu [
  chart-rows-from-pipeline
  chart-source-hash
  chart-source-hash-from-pipeline
  verify-generated-ci
  write-generated-ci
]
use lib/images.nu [chart-image-rows local-image-rows sync-one-image]
use lib/select.nu [all-build-rows]

def inventory [cfg: record, skip_render: bool = false] {
  let builds = (all-build-rows $cfg)
  let charts = if $skip_render {
    if not ($cfg.generated_ci | path exists) {
      error make {msg: $"generated CI file is missing: ($cfg.generated_ci)"}
    }

    let pipeline = (open $cfg.generated_ci)
    let preserved_hash = (chart-source-hash-from-pipeline $pipeline)
    let current_hash = (chart-source-hash)
    if $preserved_hash != $current_hash {
      error make {msg: "chart sources changed; rerun without --skip-render"}
    }

    chart-rows-from-pipeline $pipeline
  } else {
    chart-image-rows $cfg
  }
  let locals = (local-image-rows $cfg)

  {
    builds: $builds
    charts: $charts
    locals: $locals
    chart_source_hash: (chart-source-hash)
  }
}

def main [] {
  print "usage: nu ci/images.nu <command>"
  print "commands: generate-ci | verify-ci | build | wait-for-docker | sync-one"
}

def "main generate-ci" [--skip-render] {
  let cfg = (settings)
  let images = (inventory $cfg $skip_render)
  write-generated-ci $cfg $images.builds $images.charts $images.locals $images.chart_source_hash
  print $"generated ($cfg.generated_ci): (($images.builds | length)) builds, (($images.charts | get image | uniq | length)) chart images, (($images.locals | get image | uniq | length)) local images"
}

def "main verify-ci" [--skip-render] {
  let cfg = (settings)
  let images = (inventory $cfg $skip_render)
  verify-generated-ci $cfg $images.builds $images.charts $images.locals $images.chart_source_hash
}

def "main build" [name: string] {
  build-image (settings) $name
}

def "main wait-for-docker" [] {
  wait-for-docker
}

def "main sync-one" [image: string] {
  sync-one-image (settings) $image
}
