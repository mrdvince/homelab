export def env-str [name: string, fallback: string = ""] {
  $env | get -o $name | default $fallback
}

export def env-true [name: string] {
  (env-str $name) == "true"
}

export def settings [] {
  {
    env_name: (env-str ENV_NAME "aion")
    dest_registry: (env-str DEST_REGISTRY "registry.home.mrdvince.me")
    rendered_dir: (env-str RENDERED_MANIFEST_DIR ".rendered-manifests")
    image_list: (env-str IMAGE_LIST "imagelist.txt")
    chart_pipeline: (env-str CHART_IMAGE_PIPELINE "chart-images.yml")
    local_image_dir: (env-str LOCAL_IMAGE_DIR "infrastructure/images/images/local")
    local_image_list: (env-str LOCAL_IMAGE_LIST "local-imagelist.txt")
    local_pipeline: (env-str LOCAL_IMAGE_PIPELINE "local-images.yml")
    build_dir: (env-str BUILD_DIR "infrastructure/images/builds")
    build_list: (env-str BUILD_LIST "build-images.txt")
    build_pipeline: (env-str BUILD_PIPELINE "build-images.yml")
    builder_image: (env-str BUILDER_IMAGE "registry.home.mrdvince.me/homelab/builder:1.4.3")
    builder_bootstrap_image: (env-str BUILDER_BOOTSTRAP_IMAGE "registry.home.mrdvince.me/homelab/builder:1.4.3")
  }
}
