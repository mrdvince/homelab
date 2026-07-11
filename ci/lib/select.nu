use config.nu [env-str env-true]

def changed-files [] {
  let explicit = (env-str CHANGED_FILES)

  if ($explicit | str trim | is-not-empty) {
    return ($explicit | split row --regex '\s+' | where {|path| $path != "" })
  }

  if (which git | is-empty) {
    error make {msg: "git is not available and CHANGED_FILES is empty"}
  }

  let head = (env-str CI_COMMIT_SHA "HEAD")
  let merge_base = (env-str CI_MERGE_REQUEST_DIFF_BASE_SHA)
  let before_sha = (env-str CI_COMMIT_BEFORE_SHA)
  let zero_sha = "0000000000000000000000000000000000000000"

  let base = if ($merge_base | is-not-empty) {
    $merge_base
  } else if (($before_sha | is-not-empty) and $before_sha != $zero_sha) {
    $before_sha
  } else {
    ""
  }

  if ($base | is-empty) {
    error make {msg: "no changed-file base is available"}
  }

  ^git diff --name-only $base $head | lines | where {|path| $path != "" }
}

def touches-ci [files: list<string>] {
  $files | any {|path| $path =~ '^ci/' }
}

export def all-local-image-files [cfg: record] {
  glob $"($cfg.local_image_dir)/*.yaml"
  | path relative-to (pwd)
  | sort
}

export def local-image-files [cfg: record] {
  let explicit = (env-str LOCAL_IMAGE_FILES)

  if ($explicit | str trim | is-not-empty) {
    return ($explicit | split row --regex '\s+' | where {|path| $path != "" })
  }

  if (env-true SYNC_LOCAL_IMAGES) {
    return (all-local-image-files $cfg)
  }

  let changed = (try { changed-files } catch { null })

  if $changed == null {
    return (all-local-image-files $cfg)
  }

  if (touches-ci $changed) {
    return (all-local-image-files $cfg)
  }

  let local_re = $"^($cfg.local_image_dir)/[^/]+\\.yaml$"
  $changed | where {|path| $path =~ $local_re } | sort
}

export def all-build-rows [cfg: record] {
  glob $"($cfg.build_dir)/*.yaml"
  | path relative-to (pwd)
  | each {|source_file|
      open $source_file
      | transpose name value
      | where {|row|
          let has_dockerfile = (($row.value.dockerfile? | default "") | is-not-empty)
          let has_image = (($row.value.image? | default "") | is-not-empty)
          let has_tag = (($row.value.tag? | default "") | into string | is-not-empty)

          $has_dockerfile and $has_image and $has_tag
        }
      | each {|row|
          {
            source_file: $source_file
            name: $row.name
            repo: ($row.value.repo? | default "-")
            commit: ($row.value.commit? | default "-")
            dockerfile: $row.value.dockerfile
            image: $row.value.image
            tag: ($row.value.tag | into string)
          }
        }
    }
  | flatten
  | sort-by source_file name
}

export def build-rows [cfg: record] {
  if (env-true BUILD_IMAGES) {
    return (all-build-rows $cfg)
  }

  let changed = (try { changed-files } catch { null })

  if $changed == null {
    return (all-build-rows $cfg)
  }

  let rows = (all-build-rows $cfg)

  if (touches-ci $changed) {
    return $rows
  }

  $rows | where {|row|
    $changed | any {|path| $path == $row.source_file or $path == $row.dockerfile }
  } | sort-by source_file name
}

export def all-helmfile-paths [] {
  glob "apps/**/helmfile.yaml.gotmpl"
  | path relative-to (pwd)
  | sort
}

export def select-helmfile-for [changed_file: string] {
  mut dir = ($changed_file | path dirname)

  loop {
    if ($dir in ["" "." "/"]) {
      return null
    }

    let candidate = ([$dir "helmfile.yaml.gotmpl"] | path join)
    if ($candidate | path exists) {
      return $candidate
    }

    let parent = ($dir | path parse | get parent)
    if ($parent == $dir) {
      return null
    }

    $dir = $parent
  }
}

export def helmfile-paths [cfg: record] {
  let explicit = (env-str HELMFILE_PATHS)

  if ($explicit | str trim | is-not-empty) {
    return ($explicit | split row --regex '\s+' | where {|path| $path != "" })
  }

  if (env-true SYNC_UPSTREAM_IMAGES) {
    return (all-helmfile-paths)
  }

  let changed = (try { changed-files } catch { null })

  if $changed == null {
    return (all-helmfile-paths)
  }

  if ((touches-ci $changed) or ("infrastructure/images/config.yaml" in $changed)) {
    return (all-helmfile-paths)
  }

  $changed
  | where {|path| $path =~ '^apps/' }
  | each {|path| select-helmfile-for $path }
  | where {|path| $path != null }
  | uniq
  | sort
}
