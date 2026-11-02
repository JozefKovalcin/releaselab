#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
for tool in git kustomize; do command -v "$tool" >/dev/null; done
mkdir -p "$ROOT/.local"
tmp=$(mktemp -d "$ROOT/.local/gitops-test.XXXXXX")
git init --bare --initial-branch=main "$tmp/upstream.git" >/dev/null
git init --initial-branch=main "$tmp/seed" >/dev/null
cp -R "$ROOT/deploy" "$ROOT/scripts" "$tmp/seed/"
cp "$ROOT/.gitattributes" "$tmp/seed/"
cd "$tmp/seed"
mkdir app
printf 'source A\n' > app/input.txt
git config user.name 'ReleaseLab Test'
git config user.email 'test@example.invalid'
git config core.autocrlf false
git add . && git commit -qm 'source A'
sha_a=$(git rev-parse HEAD)
git remote add origin "$tmp/upstream.git"
git push -q -u origin main
git clone -q "$tmp/upstream.git" "$tmp/worker"
git -C "$tmp/worker" config core.autocrlf false
printf 'source B\n' > app/input.txt
git add app && git commit -qm 'source B'
sha_b=$(git rev-parse HEAD)
git push -q
export CI_SERVER_URL="$tmp" CI_PROJECT_PATH=upstream CI_DEFAULT_BRANCH=main CI_COMMIT_BRANCH=main
export CI_REGISTRY_IMAGE=registry.gitlab.com/test/releaselab GITOPS_PUSH_TOKEN=local-test-placeholder
run_update() { (cd "$tmp/worker"; CI_COMMIT_SHA="$1" bash scripts/update-gitops.sh); }
run_update "$sha_a"
[[ "$(git --git-dir="$tmp/upstream.git" rev-parse main)" == "$sha_b" ]]
run_update "$sha_b"
git fetch -q origin
[[ "$(git diff --name-only "$sha_b" origin/main)" == deploy/overlays/dev/kustomization.yaml ]]
git show origin/main:deploy/overlays/dev/kustomization.yaml | grep -q "$sha_b"
deployed=$(git rev-parse origin/main)
run_update "$sha_b"
[[ "$(git --git-dir="$tmp/upstream.git" rev-parse main)" == "$deployed" ]]
git pull -q --ff-only
printf 'docs only\n' > README.md
git add README.md && git commit -qm 'docs only'
git push -q
docs=$(git rev-parse HEAD)
run_update "$sha_b"
[[ "$(git --git-dir="$tmp/upstream.git" rev-parse main)" == "$docs" ]]
git switch -qc feature
printf 'source C\n' > app/input.txt
git add app && git commit -qm 'source C'
git switch -q main
printf 'more docs\n' >> README.md
git add README.md && git commit -qm 'more docs'
git merge -q --no-ff feature -m 'merge source C'
sha_merge=$(git rev-parse HEAD)
git push -q
run_update "$sha_b"
[[ "$(git --git-dir="$tmp/upstream.git" rev-parse main)" == "$sha_merge" ]]
run_update "$sha_merge"
git fetch -q origin
git show origin/main:deploy/overlays/dev/kustomization.yaml | grep -q "$sha_merge"
cd "$tmp/worker"
bash scripts/bump-image.sh "$CI_REGISTRY_IMAGE" "$sha_a"
kustomize build deploy/overlays/dev | grep -q "$CI_REGISTRY_IMAGE:$sha_a"
git add deploy/overlays/dev/kustomization.yaml
git commit -qm 'rollback through Git'
git push -q origin HEAD:main
git --git-dir="$tmp/upstream.git" show main:deploy/overlays/dev/kustomization.yaml | grep -q "$sha_a"
if bash scripts/bump-image.sh "$CI_REGISTRY_IMAGE" invalid 2>/dev/null; then
  echo 'Invalid image tag was accepted' >&2; exit 1
fi
echo 'GitOps integration passed: stale builds, idempotency, docs-only commits, merge commits, rollback and tag validation.'
echo "Ignored test fixtures retained in $tmp"
