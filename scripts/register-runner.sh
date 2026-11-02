#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
: "${RUNNER_AUTH_TOKEN:?Set RUNNER_AUTH_TOKEN to the glrt- token from GitLab runner creation}"
export RUNNER_TOKEN="$RUNNER_AUTH_TOKEN"
compose exec -T -e RUNNER_TOKEN runner sh -ec '
  gitlab-runner register --non-interactive \
    --url https://gitlab.com --token "$RUNNER_TOKEN" \
    --executor docker --docker-image node:24-bookworm-slim \
    --description releaselab-local --template-config /templates/config.toml
'
echo 'Runner registered; ensure its GitLab tag is releaselab and it is locked to this project.'
