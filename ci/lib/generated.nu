def safe-image-name [image: string] {
  $image
  | str replace -r '@sha256:' '-sha256-'
  | str replace -a -r '[^[:alnum:]]' '-'
  | str replace -a -r '--+' '-'
  | str replace -r '^-|-$' ''
  | str substring 0..95
}

def build-rules [row: record] {
  let dockerfile_dir = ($row.dockerfile | path dirname)

  [
    {if: $'$BUILD_IMAGE == "($row.name)"'}
    {if: '$BUILD_IMAGES == "true"'}
    {if: '$CI_PIPELINE_SOURCE == "push" && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_COMMIT_MESSAGE =~ /build-all/'}
    {
      if: '$CI_PIPELINE_SOURCE == "push" && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
      changes: [
        $row.source_file
        $"($dockerfile_dir)/**/*"
      ]
    }
  ]
}

def source-block [category: string, source_file: string] {
  if $category == chart {
    $source_file | path dirname | path basename
  } else {
    $source_file | path parse | get stem
  }
}

def sync-rules [category: string, image: string, image_key: string, source_files: list<string>] {
  let selector = if $category == chart {
    {
      image_variable: $'$SYNC_UPSTREAM_IMAGE == "($image)"'
      commit_message: $'$CI_PIPELINE_SOURCE == "push" && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_COMMIT_MESSAGE =~ /sync-upstream:($image_key)/'
      all_variable: '$SYNC_UPSTREAM_IMAGES == "true"'
    }
  } else {
    {
      image_variable: $'$SYNC_LOCAL_IMAGE == "($image)"'
      commit_message: $'$CI_PIPELINE_SOURCE == "push" && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_COMMIT_MESSAGE =~ /sync-local:($image_key)/'
      all_variable: '$SYNC_LOCAL_IMAGES == "true"'
    }
  }
  let category_paths = if $category == chart {
    let chart_paths = (
      $source_files
      | each {|path| $"($path | path dirname)/**/*" }
    )
    [$chart_paths infrastructure/images/config.yaml] | flatten | uniq | sort
  } else {
    $source_files | uniq | sort
  }
  let blocks = ($source_files | each {|path| source-block $category $path } | uniq | sort)
  let block_rules = ($blocks | each {|block|
    let block_variable = if $category == chart {
      $'$SYNC_UPSTREAM_BLOCK == "($block)"'
    } else {
      $'$SYNC_LOCAL_BLOCK == "($block)"'
    }
    let commit_prefix = if $category == chart { "sync-upstream" } else { "sync-local" }

    [
      {if: $block_variable}
      {if: $'$CI_PIPELINE_SOURCE == "push" && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $CI_COMMIT_MESSAGE =~ /($commit_prefix):($block)/'}
    ]
  } | flatten)

  [[
    {if: $selector.image_variable}
    {if: $selector.commit_message}
  ] $block_rules [
    {if: $selector.all_variable}
    {
      if: '$CI_PIPELINE_SOURCE == "push" && $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
      changes: $category_paths
    }
  ]] | flatten
}

def build-job [row: record] {
  {
    name: $"build:($row.name)"
    value: {
      extends: .build-image
      variables: {BUILD_NAME: $row.name}
      rules: (build-rules $row)
    }
  }
}

def sync-jobs [category: string, rows: list<record>] {
  $rows
  | group-by image
  | transpose image rows
  | sort-by image
  | each {|group|
      let image_key = (safe-image-name $group.image)
      let job_name = $"sync:($category):($image_key)"
      let sources = ($group.rows | get source_file | uniq | sort)

      {
        name: $job_name
        value: {
          extends: $".sync-($category)-image"
          variables: {IMAGE_TO_SYNC: $group.image}
          rules: (sync-rules $category $group.image $image_key $sources)
        }
      }
    }
}

def jobs-to-record [jobs: list<record>] {
  let names = ($jobs | get name)
  if (($names | uniq | length) != ($names | length)) {
    let duplicates = (
      $names
      | group-by
      | transpose name values
      | where {|row| ($row.values | length) > 1 }
      | get name
      | str join ", "
    )
    error make {msg: $"generated CI job names are not unique: ($duplicates)"}
  }

  $jobs | reduce -f {} {|job, result| $result | insert $job.name $job.value }
}

export def chart-rows-from-pipeline [pipeline: record] {
  let chart_jobs = (
    $pipeline
    | transpose name value
    | where {|job| $job.name | str starts-with "sync:chart:" }
  )

  if ($chart_jobs | is-empty) {
    error make {msg: "generated CI has no chart image jobs to preserve"}
  }

  $chart_jobs
  | each {|job|
      let image = ($job.value.variables.IMAGE_TO_SYNC? | default "")
      let source_files = (
        $job.value.rules
        | each {|rule| $rule.changes? | default [] }
        | flatten
        | where {|path| $path | str starts-with "apps/" }
        | where {|path| $path | str ends-with "/**/*" }
        | each {|path|
            let app_dir = ($path | str replace -r '/\*\*/\*$' '')
            $"($app_dir)/helmfile.yaml.gotmpl"
          }
        | uniq
        | sort
      )

      if ($image | is-empty) or ($source_files | is-empty) {
        error make {msg: $"invalid preserved chart image job: ($job.name)"}
      }

      $source_files
      | each {|source_file| {image: $image, source_file: $source_file} }
    }
  | flatten
  | sort-by image source_file
}

export def chart-source-hash [] {
  let source_files = (
    ^git ls-files -- apps charts infrastructure/charts infrastructure/images/config.yaml
    | lines
    | where {|path| $path | is-not-empty }
    | sort
  )

  $source_files
  | each {|path| $"($path)\u{0}((open --raw $path | hash sha256))" }
  | str join "\n"
  | hash sha256
}

export def chart-source-hash-from-pipeline [pipeline: record] {
  let metadata = (
    $pipeline
    | transpose name value
    | where name == ".chart-inventory"
  )

  if ($metadata | is-empty) {
    error make {msg: "generated CI has no chart inventory fingerprint"}
  }

  let source_hash = ($metadata | first | get value.variables.SOURCE_HASH? | default "")
  if ($source_hash | is-empty) {
    error make {msg: "generated CI has an invalid chart inventory fingerprint"}
  }

  $source_hash
}

def chart-inventory-job [source_hash: string] {
  {
    name: .chart-inventory
    value: {variables: {SOURCE_HASH: $source_hash}}
  }
}

export def pipeline-record [
  builds: list<record>
  charts: list<record>
  locals: list<record>
  chart_source_hash: string = ""
] {
  let metadata_jobs = if ($chart_source_hash | is-empty) {
    []
  } else {
    [(chart-inventory-job $chart_source_hash)]
  }
  let build_jobs = ($builds | sort-by name | each {|row| build-job $row })
  let chart_jobs = (sync-jobs chart $charts)
  let local_jobs = (sync-jobs local $locals)

  let jobs = ([$metadata_jobs $build_jobs $chart_jobs $local_jobs] | flatten)
  jobs-to-record $jobs
}

export def generated-ci-content [
  cfg: record
  builds: list<record>
  charts: list<record>
  locals: list<record>
  chart_source_hash: string
] {
  let header = "# generated by `nu ci/images.nu generate-ci`; do not edit by hand\n"
  let yaml = (pipeline-record $builds $charts $locals $chart_source_hash | to yaml)
  $header + $yaml
}

export def write-generated-ci [
  cfg: record
  builds: list<record>
  charts: list<record>
  locals: list<record>
  chart_source_hash: string
] {
  generated-ci-content $cfg $builds $charts $locals $chart_source_hash | save -f $cfg.generated_ci
}

export def verify-generated-ci [
  cfg: record
  builds: list<record>
  charts: list<record>
  locals: list<record>
  chart_source_hash: string
] {
  if not ($cfg.generated_ci | path exists) {
    error make {msg: $"generated CI file is missing: ($cfg.generated_ci)"}
  }

  let expected = (pipeline-record $builds $charts $locals $chart_source_hash)
  let actual = (open $cfg.generated_ci)

  if $actual != $expected {
    error make {msg: $"generated CI is stale; run `nu ci/images.nu generate-ci`"}
  }

  print "generated image CI is current"
}
