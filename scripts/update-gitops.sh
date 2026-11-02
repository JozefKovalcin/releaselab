#!/usr/bin/env bash
set -euo pipefail
: "${CI_COMMIT_SHA:?}" "${CI_DEFAULT_BRANCH:?}" "${CI_REGISTRY_IMAGE:?}" "${GITOPS_PUSH_TOKEN:?}"
[[ "${CI_COMMIT_BRANCH:-}" == "$CI_DEFAULT_BRANCH" ]] || { echo 'Only default branch may update GitOps'; exit 1; }
cd "$(dirname "$0")/.."
askpass=$(mktemp)
trap 'rm -f "$askpass"' EXIT
cat > "$askpass" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' oauth2 ;;
  *) printf '%s\n' "$GITOPS_PUSH_TOKEN" ;;
esac
EOF
chmod 700 "$askpass"
export GIT_ASKPASS="$askpass" GIT_TERMINAL_PROMPT=0
git remote set-url origin "${CI_SERVER_URL}/${CI_PROJECT_PATH}.git"
git config user.name 'ReleaseLab GitOps'
git config user.email 'releaselab-bot@example.invalid'
for attempt in 1 2 3; do
  git fetch origin "$CI_DEFAULT_BRANCH"
  git checkout -B gitops-update "origin/$CI_DEFAULT_BRANCH"
  newer=$(git log -1 --format=%H "$CI_COMMIT_SHA..HEAD" -- app scripts Dockerfile .dockerignore .gitlab-ci.yml)
  if ! git merge-base --is-ancestor "$CI_COMMIT_SHA" HEAD || [[ -n "$newer" ]]; then
    echo 'A newer application/build input exists; skip stale deployment.'
    exit 0
  fi
  bash scripts/bump-image.sh "$CI_REGISTRY_IMAGE" "$CI_COMMIT_SHA"
  git add deploy/overlays/dev/kustomization.yaml
  git diff --cached --quiet && { echo 'Desired version already committed'; exit 0; }
  git commit -m "chore(gitops): deploy ${CI_COMMIT_SHA}"
  if git push origin "HEAD:refs/heads/$CI_DEFAULT_BRANCH"; then exit 0; fi
done
echo 'Branch changed repeatedly; retry the GitOps job' >&2
exit 1
