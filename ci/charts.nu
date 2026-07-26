#!/usr/bin/env nu

const config_path = "infrastructure/charts/sources.yaml"

def settings [] {
  open $config_path
}

def clean-value [value: string] {
  $value
  | str trim
  | str trim -c '"'
  | str trim -c "'"
}

def parse-chart-ref [cfg: record, chart_ref: string] {
  let value = (clean-value $chart_ref)
  let oci_prefix = $"oci://($cfg.registry.host)/($cfg.registry.namespace)/"
  let alias_prefix = $"($cfg.registry.alias)/"
  let relative = if ($value | str starts-with $oci_prefix) {
    $value | str replace $oci_prefix ""
  } else if ($value | str starts-with $alias_prefix) {
    $value | str replace $alias_prefix ""
  } else {
    $value
  }
  let parts = ($relative | split row "/")

  if (($parts | first) == "upstream") and (($parts | length) == 3) {
    {
      kind: upstream
      source: ($parts | get 1)
      name: ($parts | get 2)
    }
  } else if (($parts | first) == "internal") and (($parts | length) == 2) {
    {
      kind: internal
      source: internal
      name: ($parts | get 1)
    }
  } else if (($parts | length) == 2) {
    let source = ($parts | first)
    {
      kind: (if $source == "homelab" { "internal" } else { "upstream" })
      source: (if $source == "homelab" { "internal" } else { $source })
      name: ($parts | get 1)
    }
  } else {
    error make {msg: $"unsupported chart reference: ($value)"}
  }
}

def release-rows [cfg: record] {
  glob "apps/**/helmfile.yaml.gotmpl"
  | each {|file|
      let lines = (open --raw $file | lines)
      $lines
      | window 2
      | each {|pair|
          let chart_match = ($pair.0 | parse -r '^\s*chart:\s*(?<value>\S+)\s*$')
          let version_match = ($pair.1 | parse -r '^\s*version:\s*(?<value>\S+)\s*$')

          if ($chart_match | is-empty) or ($version_match | is-empty) {
            null
          } else {
            let parsed = (parse-chart-ref $cfg ($chart_match | first | get value))
            {
              kind: $parsed.kind
              source: $parsed.source
              name: $parsed.name
              version: (clean-value ($version_match | first | get value))
              source_file: ($file | into string)
            }
          }
        }
      | compact
    }
  | flatten
}

def dependency-rows [cfg: record] {
  let prefix = $"oci://($cfg.registry.host)/($cfg.registry.namespace)/upstream/"
  let sources = ($cfg.sources | transpose source repository)

  glob "charts/*/Chart.yaml"
  | each {|file|
      let chart = (open $file)
      $chart.dependencies?
      | default []
      | each {|dependency|
          let repository = ($dependency.repository | str trim -r -c "/")
          let source = if ($repository | str starts-with $prefix) {
            $repository | str replace $prefix ""
          } else {
            let match = ($sources | where {|entry|
              ($entry.repository | str trim -r -c "/") == $repository
            })
            if ($match | is-empty) {
              error make {msg: $"no chart source maps dependency repository ($repository) in ($file)"}
            }
            $match | first | get source
          }

          {
            kind: upstream
            source: $source
            name: ($dependency.name | into string)
            version: ($dependency.version | into string)
            source_file: ($file | into string)
          }
        }
    }
  | flatten
}

def internal-rows [] {
  glob "charts/*/Chart.yaml"
  | each {|file|
      let chart = (open $file)
      {
        kind: internal
        source: internal
        name: ($chart.name | into string)
        version: ($chart.version | into string)
        path: ($file | path dirname)
        source_file: ($file | into string)
      }
    }
}

def inventory [cfg: record] {
  (internal-rows)
  | append (release-rows $cfg)
  | append (dependency-rows $cfg)
  | uniq-by kind source name version
  | sort-by kind source name version
  | collect
}

def destination-base [cfg: record, row: record] {
  if $row.kind == "internal" {
    $"oci://($cfg.registry.host)/($cfg.registry.namespace)/internal"
  } else {
    $"oci://($cfg.registry.host)/($cfg.registry.namespace)/upstream/($row.source)"
  }
}

def destination-ref [cfg: record, row: record] {
  $"(destination-base $cfg $row)/($row.name)"
}

def fail-command [action: string, result: record] {
  let detail = if ($result.stderr | str trim | is-empty) {
    $result.stdout | str trim
  } else {
    $result.stderr | str trim
  }
  error make {msg: $"($action): ($detail)"}
}

def package-upstream [cfg: record, row: record, output_dir: string] {
  let repository = ($cfg.sources | get $row.source)
  let result = (do {
    ^helm pull --repo $repository $row.name --version $row.version --destination $output_dir
  } | complete)
  if $result.exit_code != 0 {
    fail-command $"failed to pull ($row.source)/($row.name) ($row.version)" $result
  }

  glob $"($output_dir)/*.tgz" | first | into string
}

def package-internal [row: record, output_dir: string] {
  let chart_dir = $"($output_dir)/chart"
  ^cp -R $row.path $chart_dir

  let chart = (open $"($chart_dir)/Chart.yaml")
  if not ($chart.dependencies? | default [] | is-empty) {
    let result = (do { ^helm dependency update $chart_dir } | complete)
    if $result.exit_code != 0 {
      fail-command $"failed to update dependencies for ($row.name)" $result
    }
  }

  let result = (do { ^helm package $chart_dir --destination $output_dir } | complete)
  if $result.exit_code != 0 {
    fail-command $"failed to package ($row.name) ($row.version)" $result
  }

  glob $"($output_dir)/($row.name)-*.tgz" | first | into string
}

def package-row [cfg: record, row: record, output_dir: string] {
  if $row.kind == "internal" {
    package-internal $row $output_dir
  } else {
    package-upstream $cfg $row $output_dir
  }
}

def package-hash [path: string] {
  let extract_root = (^mktemp -d)
  ^tar -xzf $path -C $extract_root
  let digest = (
    glob $"($extract_root)/**/*"
    | where {|entry| ($entry | path type) == "file"}
    | sort
    | each {|entry|
        let relative_path = ($entry | path relative-to $extract_root)
        $"($relative_path)\u{0}(open --raw $entry | hash sha256)"
      }
    | str join "\n"
    | hash sha256
  )
  ^rm -rf $extract_root
  $digest
}

def pull-package [cfg: record, row: record, output_dir: string] {
  do {
    ^helm pull (destination-ref $cfg $row) --version $row.version --destination $output_dir
  } | complete
}

def sync-row [cfg: record, row: record, work_root: string] {
  let row_root = (^mktemp -d $"($work_root)/chart.XXXXXX")
  let source_dir = $"($row_root)/source"
  let remote_dir = $"($row_root)/remote"
  ^mkdir -p $source_dir $remote_dir

  let package = (package-row $cfg $row $source_dir)
  let existing = (pull-package $cfg $row $remote_dir)

  if $existing.exit_code == 0 {
    let remote_package = (glob $"($remote_dir)/*.tgz" | first | into string)
    if (package-hash $package) != (package-hash $remote_package) {
      error make {
        msg: $"refusing to replace (destination-ref $cfg $row):($row.version) with different content"
      }
    }
    print $"present (destination-ref $cfg $row):($row.version)"
    return
  }

  let pushed = (do {
    ^helm push $package (destination-base $cfg $row)
  } | complete)
  if $pushed.exit_code != 0 {
    fail-command $"failed to push (destination-ref $cfg $row):($row.version)" $pushed
  }

  let verified = (pull-package $cfg $row $remote_dir)
  if $verified.exit_code != 0 {
    fail-command $"failed to pull back (destination-ref $cfg $row):($row.version)" $verified
  }

  let remote_package = (glob $"($remote_dir)/*.tgz" | first | into string)
  if (package-hash $package) != (package-hash $remote_package) {
    error make {msg: $"pull-back checksum mismatch for (destination-ref $cfg $row):($row.version)"}
  }
  print $"synced (destination-ref $cfg $row):($row.version)"
}

def latest-row [cfg: record, row: record, work_root: string] {
  let latest_root = (^mktemp -d $"($work_root)/latest.XXXXXX")
  let repository = ($cfg.sources | get $row.source)
  let result = (do {
    ^helm pull --repo $repository $row.name --destination $latest_root
  } | complete)
  if $result.exit_code != 0 {
    fail-command $"failed to resolve latest ($row.source)/($row.name)" $result
  }

  let package = (glob $"($latest_root)/*.tgz" | first | into string)
  let metadata = (^helm show chart $package | from yaml)
  $row | upsert version ($metadata.version | into string)
}

def validate-inventory [cfg: record, rows: table] {
  let known_sources = ($cfg.sources | columns)
  let unknown_sources = (
    $rows
    | where kind == upstream
    | where {|row| $row.source not-in $known_sources}
  )
  if not ($unknown_sources | is-empty) {
    error make {msg: $"unknown upstream chart sources: ($unknown_sources.source | uniq | str join ', ')"}
  }

  let release_internal = (release-rows $cfg | where kind == internal)
  let local = (internal-rows)
  for row in $release_internal {
    let match = ($local | where name == $row.name | where version == $row.version)
    if ($match | is-empty) {
      error make {msg: $"($row.source_file) references missing internal chart ($row.name) ($row.version)"}
    }
  }

  print $"validated (($rows | length)) unique chart artifacts"
}

def main [] {
  print "usage: nu ci/charts.nu <command>"
  print "commands: verify | sync [--latest] | verify-remote"
}

def "main verify" [] {
  let cfg = (settings)
  validate-inventory $cfg (inventory $cfg)
}

def "main sync" [--latest, --source: string, --name: string] {
  let cfg = (settings)
  let rows = (inventory $cfg | collect)
  validate-inventory $cfg $rows
  let selected = (
    $rows
    | where {|row| ($source == null) or ($row.source == $source)}
    | where {|row| ($name == null) or ($row.name == $name)}
    | collect
  )
  if ($selected | is-empty) {
    error make {msg: "no chart artifacts matched the requested filters"}
  }
  let work_root = (^mktemp -d)

  try {
    for row in $selected {
      sync-row $cfg $row $work_root
    }

    if $latest {
      let upstream = ($selected | where kind == upstream | uniq-by source name | collect)
      for row in $upstream {
        sync-row $cfg (latest-row $cfg $row $work_root) $work_root
      }
    }
  } catch {|error|
    ^rm -rf $work_root
    error make $error.raw
  }

  ^rm -rf $work_root
}

def "main verify-remote" [--source: string, --name: string] {
  let cfg = (settings)
  let rows = (
    inventory $cfg
    | where {|row| ($source == null) or ($row.source == $source)}
    | where {|row| ($name == null) or ($row.name == $name)}
  )
  if ($rows | is-empty) {
    error make {msg: "no chart artifacts matched the requested filters"}
  }
  let work_root = (^mktemp -d)

  try {
    for row in $rows {
      let output_dir = (^mktemp -d $"($work_root)/pull.XXXXXX")
      let pulled = (pull-package $cfg $row $output_dir)
      if $pulled.exit_code != 0 {
        fail-command $"failed remote pull of (destination-ref $cfg $row):($row.version)" $pulled
      }
      print $"pulled (destination-ref $cfg $row):($row.version)"
    }
  } catch {|error|
    ^rm -rf $work_root
    error make $error.raw
  }

  ^rm -rf $work_root
}
