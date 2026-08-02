include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/argocd.hcl"
}

dependency "cluster" {
  config_path = "../cluster"
}

locals {
  secret_vars = try(
    {
      gitlab_deploy_key = get_env("GITLAB_DEPLOY_KEY")
    },
    yamldecode(sops_decrypt_file("${dirname(find_in_parent_folders("root.hcl"))}/../secrets/secrets.enc.yaml")),
  )
}

inputs = {
  kubernetes_host               = dependency.cluster.outputs.kubernetes_client_configuration.host
  kubernetes_client_certificate = dependency.cluster.outputs.kubernetes_client_configuration.client_certificate
  kubernetes_client_key         = dependency.cluster.outputs.kubernetes_client_configuration.client_key
  kubernetes_ca_certificate     = dependency.cluster.outputs.kubernetes_client_configuration.ca_certificate

  sops_age_key = get_env("SOPS_AGE_KEY")

  repositories = {
    homelab = {
      url      = "git@gitlab.home.mrdvince.me:homelab/homelab.git"
      ssh_key  = local.secret_vars.gitlab_deploy_key
      insecure = true
    }
  }

  root_app = {
    repo_url = "git@gitlab.home.mrdvince.me:homelab/homelab.git"
    env_name = "aion"
  }
}
