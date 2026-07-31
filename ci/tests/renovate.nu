#!/usr/bin/env nu

use std/assert

def main [] {
  let config = (open renovate.json)
  let task = $config.postUpgradeTasks

  assert equal $config.branchConcurrentLimit 0
  assert equal $config.prConcurrentLimit 0
  assert equal $config.prHourlyLimit 0
  assert equal $task.commands ["nu ci/images.nu generate-ci --skip-render"]
  assert equal $task.fileFilters [ci/generated-images.gitlab-ci.yml]
  assert equal $task.executionMode branch

  let runtime_manager = (
    $config.customManagers
    | where description == "update the renovate CI runtime"
    | first
  )
  assert equal ($runtime_manager.managerFilePatterns | length) 3
  assert equal $runtime_manager.datasourceTemplate npm

  let hermes_rule = (
    $config.packageRules
    | where description? == "keep hermes updates out of bulk image bumps"
    | first
  )
  assert equal $hermes_rule.groupName hermes
  assert equal ($hermes_rule.matchPackageNames | length) 2
}
