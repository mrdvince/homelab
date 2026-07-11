export def env-str [name: string, fallback: string = ""] {
  if ($name in ($env | columns)) {
    $env | get $name
  } else {
    $fallback
  }
}

export def settings [] {
  let tmp_dir = (env-str TMPDIR "/tmp")

  {
    env_name: (env-str ENV_NAME "aion")
    dest_registry: (env-str DEST_REGISTRY "registry.home.mrdvince.me")
    rendered_dir: (env-str RENDERED_MANIFEST_DIR ([$tmp_dir "homelab-rendered-manifests"] | path join))
    generated_ci: (env-str GENERATED_IMAGE_CI "ci/generated-images.gitlab-ci.yml")
    local_image_dir: (env-str LOCAL_IMAGE_DIR "infrastructure/images/images/local")
    build_dir: (env-str BUILD_DIR "infrastructure/images/builds")
    builder_image: (env-str BUILDER_IMAGE "registry.home.mrdvince.me/homelab/builder:1.4.3")
    builder_bootstrap_image: (env-str BUILDER_BOOTSTRAP_IMAGE "registry.home.mrdvince.me/homelab/builder:1.4.3")
  }
}
