#!/bin/bash

echo "Waiting for ArgoCD namespace to exist..."
for i in {1..12}; do
  if kubectl get namespace argocd >/dev/null 2>&1; then
    echo "ArgoCD namespace found!"
    break
  fi
  if [ $i -eq 12 ]; then
    echo "Timed out waiting for ArgoCD namespace"
    exit 1
  fi
  echo "ArgoCD namespace not found yet. Waiting 5 seconds..."
  sleep 5
done

echo "Creating repository secret with SSH key..."
kubectl -n argocd apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: repo-github-homelab
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: git@github.com:mrdvince/homelab.git
  sshPrivateKey: |
$(cat ${HOME}/.ssh/id_ed25519 | sed 's/^/    /')
  insecure: "true"
  enableLfs: "false"
EOF
echo "Added GitHub repository with SSH authentication!"
