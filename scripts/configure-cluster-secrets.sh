#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
: "${GITLAB_REPO_URL:?https://gitlab.com/group/releaselab.git}"
: "${GITLAB_DEPLOY_USER:?Deploy token username}" "${GITLAB_DEPLOY_TOKEN:?read_repository + read_registry token}"
command -v jq >/dev/null
umask 077
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
registry=${GITLAB_REGISTRY:-registry.gitlab.com}
printf '%s' "$GITLAB_DEPLOY_USER" > "$tmp/username"
printf '%s' "$GITLAB_DEPLOY_TOKEN" > "$tmp/password"
printf '%s' "$GITLAB_REPO_URL" > "$tmp/url"
printf git > "$tmp/type"
jq -n --arg registry "$registry" --rawfile user "$tmp/username" --rawfile pass "$tmp/password" \
  '{auths:{($registry):{username:$user,password:$pass,auth:(($user+":"+$pass)|@base64)}}}' > "$tmp/config.json"
kubectl --context kind-releaselab -n releaselab create secret generic gitlab-registry \
  --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson="$tmp/config.json" \
  --dry-run=client -o yaml | kubectl --context kind-releaselab apply --server-side -f -
kubectl --context kind-releaselab -n argocd create secret generic releaselab-repository \
  --from-file=type="$tmp/type" --from-file=url="$tmp/url" \
  --from-file=username="$tmp/username" --from-file=password="$tmp/password" \
  --dry-run=client -o yaml | kubectl --context kind-releaselab apply --server-side -f -
kubectl --context kind-releaselab -n argocd label secret releaselab-repository argocd.argoproj.io/secret-type=repository --overwrite
if ! kubectl --context kind-releaselab -n releaselab get secret releaselab-api >/dev/null 2>&1; then
  openssl rand -hex 32 | tr -d '\n' > "$tmp/api_key"
  kubectl --context kind-releaselab -n releaselab create secret generic releaselab-api --from-file=api_key="$tmp/api_key"
fi
echo 'Registry, repository and runtime API credentials configured.'
