
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
  │   │   ├── aion/
  │   │   └── athos/
  │   │
  │   └── kubernetes/
  │       ├── bootstrap/
  │       │   ├── cilium/
  │       │   └── argocd/
  │       ├── aion/
  │       └── athos/
  │
  ├── dashboards/
  └── secrets/                          # Git submodule
```