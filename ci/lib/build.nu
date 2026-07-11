use config.nu [env-str]
use select.nu [all-build-rows]

def optional-value [value: string] {
  if $value == "-" { "" } else { $value }
}

export def wait-for-docker [] {
  print "waiting for docker daemon"

  for _ in 1..30 {
    let result = (^docker info | complete)
    if $result.exit_code == 0 {
      print "docker daemon ready"
      return
    }
    sleep 2sec
  }

  ^docker info
  error make {msg: "docker daemon did not become ready"}
}

export def build-image [cfg: record, name: string] {
  let matches = (all-build-rows $cfg | where name == $name)
  if ($matches | is-empty) {
    error make {msg: $"unknown build image: ($name)"}
  }
  if (($matches | length) != 1) {
    error make {msg: $"build image name is not unique: ($name)"}
  }

  let row = ($matches | first)
  let user = (env-str REGISTRY_USER)
  let password = (env-str REGISTRY_PASSWORD)

  if (($user | is-empty) or ($password | is-empty)) {
    error make {msg: "REGISTRY_USER and REGISTRY_PASSWORD are required to build images"}
  }

  let project_dir = (env-str CI_PROJECT_DIR (pwd))
  let destination = $"($cfg.dest_registry)/($row.image):($row.tag)"
  let build_repo = (optional-value $row.repo)
  mut context_dir = $project_dir

  $password | ^docker login -u $user --password-stdin $cfg.dest_registry

  if ($build_repo | is-not-empty) {
    $context_dir = ([$project_dir ".build" $row.name] | path join)
    rm -rf $context_dir
    mkdir (($context_dir | path dirname))
    ^git clone --filter=blob:none $build_repo $context_dir

    let build_commit = (optional-value $row.commit)
    if ($build_commit | is-not-empty) {
      ^git -C $context_dir checkout --detach $build_commit
    }
  }

  ^docker build -f ([$project_dir $row.dockerfile] | path join) -t $destination $context_dir
  ^docker push $destination
}
