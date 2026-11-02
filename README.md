# ReleaseLab

**Work in Progress — this project is not complete.** The API and automation are implemented, but the full GitLab-to-Kubernetes deployment flow still requires validation.

A DevOps portfolio project built around a small NestJS REST API. ReleaseLab combines GitLab CI, Docker, Kubernetes, Argo CD, HashiCorp Vault and Bash to build, test and deploy versioned application images through GitOps.

## Architecture

```text
GitLab repository
  └─ GitLab Runner (Docker)
      ├─ build → compiled application
      ├─ test ← Vault API key
      ├─ build_image → image.tar
      ├─ push → GitLab Container Registry
      └─ update_gitops → Kustomize image tag commit
                              │
                         Argo CD sync
                              │
                     Kubernetes (kind)
                              └─ ReleaseLab API
```

The GitHub repository hosts the portfolio source and a reference GitHub Actions workflow. The deployment pipeline is designed to run from a GitLab repository with a local Docker runner. Argo CD watches `deploy/overlays/dev`; CI does not require cluster access.

## Project status

Implemented and verified locally:

- REST API with validation, API key authentication and in-memory storage.
- Unit and HTTP integration tests, including rejected unauthorized writes.
- Vault secret retrieval with a scoped token and a denied-path check.
- Kustomize rendering and GitOps script tests covering stale builds, merge commits and rollback.

Still to validate:

- GitLab runner registration and the complete GitLab pipeline.
- GitLab ID token authentication against Vault.
- Container build, artifact transfer and registry publishing.
- Argo CD synchronization, self-healing and version changes on a running cluster.

This is a local learning environment, not a production deployment. Vault runs in dev mode, the runner uses the host Docker socket, and application data is lost on restart.

## API

| Endpoint | Description | Authentication |
| --- | --- | --- |
| `GET /health` | Health check | None |
| `GET /version` | Application version and commit SHA | None |
| `GET /releases` | List releases | None |
| `POST /releases` | Create a release | `X-API-Key` |

```json
{
  "version": "1.2.3",
  "notes": "Release description"
}
```

Invalid requests return `400`; missing or incorrect API keys return `401`.

## Run locally

Requires Node.js 24, npm and Bash.

```bash
cd app
npm ci
npm run build
npm test
export RELEASELAB_API_KEY="$(openssl rand -hex 32)"
npm start
```

In another terminal:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/version
curl http://localhost:3000/releases
```

Local tests generate an ephemeral API key. CI requires an injected key. JUnit reports are written to `app/reports/junit.xml`.

## Delivery pipeline

| Stage | Output |
| --- | --- |
| `build` | Compiled TypeScript in `app/dist/` |
| `test` | Unit and HTTP tests using a key retrieved from Vault |
| `build_image` | Verified build packaged as `image.tar` |
| `push` | Image published with the full commit SHA as its tag |
| `update_gitops` | Commit updating the development overlay |

Image publication and GitOps updates run only for pushes to the default branch. Deployment-only commits do not trigger another build. GitOps updates are serialized and reject stale builds.

## Repository layout

```text
app/                      REST API and tests
.github/workflows/ci.yml   Reference GitHub Actions workflow
.gitlab-ci.yml            GitLab delivery pipeline
Dockerfile                Application image
infra/                    Runner, Vault and kind configuration
deploy/                   Kubernetes manifests and Kustomize overlay
argocd/                   Argo CD application
scripts/                  Bootstrap, testing and GitOps automation
docs/                     Setup, CI design and demonstration guide
```

## Documentation

- [Environment setup](docs/setup.md)
- [CI migration and design](docs/ci-migration.md)
- [Release and rollback demonstration](docs/demo.md)

## Configuration checks

Run from the repository root after installing application dependencies:

```bash
node scripts/validate.mjs
for file in scripts/*.sh; do bash -n "$file"; done
kustomize build deploy/overlays/dev
bash scripts/test-gitops.sh
```

The GitOps test uses isolated local repositories and does not push to GitHub or GitLab.
