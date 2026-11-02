#!/usr/bin/env bash
set -euo pipefail
image="${1:?Usage: bump-image.sh IMAGE FULL_SHA}"
tag="${2:?Usage: bump-image.sh IMAGE FULL_SHA}"
[[ "$image" =~ ^[a-zA-Z0-9][a-zA-Z0-9./:_-]*$ ]] || { echo 'Invalid image name' >&2; exit 1; }
[[ "$tag" =~ ^[a-f0-9]{40}$ ]] || { echo 'Tag must be a full 40-character commit SHA' >&2; exit 1; }
cd "$(dirname "$0")/../deploy/overlays/dev"
kustomize edit set image "release-demo=${image}:${tag}"
