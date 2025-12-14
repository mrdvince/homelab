#!/bin/bash

echo "waiting for argocd namespace to exist..."
for i in {1..12}; do
  if kubectl get namespace argocd >/dev/null 2>&1; then
    echo "argocd namespace found"
    break
  fi
  if [ $i -eq 12 ]; then
    echo "timed out waiting for argocd namespace"
    exit 1
  fi
  echo "argocd namespace not found yet, waiting 5 seconds..."
  sleep 5
done

echo "creating repository secrets with ssh key..."

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
echo "added homelab repository"

kubectl -n argocd apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: repo-github-hllab
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: git@github.com:mrdvince/hllab.git
  sshPrivateKey: |
$(cat ${HOME}/.ssh/id_ed25519 | sed 's/^/    /')
  insecure: "true"
  enableLfs: "false"
EOF
echo "added hllab repository"

echo "github repositories configured with ssh authentication"
