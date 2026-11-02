# Environment setup

The deployment environment targets GitLab.com, a local Docker runner, Vault in Docker and a kind cluster. On Windows, run the infrastructure commands from WSL2 with Docker Desktop integration enabled.

## Requirements

- Node.js 24 and npm
- Bash, Git, curl, jq and openssl
- Docker with Compose v2
- kubectl, kind and standalone Kustomize
- A GitLab project with Container Registry enabled

Keep the working copy in the Linux filesystem when using WSL2. Allow approximately 4 CPUs and 6–8 GB of memory for the lab.

## GitLab project

Create an empty GitLab project with `main` as its default branch. Push this repository to it, or use a separate remote if GitHub remains the portfolio host.

Before running the pipeline:

1. Set `repoURL` in `argocd/application.yaml` to the GitLab repository URL.
2. Set `targetRevision` if the default branch is not `main`.
3. Set `newName` in `deploy/overlays/dev/kustomization.yaml` to the exact registry image path.

The initial `bootstrap` image tag is a placeholder. Apply the Argo CD application only after the first image has been published and the pipeline has updated the tag.

## Runner and Vault

```bash
bash scripts/setup-local.sh
```

This generates a local `.env` file with a random dev root token and starts the runner and Vault. The runner template attaches job containers to `releaselab-ci`, where Vault is available at `http://vault:8200`. The host uses `http://127.0.0.1:8200`.

Create a project runner in GitLab with the tag `releaselab`, disable untagged jobs and lock it to the project. Use its `glrt-` authentication token:

```bash
read -rsp 'Runner authentication token: ' RUNNER_AUTH_TOKEN; echo
export RUNNER_AUTH_TOKEN
bash scripts/register-runner.sh
unset RUNNER_AUTH_TOKEN
```

Register once; repeated registration creates additional runner entries. Protected runner settings must match the branches being tested.

The Docker executor mounts the host Docker socket. Run only trusted project code on this runner; it is not suitable for untrusted fork pipelines. Vault dev mode uses HTTP and loses its data on restart.

## Vault authentication

### Scoped token

```bash
bash scripts/init-vault.sh token
```

Add the contents of `.local/ci-vault-token` to GitLab as masked, hidden `VAULT_TOKEN`, and set `VAULT_AUTH_MODE=token`. The token expires after 24 hours. Reissue it after expiry or a Vault restart. Protected variables are available only on protected refs.

### GitLab ID token

Set `GITLAB_PROJECT_ID` to the numeric project ID shown in GitLab:

```bash
export GITLAB_PROJECT_ID=12345678
bash scripts/init-vault.sh jwt
```

Remove the `VAULT_TOKEN` variable and set `VAULT_AUTH_MODE=jwt`, which is the pipeline default. The role binds `project_id`, `job_project_id` and branch refs. It requires GitLab-issued `job_project_id` claims and allows the project's trusted branch jobs to read the test fixture.

The audience is `https://releaselab.local/vault`. If changed, use the same `VAULT_AUDIENCE` during initialization and in CI. Vault must reach GitLab.com over HTTPS to retrieve discovery metadata and signing keys.

Initialization preserves the existing test key and reapplies the policy and fixtures. Run it again after restarting dev Vault. Root credentials stay local and must not be added to CI. Do not enable `CI_DEBUG_TRACE` or shell tracing for secret-handling jobs.

## GitOps write access

Create a GitLab project access token with `write_repository` and permission to push to the protected default branch. If project access tokens are unavailable, use a dedicated bot account's personal access token.

Store it as masked, hidden, protected `GITOPS_PUSH_TOKEN`. Protect `main` and allow the bot identity to push. Registry publication uses GitLab's predefined `CI_REGISTRY_USER` and `CI_REGISTRY_PASSWORD`.

## Cluster and Argo CD

```bash
bash scripts/bootstrap-cluster.sh
```

The script targets the `kind-releaselab` context and installs Argo CD `v3.2.0`. Override the version with `ARGOCD_VERSION` when updating the lab baseline.

Create a GitLab deploy token with `read_repository` and `read_registry`. Set the repository URL and deploy-token username to your project values:

```bash
export GITLAB_REPO_URL=https://gitlab.com/YOUR_NAMESPACE/releaselab.git
export GITLAB_DEPLOY_USER=YOUR_DEPLOY_TOKEN_USERNAME
read -rsp 'GitLab deploy token: ' GITLAB_DEPLOY_TOKEN; echo
export GITLAB_DEPLOY_TOKEN
bash scripts/configure-cluster-secrets.sh
unset GITLAB_DEPLOY_TOKEN
```

The script creates the registry pull secret, Argo CD repository credentials and an independent runtime API key. Runtime credentials are separate from the Vault CI fixture and are preserved on repeat runs.

After the first successful pipeline, pull the updated overlay and create the application:

```bash
git pull --ff-only
kubectl --context kind-releaselab apply -f argocd/application.yaml
kubectl --context kind-releaselab -n argocd get application releaselab -w
```

Argo CD polls Git, so synchronization can take a few minutes. To open its UI:

```bash
kubectl --context kind-releaselab -n argocd port-forward service/argocd-server 8080:443
```

Use `https://localhost:8080` and retrieve the initial administrator password locally from `argocd-initial-admin-secret`.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Job remains pending | Runner online status, tag, protected refs and variable availability |
| Vault authentication fails | Project ID, audience, issuer, token expiry and discovery connectivity |
| `ImagePullBackOff` | Image path, published tag and deploy-token `read_registry` scope |
| Argo CD repository access fails | Repository URL and `read_repository` credentials |
| API pod cannot start | `releaselab-api` secret and `api_key` entry |

## Cleanup

Stop active port-forward processes, then remove the lab cluster and stop the Docker services:

```bash
kind delete cluster --name releaselab
docker compose --env-file .env -f infra/compose.yaml down
```

Vault dev data is lost. Runner registration remains in the Docker volume. Local credentials in `.env` and `.local/` are ignored by Git.
