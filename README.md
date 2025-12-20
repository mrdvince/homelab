
```
 homelab/
  ├── apps/
  │   ├── _argocd/                      # App-of-apps definitions
  │   │   ├── helmfile.yaml
  │   │   ├── base.values.yaml
  │   │   ├── aion.values.yaml
  │   │   └── athos.values.yaml
  │   │
  │   ├── core/                         # Platform essentials
  │   │   ├── cert-manager/
  │   │   ├── traefik/
  │   │   ├── storage/
  │   │   └── monitoring/
  │   │
  │   └── services/                     # Everything else
  │       ├── authentik/
  │       ├── cnpg/
  │       ├── chartmuseum/
  │       ├── external-dns/
  │       └── ...
  │
  ├── charts/
  │   ├── secrets/
  │   ├── certificates/
  │   └── ...
  │
  ├── infrastructure/
  │   ├── proxmox/
  │   │   ├── root.hcl
  │   │   ├── _envcommon/
  │   │   ├── avalon/                     # proxmox node
  │   │   │   ├── node.hcl
  │   │   │   └── clusters/
  │   │   │       └── aion/
  │   │   │           ├── env.hcl
  │   │   │           ├── cluster/
  │   │   │           ├── cp/
  │   │   │           ├── workers/
  │   │   │           ├── outposts/
  │   │   │           └── oidc/
  │   │   └── elysium/                    # proxmox node
  │   │       ├── node.hcl
  │   │       └── clusters/
  │   │           └── aion/
  │   │               └── workers/        # workers joining avalon's aion
  │   │
  │   └── kubernetes/
  │       └── bootstrap/
  │           ├── cilium/
  │           └── argocd/
  │
  ├── dashboards/
  └── secrets/                          # Git submodule
```