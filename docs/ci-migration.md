# CI migration and design

ReleaseLab includes a reference GitHub Actions workflow and a GitLab pipeline for the same application. GitHub Actions builds, tests and packages the API. GitLab extends that flow with Vault authentication, registry publishing and GitOps updates.

## Workflow mapping

| GitHub Actions | GitLab CI |
| --- | --- |
| `jobs` and `needs` | Jobs, `stages` and `needs` |
| Upload/download artifacts | `artifacts` and `needs:artifacts` |
| GitHub Secrets | CI/CD variables and Vault |
| Trigger paths and job conditions | `workflow:rules` and job `rules` |
| `runs-on` | Runner tags and container images |
| Uploaded test results | JUnit report artifacts |

## Build artifacts

The build job runs `npm ci` and compiles TypeScript. The test job downloads `app/dist/`, installs its own dependencies and tests the compiled HTTP server. Test sources compile separately into `.test-dist/`.

The Dockerfile packages the verified `dist/` artifact without compiling it again. Production dependencies are installed from the committed lockfile. The image is tagged with the full source commit SHA.

`build_image` exports the image with `docker save`. The separate `push` job downloads `image.tar` and imports it with `docker load` before authenticating to the registry. Jobs do not depend on a shared local image cache.

Build artifacts expire after one day; test reports expire after one week. The GitLab instance must allow artifacts large enough for the image archive.

## Pipeline rules

Application, script, Dockerfile and GitLab pipeline changes trigger validation. An open merge request suppresses the duplicate branch push pipeline. Merge request jobs build and test without publishing.

Only default-branch push pipelines publish images and update the GitOps overlay. Changes limited to deployment manifests or documentation do not start another application pipeline. GitLab may evaluate `changes` more broadly on new branches or manually started pipelines; publication still requires a default-branch push.

## GitOps updates

The update job uses a `resource_group` to serialize changes. Before editing the overlay, it fetches the current default branch and checks for newer commits affecting build inputs. It also verifies that the source commit remains an ancestor of the branch tip.

The script retries a rejected push up to three times, checking freshness after each fetch. It never force-pushes. Credentials are supplied through an environment-backed temporary Git askpass script.

A failed test prevents image packaging and publication. A newer application revision also prevents an older pipeline from replacing the desired version.

## Vault authentication

Token mode reads a masked CI/CD variable containing a scoped Vault token. JWT mode exchanges a GitLab ID token for a Vault token with a maximum lifetime of five minutes. Vault validates the issuer, audience, signature and project claims.

The policy permits reading only `secret/data/releaselab/ci` and revoking the caller's token. The test job checks that an existing sibling secret returns HTTP `403`, then passes the API key to the test process through its environment. Secret values are not written to image layers or report artifacts.

The GitHub reference workflow uses an ephemeral test key and does not require access to the local Vault instance.

## References

- [GitLab CI configuration](https://docs.gitlab.com/ci/yaml/)
- [GitLab Docker executor](https://docs.gitlab.com/runner/executors/docker/)
- [GitLab ID tokens](https://docs.gitlab.com/ci/secrets/id_token_authentication/)
- [Vault JWT authentication](https://developer.hashicorp.com/vault/docs/auth/jwt)
- [Argo CD automated synchronization](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
