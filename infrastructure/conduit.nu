const infisical_domain = "https://infisical.home.mrdvince.me"
const infisical_project = "0b29d425-2822-4168-b95f-38127a2e80d7"

# run terragrunt with the operational infisical secret set.
def --wrapped main [...terragrunt_args: string] {
  ^infisical run --silent --log-level=error $"--domain=($infisical_domain)" $"--projectId=($infisical_project)" --env=prod --path=/infrastructure -- terragrunt ...$terragrunt_args
}
