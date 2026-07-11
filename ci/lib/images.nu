use config.nu [env-str]
use select.nu [all-helmfile-paths all-local-image-files]

def require-safe-render-dir [cfg: record] {
  if ($cfg.rendered_dir in ["" "/" "."]) {
    error make {msg: $"unsafe RENDERED_MANIFEST_DIR: ($cfg.rendered_dir)"}
  }
}

export def destination-for [cfg: record, image: string] {
  let first_part = ($image | split row "/" | first)
  let without_digest = ($image | split row "@" | first)

  if (($first_part =~ '[.:]') or $first_part == "localhost") {
    let image_without_registry = ($without_digest | str replace -r '^[^/]*/' '')
    $"($cfg.dest_registry)/($image_without_registry)"
  } else {
    $"($cfg.dest_registry)/($without_digest)"
  }
}

def source-for [image: string] {
  if not ($image =~ '@') {
    return $image
  }

  let image_without_digest = ($image | split row "@" | first)
  let digest = ($image | split row "@" | last)
  let image_tail = ($image_without_digest | split row "/" | last)

  if ($image_tail =~ ':') {
    $"($image_without_digest | str replace -r ':[^/:]+$' '')@($digest)"
  } else {
    $image
  }
}

def login-to-destination-registry [cfg: record] {
  let user = (env-str REGISTRY_USER)
  let password = (env-str REGISTRY_PASSWORD)

  if (($user | is-empty) or ($password | is-empty)) {
    error make {msg: "REGISTRY_USER and REGISTRY_PASSWORD are required to sync images"}
  }

  $password | ^skopeo login -u $user --password-stdin $cfg.dest_registry
}

def destination-exists [destination: string] {
  let result = (^skopeo inspect --raw $"docker://($destination)" | complete)
  $result.exit_code == 0
}

export def sync-one-image [cfg: record, image: string] {
  login-to-destination-registry $cfg

  if ($image | str starts-with $"($cfg.dest_registry)/") {
    print $"skipping ($image) - already mirrored"
    return
  }

  let destination = (destination-for $cfg $image)
  let source = (source-for $image)

  if (destination-exists $destination) {
    print $"skipping ($destination) - already exists"
    return
  }

  print $"syncing docker://($source) -> docker://($destination)"
  ^skopeo copy --all $"docker://($source)" $"docker://($destination)"
}

export def render-upstream-manifests [cfg: record] {
  require-safe-render-dir $cfg

  rm -rf $cfg.rendered_dir
  mkdir $cfg.rendered_dir
  let helm_plugins = (^helm env HELM_PLUGINS | str trim)

  all-helmfile-paths
  | par-each --threads $cfg.render_threads {|helmfile_path|
      let output_name = (
        $helmfile_path
        | str replace -a "/" "__"
        | str replace -a " " "__"
        | $"($in).yaml"
      )
      let output_path = ([$cfg.rendered_dir $output_name] | path join)
      let helm_home = ([$cfg.rendered_dir ".helm" $output_name] | path join)
      let helm_env = {
        HELM_CACHE_HOME: ([$helm_home "cache"] | path join)
        HELM_CONFIG_HOME: ([$helm_home "config"] | path join)
        HELM_DATA_HOME: ([$helm_home "data"] | path join)
        HELM_PLUGINS: $helm_plugins
      }

      mkdir $helm_home
      print $"rendering ($helmfile_path)"
      with-env $helm_env {
        ^helmfile -f $helmfile_path -e $cfg.env_name repos | ignore
        ^helmfile -f $helmfile_path -e $cfg.env_name template --include-crds --skip-tests -q --state-values-set renderStockImages=true | save -f $output_path
      }

      {source_file: $helmfile_path, rendered_file: $output_path}
    }
  | sort-by source_file
}

export def extract-images [rendered_file: string] {
  ^yq -N -r '.. | select(tag == "!!str")' $rendered_file
  | lines
  | each {|value| $value | split row --regex '[[:space:],;"(){}\\[\\]=]+' }
  | flatten
  | where {|image|
      let is_present = ($image | str trim | is-not-empty)
      let is_not_url = not ($image =~ '://')
      let has_image_shape = ($image =~ '^[[:alnum:]_.-]+(:[0-9]+)?/[[:alnum:]_.@:/-]+$')
      let has_tag_or_digest = ($image =~ '(:[[:alnum:]_][[:alnum:]_.-]*(@sha256:[[:xdigit:]]{64})?$|@sha256:[[:xdigit:]]{64}$)')
      let is_not_boolean_label = not ($image =~ ':(true|false)$')

      $is_present and $is_not_url and $has_image_shape and $has_tag_or_digest and $is_not_boolean_label
    }
  | uniq
  | sort
}

def rendered-manifests [cfg: record] {
  glob $"($cfg.rendered_dir)/*.yaml"
  | sort
  | each {|rendered_file|
      let source_file = (
        $rendered_file
        | path basename
        | str replace -r '\.yaml$' ''
        | str replace -a '__' '/'
      )
      {source_file: $source_file, rendered_file: $rendered_file}
    }
}

export def chart-image-rows [cfg: record, --skip-render] {
  if not $skip_render {
    render-upstream-manifests $cfg | ignore
  }

  rendered-manifests $cfg
  | each {|rendered|
      extract-images $rendered.rendered_file
      | each {|image| {image: $image, source_file: $rendered.source_file} }
    }
  | flatten
  | sort-by image source_file
}

export def local-image-rows [cfg: record] {
  all-local-image-files $cfg
  | each {|source_file|
      open $source_file
      | transpose group images
      | each {|group|
          $group.images
          | where {|image|
              let has_registry = (($image.registry? | default "") | is-not-empty)
              let has_image = (($image.image? | default "") | is-not-empty)
              let has_tag = (($image.tag? | default "") | into string | is-not-empty)

              $has_registry and $has_image and $has_tag
            }
          | each {|image|
              {
                image: $"($image.registry)/($image.image):($image.tag | into string)"
                source_file: $source_file
              }
            }
        }
    }
  | flatten
  | flatten
  | sort-by image source_file
}
