#!/usr/bin/env bash
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case "$(uname -s)" in
  MINGW*|MSYS*) ROOT=$(cygpath -m "$ROOT") ;;
esac
compose() { MSYS_NO_PATHCONV=1 docker compose --env-file "$ROOT/.env" -f "$ROOT/infra/compose.yaml" "$@"; }
vault_cli() { compose exec -T vault vault "$@"; }
