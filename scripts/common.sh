#!/usr/bin/env bash
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
compose() { docker compose --env-file "$ROOT/.env" -f "$ROOT/infra/compose.yaml" "$@"; }
vault_cli() { compose exec -T vault vault "$@"; }
