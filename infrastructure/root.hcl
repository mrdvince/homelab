locals {
  node_vars        = read_terragrunt_config(find_in_parent_folders("node.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  aws_region       = "garage"
  secret_vars  = yamldecode(sops_decrypt_file("${dirname(find_in_parent_folders("root.hcl"))}/../secrets/secrets.enc.yaml"))

  pm_api_token_id     = local.secret_vars.pm_api_token_id
  pm_api_token_secret = local.secret_vars.pm_api_token_secret
  cipassword          = try(local.secret_vars.cipassword, "")
  pm_api_url          = local.node_vars.locals.pm_api_url
  authentik_token     = local.secret_vars.authentik

  providers_file   = "${get_terragrunt_dir()}/providers.yaml"
  module_providers = try(yamldecode(file(local.providers_file)).providers, ["proxmox", "random"])

  provider_registry = {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.4.0"
      config  = <<-EOF
        provider "authentik" {
          url   = "https://auth.home.mrdvince.me"
          token = "${local.authentik_token}"
        }
      EOF
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.89.1"
      config  = <<-EOF
        provider "proxmox" {
          endpoint  = "${local.pm_api_url}"
          api_token = "${local.pm_api_token_id}=${local.pm_api_token_secret}"
          insecure  = false
        }
      EOF
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
      config  = ""
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
      config  = ""
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
      config  = ""
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
      config  = ""
    }
  }

  required_providers = {
    for name in local.module_providers : name => {
      source  = local.provider_registry[name].source
      version = local.provider_registry[name].version
    } if contains(keys(local.provider_registry), name)
  }

  provider_configs = [
    for name in local.module_providers : local.provider_registry[name].config
    if contains(keys(local.provider_registry), name) && local.provider_registry[name].config != ""
  ]
}

remote_state {
  backend = "s3"
  config = {
    bucket                             = "terragrunt-state"
    key                                = "${path_relative_to_include()}/state.tfstate"
    region                             = local.aws_region
    endpoint                           = local.environment_vars.locals.s3_endpoint_url
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

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    terraform {
      required_providers {
    %{for name, config in local.required_providers~}
        ${name} = {
          source  = "${config.source}"
          version = "${config.version}"
        }
    %{endfor~}
      }
    }
  EOF
}

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite"
  contents  = join("\n\n", local.provider_configs)
}
