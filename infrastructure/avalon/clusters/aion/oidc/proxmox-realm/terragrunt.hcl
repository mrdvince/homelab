include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  pm_api_token_id     = include.root.locals.pm_api_token_id
  pm_api_token_secret = include.root.locals.pm_api_token_secret
  pm_api_url          = include.root.locals.pm_api_url
}

dependency "authentik" {
  config_path = "../proxmox"
}

terraform {
  source = "${get_terragrunt_dir()}//."

  after_hook "create_realm" {
    commands = ["apply"]
    execute = ["bash", "-c", <<-BASH
        STATUS=$(curl -k -s -o /dev/null -w "%%{http_code}" \
        "${local.pm_api_url}/access/domains/authentik" \
        -H "Authorization: PVEAPIToken=${local.pm_api_token_id}=${local.pm_api_token_secret}")

        if [ "$STATUS" = "200" ]; then
            echo "Realm 'authentik' already exists"
        else
            echo "Creating realm 'authentik'"
            curl -k -X POST "${local.pm_api_url}/access/domains" \
                -H "Authorization: PVEAPIToken=${local.pm_api_token_id}=${local.pm_api_token_secret}" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                --data-urlencode "realm=authentik" \
                --data-urlencode "type=openid" \
                --data-urlencode "issuer-url=https://auth.home.mrdvince.me/application/o/proxmox/" \
                --data-urlencode "client-id=${dependency.authentik.outputs.client_id["proxmox"]}" \
                --data-urlencode "client-key=${dependency.authentik.outputs.client_secret["proxmox"]}" \
                --data-urlencode "username-claim=preferred_username" \
                --data-urlencode "autocreate=1" \
                --data-urlencode "default=1"
        fi
    BASH
    ]
  }

  before_hook "delete_realm" {
    commands = ["destroy"]
    execute = ["bash", "-c", <<-BASH
      curl -k -X DELETE "${local.pm_api_url}/access/domains/authentik" \
        -H "Authorization: PVEAPIToken=${local.pm_api_token_id}=${local.pm_api_token_secret}"
    BASH
    ]
  }
}
