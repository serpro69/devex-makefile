# pulumi-gcp

[![Pulumi](https://img.shields.io/badge/Pulumi-orange.svg?logo=pulumi)](https://www.pulumi.com/)

An opinionated [Pulumi](https://www.pulumi.com/) workflow for projects that store
their state in a **Google Cloud Storage** bucket (or locally).

Pulumi's model differs from Terraform/OpenTofu — it uses **stacks** instead of
workspaces, per-stack **YAML config** instead of `.tfvars`, and `pulumi
login`/`logout` to switch backends — so this makefile is documented standalone
rather than via the [Common concepts](concepts.md) page.

## Dependencies

Checked on startup (except for `make help`):

| Tool | Link |
| --- | --- |
| `gcloud` | <https://cloud.google.com/sdk/docs/install> |
| `jq` | <https://github.com/jqlang/jq> |
| `pulumi` | <https://www.pulumi.com/docs/install/> |

Optional: a [Nerd Font](https://www.nerdfonts.com/) for the help/output glyphs.

## Targets

| Target | What it does |
| --- | --- |
| `help` | Print the self-documenting help. |
| `init` | Configure GCP context, choose the backend (local or GCS), initialize the project, and select/create the stack. Run this first. |
| `preview` | Preview changes — `pulumi preview --refresh` (the analogue of `plan`). |
| `up` | Apply changes — `pulumi up --refresh` (the analogue of `apply`). ⚠️ costs money. |
| `destroy` | `pulumi destroy --refresh`. ⚠️ irreversible. |
| `test` | Experimental blue-green integration test (see the [caution](#test-is-experimental) below). |

!!! note "No `format` / `validate` / `clean` yet"
    Those targets exist only as commented-out stubs in the makefile and are not
    available.

## Quick start

```bash
# first-time setup (configures GCP + backend + stack)
GCP_PROJECT=my-project STACK=demo make init

# everyday loop
make preview
make up
```

## Input variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `STACK` | current stack, else `null` | Pulumi stack to select/create. Also picks the config file `Pulumi.<STACK>.yaml`. |
| `GCP_PROJECT` | `gcloud config get project` | GCP project to configure during `init`. |
| `PL_ARGS` | – | Extra arguments appended to the `pulumi` command, e.g. `--yes --expect-no-changes`. |
| `PL_CONVERGE_FROM` | – | Resource URN to apply first (via `--target … --target-dependents`) before converging the rest. |
| `NON_INTERACTIVE` | `false` | `true` disables the makefile's own prompts (not Pulumi's). |
| `NO_TERM` | `false` | `true` disables colored output. |

!!! warning "Backend project/bucket are hardcoded — edit before use"
    Unlike the Terraform/OpenTofu makefiles, the state-project and bucket values
    here are baked into the makefile as the author's own environment and are
    **not** overridable via the command line:

    ```makefile
    GCP_PREFIX=test-state-wlcm
    GCP_POSTFIX=c21b45
    QUOTA_PROJECT=$(GCP_PREFIX)-plstate-$(GCP_POSTFIX)   # -> test-state-wlcm-plstate-c21b45
    __GCS_BUCKET=plstate                                 # bucket name is matched by 'plstate'
    ```

    To use this makefile in your own project, edit these lines to match your GCP
    quota project and state bucket. (Contributions to make them overridable are
    welcome!)

There is **no `.conf` / `.env` file support** in this makefile — configure via
`make` variables and the per-stack `Pulumi.<STACK>.yaml`.

## What `make init` does

1. **GCP project** — offers to `gcloud config set project` to `GCP_PROJECT` and
   re-login / update ADC.
2. **ADC quota project** — offers to point Application Default Credentials at
   `QUOTA_PROJECT`.
3. **Backend** — reads `~/.pulumi/credentials.json` and, if no backend override is
   set, prompts you to choose:
     - **local** — `pulumi login --local` (state under `~/.pulumi/`), or
     - **GCS** — discovers a bucket matching `plstate` in `QUOTA_PROJECT`, asks
       whether to use the `prod` or `test` subdirectory, and runs
       `pulumi login gs://<bucket>/state/<subdir>`.
4. **Project** — if there's no `Pulumi.yaml`, offers to run `pulumi new`.
5. **Stack** — selects `STACK` (creating it with `pulumi stack select --create`
   if needed), or lets you pick from a list when `STACK` isn't set.

## Stacks and config

`STACK` selects both the Pulumi stack and its config file `Pulumi.<STACK>.yaml`,
which is passed to `preview`/`up`/`destroy` via `--config-file`. `init` fails
early if that file is missing.

## Examples

```bash
# preview / up a specific stack
STACK=staging make preview
STACK=staging make up

# apply non-interactively (auto-approve Pulumi too)
make up PL_ARGS='--yes' NON_INTERACTIVE=true

# converge one resource first, then the rest
make up PL_CONVERGE_FROM='urn:pulumi:...::my-resource'
```

## `test` is experimental

`make test` is an in-progress blue-green test harness. It currently still
contains **Terraform remnants** (e.g. `terraform workspace show`,
`.terraform/terraform.tfstate` checks) copied from the Terraform makefile and
**will not work as-is** for a Pulumi project. Treat it as a work in progress and
avoid relying on it until it's ported.

## See also

- [IaC overview](index.md) — how the makefiles compare.
- [`terraform-gcp`](terraform-gcp.md) / [`tofu-gcp`](tofu-gcp.md) — the
  Terraform/OpenTofu counterparts with GCS backends.
