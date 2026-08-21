# terraform-gcp

[![TF](https://img.shields.io/badge/Terraform-%3E%3D1.0.0-purple.svg)](https://www.terraform.io/)

An opinionated [Terraform](https://www.terraform.io/) workflow for projects that
store their state in a **Google Cloud Storage** bucket.

It wraps `terraform` with sane defaults, sets up the GCS backend and your GCP
context during `make init`, and exposes the shared targets and variables
described in [Common concepts](concepts.md). This page covers what's specific to
`terraform-gcp`.

## Dependencies

Checked on startup (except for `make help`):

| Tool | Link |
| --- | --- |
| `gcloud` | <https://cloud.google.com/sdk/docs/install> |
| `jq` | <https://github.com/jqlang/jq> |
| `terraform` | <https://www.terraform.io/downloads.html> |
| `tflint` | <https://github.com/terraform-linters/tflint> |
| `trivy` | <https://github.com/aquasecurity/trivy> |

Optional: a [Nerd Font](https://www.nerdfonts.com/) for the help/output glyphs.

## Quick start

```bash
# first-time setup for a workspace (configures GCP + GCS backend + workspace)
GCP_PROJECT=my-project WORKSPACE=demo make init

# everyday loop
make plan
make apply
```

!!! tip
    Prefix a command with a space (`  GCP_PROJECT=… make init`) to keep it out of
    your shell history.

## GCP input variables (used by `init`)

In addition to the [shared variables](concepts.md#input-variables):

| Variable | Default | Purpose |
| --- | --- | --- |
| `GCP_PROJECT` | `gcloud config get project` | GCP project to work against. `init` offers to switch `gcloud` to it. |
| `GCP_PREFIX` | – | Prefix used to derive `QUOTA_PROJECT` (e.g. a short company name). |
| `GCP_POSTFIX` | – | Postfix used to derive `QUOTA_PROJECT` (e.g. an id hash). |
| `QUOTA_PROJECT` | `<GCP_PREFIX>-tfstate-<GCP_POSTFIX>` | Project that hosts the state bucket; also set as the ADC quota project. |
| `GCLOUD_LAUNCH_BROWSER` | `false` | `true` lets `gcloud auth login` open a browser; otherwise `--no-launch-browser` is used. |

## What `make init` does

1. **GCP configuration** — checks the active `gcloud` configuration and offers to
   switch to the default one if they differ.
2. **GCP project** — compares the requested `GCP_PROJECT` with the active one and
   offers to `gcloud config set project` + re-login / update ADC.
3. **ADC quota project** — offers to point Application Default Credentials at
   `QUOTA_PROJECT` (the project that holds the state bucket).
4. **GCS backend** — discovers a bucket named `*tfstate*` in `QUOTA_PROJECT`,
   picks a subdirectory under `terraform/state/…`, and runs `terraform init`
   against it.
5. **Workspace** — creates and/or selects `WORKSPACE`.

### State bucket subdirectory

The state path is `terraform/state/<subdir>`, where `<subdir>` is chosen by this
priority:

1. `__BUCKET_SUBDIR` (explicit override), else
2. `__ENVIRONMENT` (derived from the current backend prefix), else
3. an interactive prompt asking whether to use the **production** subdir (`prod`),
   else
4. defaults to `test`.

The `prod` path is highlighted in red as a reminder that you're touching
production state.

## State encryption

`TF_ENCRYPT_STATE` defaults to `false`. Set it to `true` (with
`TF_ENCRYPT_METHOD=sops`, the default and only supported method here) to encrypt
state via [SOPS](https://github.com/getsops/sops). See
[State encryption](concepts.md#state-encryption).

## Examples

```bash
# plan against a specific workspace, writing a plan file
WORKSPACE=staging make plan TF_PLAN=staging.tfplan
# apply that saved plan
WORKSPACE=staging make apply TF_PLAN=staging.tfplan

# read a single output value
make output TF_OPTS='-raw' TF_ARGS='project_id'

# import an existing resource
make import TF_RES_ADDR='google_storage_bucket.this' TF_RES_ID='my-bucket'

# apply one resource first, then converge everything
make apply TF_CONVERGE_FROM='google_project_service.compute'

# non-interactive apply for CI (no makefile prompts, no colors)
make apply NON_INTERACTIVE=true NO_TERM=true
```

## See also

- [Common concepts](concepts.md) — targets, variables, config files, testing.
- [`tofu-gcp`](tofu-gcp.md) — the OpenTofu equivalent.
