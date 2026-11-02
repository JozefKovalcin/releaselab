#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
for tool in kind kubectl curl; do command -v "$tool" >/dev/null; done
if ! kind get clusters | grep -qx releaselab; then kind create cluster --config "$ROOT/infra/kind.yaml"; fi
kubectl --context kind-releaselab create namespace argocd --dry-run=client -o yaml | kubectl --context kind-releaselab apply -f -
version=${ARGOCD_VERSION:-v3.2.0}
manifest=$(mktemp)
trap 'rm -f "$manifest"' EXIT
curl -fsSL "https://raw.githubusercontent.com/argoproj/argo-cd/${version}/manifests/install.yaml" -o "$manifest"
kubectl --context kind-releaselab apply --server-side --force-conflicts -n argocd -f "$manifest"
kubectl --context kind-releaselab -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl --context kind-releaselab create namespace releaselab --dry-run=client -o yaml | kubectl --context kind-releaselab apply -f -
echo 'Cluster and Argo CD ready. Configure credentials before applying argocd/application.yaml.'
