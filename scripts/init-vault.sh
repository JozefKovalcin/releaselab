#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
umask 077
mode=${1:-jwt}
[[ "$mode" == jwt || "$mode" == token ]] || { echo 'Usage: init-vault.sh [jwt|token]' >&2; exit 1; }
vault_cli policy write releaselab-ci /bootstrap/ci-policy.hcl >/dev/null
if ! vault_cli kv get secret/releaselab/ci >/dev/null 2>&1; then
  key=$(openssl rand -hex 32)
  printf '{"api_key":"%s"}' "$key" | vault_cli kv put secret/releaselab/ci - >/dev/null
  unset key
fi
printf '{"example":"access-must-be-denied"}' | vault_cli kv put secret/releaselab/forbidden - >/dev/null
if [[ "$mode" == jwt ]]; then
  : "${GITLAB_PROJECT_ID:?Set numeric GitLab project ID}"
  [[ "$GITLAB_PROJECT_ID" =~ ^[0-9]+$ ]] || { echo 'Invalid project ID' >&2; exit 1; }
  command -v jq >/dev/null
  if ! vault_cli auth list -format=json | jq -e 'has("jwt/")' >/dev/null; then
    vault_cli auth enable jwt >/dev/null
  fi
  vault_cli write auth/jwt/config oidc_discovery_url=https://gitlab.com bound_issuer=https://gitlab.com >/dev/null
  jq -n --arg project "$GITLAB_PROJECT_ID" --arg audience "${VAULT_AUDIENCE:-https://releaselab.local/vault}" '{
    role_type: "jwt", user_claim: "sub", bound_audiences: [$audience],
    bound_claims: {project_id: $project, job_project_id: $project, ref_type: "branch"},
    token_policies: ["releaselab-ci"], token_no_default_policy: true,
    token_explicit_max_ttl: 300
  }' | vault_cli write auth/jwt/role/releaselab-ci - >/dev/null
  echo 'JWT auth configured: same project, branch refs, 5 minute maximum token TTL.'
else
  mkdir -p "$ROOT/.local"
  vault_cli token create -policy=releaselab-ci -no-default-policy -ttl=24h -explicit-max-ttl=24h -field=token > "$ROOT/.local/ci-vault-token"
  chmod 600 "$ROOT/.local/ci-vault-token"
  echo 'Scoped token saved to .local/ci-vault-token (24h); add it as masked VAULT_TOKEN in GitLab.'
fi
echo 'Vault policy and test fixtures initialized. No secret values printed.'
