use images.nu [destination-exists destination-for login-to-destination-registry-if-available safe-job-name source-for]

def numbered-id [value: int] {
  $value | fill --alignment right --character "0" --width 3
}

def image-job [cfg: record, job_prefix: string, sync_command: string, id: int, image: string] {
  let job_id = (numbered-id $id)
  let job_name = (safe-job-name $image)

  {
    name: $"($job_prefix)-($job_id)-($job_name)"
    value: {
      stage: sync
      image: {
        name: $cfg.builder_image
        entrypoint: [""]
      }
      variables: {
        IMAGE_TO_SYNC: $image
      }
      script: [
        ("nu ci/images.nu " + $sync_command + " \"$IMAGE_TO_SYNC\"")
      ]
    }
  }
}

def empty-image-job [cfg: record, job_prefix: string, empty_message: string] {
  {
    name: $"($job_prefix)-images-current"
    value: {
      stage: sync
      image: {
        name: $cfg.builder_image
        entrypoint: [""]
      }
      script: [
        $"echo \"($empty_message)\""
      ]
    }
  }
}

def write-yaml-record [pipeline: record, path: string] {
  $pipeline | to yaml | save -f $path
}

export def write-image-pipeline [
  cfg: record
  list_file: string
  pipeline_file: string
  job_prefix: string
  sync_command: string
  empty_message: string
] {
  login-to-destination-registry-if-available $cfg

  let images = if ($list_file | path exists) {
    open --raw $list_file | lines | where {|image| $image != "" }
  } else {
    []
  }

  mut skipped = 0
  mut jobs = []

  for image in $images {
    if ($image | str starts-with $"($cfg.dest_registry)/") {
      print $"skipping ($image) - already rendered with ($cfg.dest_registry)"
      $skipped = $skipped + 1
      continue
    }

    let destination = (destination-for $cfg $image)
    if (destination-exists $destination) {
      print $"skipping ($destination) - already exists"
      $skipped = $skipped + 1
      continue
    }

    let id = (($jobs | length) + 1)
    $jobs = ($jobs | append (image-job $cfg $job_prefix $sync_command $id $image))
  }

  let generated = ($jobs | length)

  if ($jobs | is-empty) {
    $jobs = [(empty-image-job $cfg $job_prefix $empty_message)]
  }

  let job_record = ($jobs | reduce -f {} {|job, acc| $acc | insert $job.name $job.value })
  let pipeline = ({stages: [sync]} | merge $job_record)

  write-yaml-record $pipeline $pipeline_file

  print $"($job_prefix) image jobs generated: ($generated)"
  print $"($job_prefix) images skipped: ($skipped)"
}

export def write-chart-pipeline [cfg: record] {
  write-image-pipeline $cfg $cfg.image_list $cfg.chart_pipeline chart chart-sync-one "no chart images found"
}

export def write-local-pipeline [cfg: record] {
  write-image-pipeline $cfg $cfg.local_image_list $cfg.local_pipeline local local-sync-one "no local images found"
}

export def write-chart-plan [cfg: record] {
  if not ($cfg.image_list | path exists) {
    return
  }

  let lines = (
    open --raw $cfg.image_list
    | lines
    | where {|image| $image != "" }
    | each {|image|
      if ($image | str starts-with $"($cfg.dest_registry)/") {
        $"skip ($image) - already rendered with ($cfg.dest_registry)"
      } else {
        let destination = (destination-for $cfg $image)
        let source = (source-for $image)
        $"skopeo copy --all docker://($source) docker://($destination)"
      }
    }
  )

  for line in $lines {
    print $line
  }
}

export def write-local-plan [cfg: record] {
  if not ($cfg.local_image_list | path exists) {
    return
  }

  let lines = (
    open --raw $cfg.local_image_list
    | lines
    | where {|image| $image != "" }
    | each {|image|
      let destination = (destination-for $cfg $image)
      let source = (source-for $image)
      $"skopeo copy --all docker://($source) docker://($destination)"
    }
  )

  for line in $lines {
    print $line
  }
}
