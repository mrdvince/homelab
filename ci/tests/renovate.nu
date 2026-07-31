#!/usr/bin/env nu

use std/assert

def main [] {
  let config = (open renovate.json)
  let task = $config.postUpgradeTasks
  let pipeline = (open .gitlab-ci.yml)
  let renovate_job = $pipeline.renovate
  let renovate_script = ($renovate_job.script | str join "\n")

  assert equal $config.branchConcurrentLimit 0
  assert equal $config.prConcurrentLimit 0
  assert equal $config.prHourlyLimit 0
  assert equal ($renovate_job.variables.RENOVATE_ALLOWED_COMMANDS | from json) ["^nu ci/images\\.nu generate-ci$"]
  assert ($renovate_script | str contains "RENOVATE_SECRETS")
  assert ($renovate_script | str contains "RENOVATE_CUSTOM_ENV_VARIABLES")
  assert ($renovate_script | str contains "secrets.SOPS_AGE_KEY")
  assert equal $task.commands ["nu ci/images.nu generate-ci"]
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

  let mongodb_rule = (
    $config.packageRules
    | where description? == "keep mongodb updates out of bulk image bumps"
    | first
  )
  assert equal $mongodb_rule.groupName mongodb
  assert equal $mongodb_rule.matchPackageNames [library/mongo]
}
