use config.nu [env-str]
use images.nu [safe-job-name]
use select.nu [build-rows]

def optional-value [value: string] {
  if $value == "-" { "" } else { $value }
}

def numbered-id [value: int] {
  $value | fill --alignment right --character "0" --width 3
}

def wait-for-docker-command [] {
  [
    "nu -c 'print \"waiting for docker daemon\""
    "for _ in 1..30 { let result = (^docker info | complete); if $result.exit_code == 0 { print \"docker daemon ready\"; exit 0 }; sleep 2sec }"
    "^docker info"
    "exit 1'"
  ] | str join "; "
}

def rows-from-list [path: string] {
  if not ($path | path exists) {
    return []
  }

  open --raw $path
  | lines
  | where {|line| $line != "" }
  | parse "{source_file}\t{name}\t{repo}\t{commit}\t{dockerfile}\t{image}\t{tag}"
}

export def extract-build-images [cfg: record] {
  let rows = (build-rows $cfg)

  $rows
  | select source_file name repo commit dockerfile image tag
  | to tsv --noheaders
  | save -f $cfg.build_list

  print $"build images extracted: (($rows | length))"
}

def build-job [cfg: record, id: int, row: record] {
  let job_id = (numbered-id $id)
  let job_name = (safe-job-name $"($row.image):($row.tag)")

  {
    name: $"build-($job_id)-($job_name)"
    value: {
      stage: build
      image: {
        name: $cfg.builder_bootstrap_image
        entrypoint: [""]
      }
      services: [
        {
          name: "docker:29-dind"
          alias: docker
          command: ["--tls=false"]
        }
      ]
      variables: {
        DOCKER_TLS_CERTDIR: ""
        DOCKER_HOST: "tcp://docker:2375"
        DOCKER_BUILDKIT: "1"
        BUILD_NAME: $row.name
        BUILD_REPO: (optional-value $row.repo)
        BUILD_COMMIT: (optional-value $row.commit)
        BUILD_DOCKERFILE: $row.dockerfile
        BUILD_IMAGE: $row.image
        BUILD_TAG: $row.tag
      }
      before_script: [
        (wait-for-docker-command)
      ]
      script: [
        "nu ci/images.nu build-one"
      ]
    }
  }
}

export def write-build-pipeline [cfg: record] {
  let rows = (rows-from-list $cfg.build_list)

  let jobs = if ($rows | is-empty) {
    [
      {
        name: build-images-current
        value: {
          stage: build
          image: "docker:29"
          script: ["echo \"no build images found\""]
        }
      }
    ]
  } else {
    $rows
    | enumerate
    | each {|item| build-job $cfg ($item.index + 1) $item.item }
  }

  let job_record = ($jobs | reduce -f {} {|job, acc| $acc | insert $job.name $job.value })
  ({stages: [build]} | merge $job_record) | to yaml | save -f $cfg.build_pipeline

  let count = if (($rows | is-empty)) { 0 } else { $rows | length }
  print $"build image jobs generated: ($count)"
}

export def write-build-plan [cfg: record] {
  for row in (rows-from-list $cfg.build_list) {
    let repo = (optional-value $row.repo)
    let commit = (optional-value $row.commit)

    if ($repo | is-not-empty) {
      print $"docker build -f ($row.dockerfile) -t ($cfg.dest_registry)/($row.image):($row.tag) <clone ($repo)@($commit)>"
    } else {
      print $"docker build -f ($row.dockerfile) -t ($cfg.dest_registry)/($row.image):($row.tag) ."
    }

    print $"docker push ($cfg.dest_registry)/($row.image):($row.tag)"
  }
}

export def build-one-image [cfg: record] {
  let user = (env-str REGISTRY_USER)
  let password = (env-str REGISTRY_PASSWORD)

  if (($user | is-empty) or ($password | is-empty)) {
    error make {msg: "REGISTRY_USER and REGISTRY_PASSWORD are required to build images"}
  }

  let dockerfile = (env-str BUILD_DOCKERFILE)
  let image = (env-str BUILD_IMAGE)
  let tag = (env-str BUILD_TAG)

  if (($dockerfile | is-empty) or ($image | is-empty) or ($tag | is-empty)) {
    error make {msg: "BUILD_DOCKERFILE, BUILD_IMAGE, and BUILD_TAG are required"}
  }

  let project_dir = (env-str CI_PROJECT_DIR (pwd))
  let destination = $"($cfg.dest_registry)/($image):($tag)"
  mut context_dir = $project_dir

  $password | ^docker login -u $user --password-stdin $cfg.dest_registry

  let build_repo = (env-str BUILD_REPO)
  if ($build_repo | is-not-empty) {
    let build_name = (env-str BUILD_NAME "source")
    $context_dir = ([$project_dir ".build" $build_name] | path join)
    rm -rf $context_dir
    mkdir (($context_dir | path dirname))
    ^git clone --filter=blob:none $build_repo $context_dir

    let build_commit = (env-str BUILD_COMMIT)
    if ($build_commit | is-not-empty) {
      ^git -C $context_dir checkout --detach $build_commit
    }
  }

  ^docker build -f ([$project_dir $dockerfile] | path join) -t $destination $context_dir
  ^docker push $destination
}
