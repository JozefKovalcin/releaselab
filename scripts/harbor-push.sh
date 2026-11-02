#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
image="${1:?Usage: harbor-push.sh SOURCE_IMAGE FULL_SHA}"
tag="${2:?Usage: harbor-push.sh SOURCE_IMAGE FULL_SHA}"
: "${HARBOR_PASSWORD:?Set HARBOR_PASSWORD}"
[[ "$tag" =~ ^[a-f0-9]{40}$ ]] || { echo 'Tag must be a full commit SHA' >&2; exit 1; }
registry="${HARBOR_REGISTRY:-localhost:8088}"
destination="$registry/library/releaselab:$tag"
export DOCKER_CONFIG
mkdir -p "$ROOT/.local"
DOCKER_CONFIG=$(mktemp -d "$ROOT/.local/docker-auth.XXXXXX")
trap 'rm -rf -- "$DOCKER_CONFIG"' EXIT
printf '%s' "$HARBOR_PASSWORD" | docker login "$registry" -u "${HARBOR_USER:-admin}" --password-stdin
docker tag "$image" "$destination"
docker push "$destination"
