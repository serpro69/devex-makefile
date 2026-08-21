# tofu-gcp

[![TF](https://img.shields.io/badge/OpenTofu-%3E%3D1.8.x-yellow.svg)](https://opentofu.org/)

An opinionated [OpenTofu](https://opentofu.org/) workflow for projects that store
their state in a **Google Cloud Storage** bucket.

This is the OpenTofu twin of [`terraform-gcp`](terraform-gcp.md): same targets,
same GCS-backed `init` flow, same [shared variables](concepts.md). The two
differences that matter are the **binary** (`tofu` instead of `terraform`) and
the **default state encryption method** (native OpenTofu encryption).

## Dependencies

Checked on startup (except for `make help`):

| Tool | Link |
| --- | --- |
| `gcloud` | <https://cloud.google.com/sdk/docs/install> |
| `jq` | <https://github.com/jqlang/jq> |
| `tofu` | <https://opentofu.org/docs/intro/install/> |
| `tflint` | <https://github.com/terraform-linters/tflint> |
| `trivy` | <https://github.com/aquasecurity/trivy> |

Optional: a [Nerd Font](https://www.nerdfonts.com/) for the help/output glyphs.

## Quick start

```bash
GCP_PROJECT=my-project WORKSPACE=demo make init
make plan
make apply
```

## GCP input variables (used by `init`)

Same as [`terraform-gcp`](terraform-gcp.md#gcp-input-variables-used-by-init):

| Variable | Default | Purpose |
| --- | --- | --- |
| `GCP_PROJECT` | `gcloud config get project` | GCP project to work against. |
| `GCP_PREFIX` | – | Prefix used to derive `QUOTA_PROJECT`. |
| `GCP_POSTFIX` | – | Postfix used to derive `QUOTA_PROJECT`. |
| `QUOTA_PROJECT` | `<GCP_PREFIX>-tfstate-<GCP_POSTFIX>` | Project hosting the state bucket / ADC quota project. |
| `GCLOUD_LAUNCH_BROWSER` | `false` | Allow `gcloud auth login` to open a browser. |

The `make init` flow (GCP config → project → ADC → GCS backend → workspace) is
identical to [terraform-gcp's](terraform-gcp.md#what-make-init-does), including
the [state-bucket-subdirectory selection](terraform-gcp.md#state-bucket-subdirectory).

## State encryption

Unlike the Terraform makefile, `tofu-gcp` defaults to **native OpenTofu
encryption**:

| Variable | Default | Notes |
| --- | --- | --- |
| `TF_ENCRYPT_STATE` | `false` | Set `true` to encrypt state. |
| `TF_ENCRYPT_METHOD` | `tofu` | `tofu` (native) or `sops`. |
| `TF_ENCRYPTION_PASSPHRASE` | – | Passphrase for native encryption; prompted if unset (fails in `NON_INTERACTIVE` mode). |

Native encryption uses a PBKDF2 key provider — read more in the
[OpenTofu docs](https://opentofu.org/docs/language/state/encryption/). See also
the shared [State encryption](concepts.md#state-encryption) section.

```bash
# apply with native OpenTofu state encryption
make apply TF_ENCRYPT_STATE=true TF_ENCRYPTION_PASSPHRASE='super-secret'
```

## Examples

```bash
# plan/apply a saved plan file for a workspace
WORKSPACE=staging make plan TF_PLAN=staging.tfplan
WORKSPACE=staging make apply TF_PLAN=staging.tfplan

# single raw output value
make output TF_OPTS='-raw' TF_ARGS='project_id'

# import an existing resource
make import TF_RES_ADDR='google_storage_bucket.this' TF_RES_ID='my-bucket'

# converge one resource first
make apply TF_CONVERGE_FROM='google_project_service.compute'
```

## See also

- [Common concepts](concepts.md) — targets, variables, config files, testing.
- [`terraform-gcp`](terraform-gcp.md) — the Terraform equivalent.
- [`tofu`](tofu.md) — OpenTofu with a local, SOPS-encrypted backend.
