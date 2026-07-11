use config.nu [env-str]
use select.nu [helmfile-paths local-image-files]

export def require-safe-render-dir [cfg: record] {
  if ($cfg.rendered_dir in ["" "/" "."]) {
    error make {msg: $"unsafe RENDERED_MANIFEST_DIR: ($cfg.rendered_dir)"}
  }
}

export def destination-for [cfg: record, image: string] {
  let first_part = ($image | split row "/" | first)
  let without_digest = ($image | split row "@" | first)

  let destination = if (($first_part =~ '[.:]') or $first_part == "localhost") {
    let image_without_registry = ($without_digest | str replace -r '^[^/]*/' '')
    $"($cfg.dest_registry)/($image_without_registry)"
  } else {
    $"($cfg.dest_registry)/($without_digest)"
  }

  $destination
}

export def source-for [image: string] {
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

export def safe-job-name [image: string] {
  $image
  | str replace -r '^[^/]*/' ''
  | str replace -r '@sha256:.*' ''
  | str replace -a -r '[^[:alnum:]]' '-'
  | str replace -a -r '--*' '-'
  | str replace -r '^-|-$' ''
  | str substring 0..71
}

export def login-to-destination-registry [cfg: record] {
  let user = (env-str REGISTRY_USER)
  let password = (env-str REGISTRY_PASSWORD)

  if (($user | is-empty) or ($password | is-empty)) {
    error make {msg: "REGISTRY_USER and REGISTRY_PASSWORD are required to sync images"}
  }

  $password | ^skopeo login -u $user --password-stdin $cfg.dest_registry
}

export def login-to-destination-registry-if-available [cfg: record] {
  let user = (env-str REGISTRY_USER)
  let password = (env-str REGISTRY_PASSWORD)

  if (($user | is-not-empty) and ($password | is-not-empty)) {
    $password | ^skopeo login -u $user --password-stdin $cfg.dest_registry | ignore
  }
}

export def destination-exists [destination: string] {
  let result = (^skopeo inspect --raw $"docker://($destination)" | complete)
  $result.exit_code == 0
}

export def sync-one-image [cfg: record, image: string] {
  if ($image | str starts-with $"($cfg.dest_registry)/") {
    print $"skipping ($image) - already rendered with ($cfg.dest_registry)"
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

  helmfile-paths $cfg | each {|helmfile_path|
    let output_name = (
      $helmfile_path
      | str replace -a "/" "__"
      | str replace -a " " "__"
      | $"($in).yaml"
    )
    let output_path = ([$cfg.rendered_dir $output_name] | path join)

    print $"rendering ($helmfile_path)"
    ^helmfile -f $helmfile_path -e $cfg.env_name repos | ignore
    ^helmfile -f $helmfile_path -e $cfg.env_name template --include-crds --skip-tests -q --state-values-set renderStockImages=true | save -f $output_path
  } | ignore
}

export def extract-rendered-images [cfg: record] {
  let files = (glob $"($cfg.rendered_dir)/*.yaml")

  if ($files | is-empty) {
    "" | save -f $cfg.image_list
    print "rendered images extracted: 0"
    return
  }

  let images = (
    ^yq -N -r '.. | select(tag == "!!str")' ...$files
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
  )

  let output = if ($images | is-empty) { "" } else { $images | str join (char nl) | $"($in)\n" }
  $output | save -f $cfg.image_list
  print $"rendered images extracted: (($images | length))"
}

export def extract-local-images [cfg: record] {
  let files = (local-image-files $cfg)

  let images = if ($files | is-empty) {
    []
  } else {
    $files
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
            | each {|image| $"($image.registry)/($image.image):($image.tag | into string)" }
          }
      }
    | flatten
    | flatten
    | uniq
    | sort
  }

  let output = if ($images | is-empty) { "" } else { $images | str join (char nl) | $"($in)\n" }
  $output | save -f $cfg.local_image_list
  print $"local images extracted: (($images | length))"
}
