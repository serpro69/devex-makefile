# tofu

[![TF](https://img.shields.io/badge/OpenTofu-%3E%3D1.8.x-yellow.svg)](https://opentofu.org/)

An opinionated [OpenTofu](https://opentofu.org/) workflow for projects that keep
their state **locally** — not tied to any cloud backend — with the state files
**encrypted at rest using [SOPS](https://github.com/getsops/sops)**.

It shares the same targets and variables as its GCS-backed siblings (see
[Common concepts](concepts.md)); this page covers the local-backend specifics.

## Dependencies

Checked on startup (except for `make help`):

| Tool | Link |
| --- | --- |
| `jq` | <https://github.com/jqlang/jq> |
| `tofu` | <https://opentofu.org/docs/intro/install/> |
| `tflint` | <https://github.com/terraform-linters/tflint> |
| `trivy` | <https://github.com/aquasecurity/trivy> |
| `sops` | <https://github.com/getsops/sops> |

!!! note "`sops` is effectively required"
    State encryption is **on by default** here (`TF_ENCRYPT_STATE=true`), and the
    makefile errors out if `sops` isn't installed. There's **no `gcloud`
    dependency** — this makefile never talks to GCP.

Optional: a [Nerd Font](https://www.nerdfonts.com/) for the help/output glyphs.

## Quick start

```bash
# initialize and select a workspace (state stays local, encrypted with SOPS)
WORKSPACE=demo make init

# everyday loop
make plan
make apply
```

## Input variables

The only `init`-specific variable is `WORKSPACE`. Everything else comes from the
[shared variables](concepts.md#input-variables). There are **no GCP variables**
and no remote backend to configure.

## What `make init` does

1. **Decrypts** the local state files (if encrypted) so OpenTofu can read them.
2. Runs `tofu init -reconfigure -upgrade …` against the local backend.
3. Creates and/or selects `WORKSPACE`.
4. Initializes `tflint` if a `.tflint.hcl` is present.
5. **Re-encrypts** the state files with SOPS.

State lives under `terraform.tfstate.d/<WORKSPACE>/terraform.tfstate` (and its
`.backup`), and is transparently decrypted before each operation and re-encrypted
afterwards.

## State encryption

| Variable | Default | Notes |
| --- | --- | --- |
| `TF_ENCRYPT_STATE` | `true` | Encrypt local state with SOPS. Set `false` to disable (then `sops` isn't required). |
| `TF_ENCRYPT_METHOD` | `sops` | SOPS is the method used for the local backend. |

Encryption/decryption is wired into every state-changing target automatically, so
your committed state files stay encrypted. See the shared
[State encryption](concepts.md#state-encryption) section for background.

## Examples

```bash
# plan/apply for a workspace
WORKSPACE=staging make plan
WORKSPACE=staging make apply

# single raw output value
make output TF_OPTS='-raw' TF_ARGS='some_output'

# import an existing resource into local state
make import TF_RES_ADDR='local_file.this' TF_RES_ID='./path/to/file'

# work without encryption (sops not needed)
make apply TF_ENCRYPT_STATE=false
```

## See also

- [Common concepts](concepts.md) — targets, variables, config files, testing.
- [`tofu-gcp`](tofu-gcp.md) — the same tool with a remote GCS backend.
