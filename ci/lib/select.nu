export def all-local-image-files [cfg: record] {
  glob $"($cfg.local_image_dir)/*.yaml"
  | path relative-to (pwd)
  | sort
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
  | sort-by name
}

export def all-helmfile-paths [] {
  glob "apps/**/helmfile.yaml.gotmpl"
  | path relative-to (pwd)
  | sort
}
