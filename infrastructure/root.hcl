locals {
  node_vars        = read_terragrunt_config(find_in_parent_folders("node.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  aws_region       = "garage"
  pm_api_url       = local.node_vars.locals.pm_api_url
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
