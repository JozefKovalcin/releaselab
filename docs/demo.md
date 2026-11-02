# Release and rollback demonstration

These scenarios require a configured GitLab project, an online runner, initialized Vault and a healthy Argo CD application. Full validation of this flow is pending.

## Deploy a new version

1. Update the version in `app/package.json` and run `npm install --package-lock-only` from `app/`.
2. Commit and push the change to the default branch. Record the source commit SHA.
3. Confirm that all five GitLab stages pass and review the JUnit report.
4. Verify the image tag in the registry and the separate commit updating the development overlay.
5. Wait for Argo CD to report `Synced` and `Healthy`.
6. Restart the port-forward if the previous pod was replaced, then check the deployed version.

```bash
kubectl --context kind-releaselab -n releaselab rollout status deployment/releaselab --timeout=180s
kubectl --context kind-releaselab -n releaselab port-forward service/releaselab 3000:80
```

In another terminal, replace `SOURCE_SHA` with the full application commit SHA:

```bash
bash scripts/smoke-test.sh http://127.0.0.1:3000 SOURCE_SHA
curl http://127.0.0.1:3000/version
```

The application reports the source SHA used to build the image, which differs from the subsequent GitOps commit SHA.

## Block a release with a failing test

On a demonstration branch, change the expected release count in `app/test/releases.test.ts` from `2` to `999` and push the change. The test job must fail and image packaging must remain blocked.

To exercise the publication gate, repeat on the default branch of a dedicated demo project. Registry publication and GitOps updates must remain blocked, with the deployed version unchanged. Revert the failing change afterwards.

## Verify Vault access restrictions

The Vault test reads the allowed secret and requires HTTP `403` when reading `secret/data/releaselab/forbidden`. The initialization script creates that forbidden fixture so the check tests authorization against an existing path.

For a local token-mode run, build the application and initialize Vault first:

```bash
bash scripts/init-vault.sh token
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_AUTH_MODE=token
export VAULT_TOKEN="$(cat .local/ci-vault-token)"
node scripts/vault-test.mjs
unset VAULT_TOKEN
```

Use the GitLab pipeline to validate the JWT variant. Do not use a Vault root token for the denied-path test.

## Roll back through Git

Wait for pending publish/update jobs to finish or cancel them before starting a manual rollback. Choose a previously verified image whose full SHA tag still exists in the registry.

Replace the image path and `PREVIOUS_SHA` below with your project values:

```bash
git switch main
git pull --ff-only
bash scripts/bump-image.sh registry.gitlab.com/YOUR_NAMESPACE/releaselab PREVIOUS_SHA
git diff -- deploy/overlays/dev/kustomization.yaml
git add deploy/overlays/dev/kustomization.yaml
git commit -m 'chore(gitops): roll back development image'
git push origin main
```

Argo CD applies the older image from the new Git commit. After the rollout, verify the previous SHA with the smoke test. Application data resets because storage is in memory.

## Verify self-healing

```bash
kubectl --context kind-releaselab -n releaselab scale deployment/releaselab --replicas=2
kubectl --context kind-releaselab -n releaselab get deployment releaselab -w
```

Argo CD should restore the single replica declared in Git. This checks reconciliation only; multiple replicas do not share the in-memory release store.
