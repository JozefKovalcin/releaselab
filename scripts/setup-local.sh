#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
umask 077
command -v docker >/dev/null
command -v openssl >/dev/null
mkdir -p "$ROOT/.local"
if [[ ! -f "$ROOT/.env" ]]; then
  printf 'VAULT_DEV_ROOT_TOKEN_ID=%s\n' "$(openssl rand -hex 32)" > "$ROOT/.env"
fi
compose up -d
compose exec -T runner gitlab-runner --version
for ((i=0; i<30; i++)); do
  if vault_cli status >/dev/null 2>&1; then echo 'Runner and Vault are ready'; exit 0; fi
  sleep 2
done
echo 'Vault did not become ready' >&2
exit 1
