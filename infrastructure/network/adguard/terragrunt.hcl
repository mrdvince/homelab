locals {
  secret_vars    = yamldecode(sops_decrypt_file("${dirname(find_in_parent_folders("root.hcl"))}/../secrets/secrets.enc.yaml"))
  adguard_url    = trimsuffix(local.secret_vars.adhome.url, "/")
  adguard_scheme = startswith(local.adguard_url, "http://") ? "http" : "https"
  adguard_host = trimprefix(
    trimprefix(local.adguard_url, "https://"),
    "http://",
  )
}

remote_state {
  backend = "s3"
  config = {
    bucket                             = "terragrunt-state"
    key                                = "dns/state.tfstate"
    region                             = "home"
    endpoint                           = "https://s3.home.mrdvince.me"
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_enforced_tls           = true
    skip_bucket_root_access            = true
    skip_credentials_validation        = true
    skip_region_validation             = true
    use_path_style                     = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

terraform {
  source = "./"
}

inputs = {
  adguard_host     = local.adguard_host
  adguard_scheme   = local.adguard_scheme
  adguard_username = local.secret_vars.adhome.user
  adguard_password = local.secret_vars.adhome.password

  domain_maps = {
    "auth.home.mrdvince.me"         = "10.30.100.13"
    "forward.auth.home.mrdvince.me" = "10.30.100.13"
    "garage.home.mrdvince.me"       = "10.30.100.13"
    "garage-s3.home.mrdvince.me"    = "10.30.100.13"
    "vale.home.mrdvince.me"         = "192.168.50.1"
    "weave.home.mrdvince.me"        = "10.30.100.13"
    "crypt.home.mrdvince.me"        = "10.30.100.13"
    "aegis.home.mrdvince.me"        = "10.30.100.13"
    "avalon.home.mrdvince.me"       = "10.30.100.13"
    "registry.home.mrdvince.me"     = "10.30.100.13"
    "vaultwarden.home.mrdvince.me"  = "10.30.100.13"
    "ntfy.home.mrdvince.me"         = "10.30.100.13"
    "status.home.mrdvince.me"       = "10.30.100.13"
    "immich.home.mrdvince.me"       = "10.30.100.13"
    "navidrome.home.mrdvince.me"    = "10.30.100.13"
    "dns.home.mrdvince.me"          = "192.168.50.120"
    "rustfs.home.mrdvince.me"       = "10.30.100.13"
    "s3.home.mrdvince.me"           = "10.30.100.13"
  }
}
