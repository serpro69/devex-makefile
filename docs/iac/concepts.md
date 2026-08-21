# Common concepts

The [`terraform-gcp`](terraform-gcp.md), [`tofu-gcp`](tofu-gcp.md), and
[`tofu`](tofu.md) makefiles share the same engine
([`base/tf.mk`](https://github.com/serpro69/devex-makefile/blob/master/base/tf.mk)),
so they expose the **same targets and input variables**. This page explains the
concepts once; each makefile's own page then covers what's specific to it.

Throughout this page, `<tool>` means `terraform` or `tofu` depending on which
makefile you're using.

## The workflow

```bash
make init      # configure backend + workspace (run this first)
make plan      # preview changes
make apply     # apply changes
```

`make init` must run before the other targets — it configures the state backend
and selects the workspace. The other targets assume that has happened.

## Targets

| Target | What it does |
| --- | --- |
| `help` | Print the self-documenting help (targets, variables, dependencies). |
| `init` | Configure the backend and (create and) select the workspace. Run this first. |
| `format` | `<tool> fmt -recursive` — rewrite files to canonical format. |
| `validate` | `fmt -check`, `<tool> validate`, `tflint`, and a `trivy` security scan. Fails on any issue. |
| `plan` | Preview changes. Honors `TF_OPTS`, `TF_ARGS`, `TF_PLAN`, `TF_CONVERGE_FROM`. |
| `apply` | Apply changes. Runs `validate` first. |
| `destroy` | Destroy managed infrastructure. Runs `validate` first. ⚠️ irreversible. |
| `show` | Show the current state (or a saved plan file, if `TF_PLAN` is set). |
| `state` | Wrap `<tool> state`. With no args, lists resources; with `TF_RES_ADDR`, shows that resource. |
| `output` | Show outputs. Combine with `TF_OPTS='-raw'` / `TF_ARGS='<name>'` for a single value. |
| `import` | Import an existing resource into state. Requires `TF_RES_ADDR` and `TF_RES_ID`. |
| `test` | Blue-green integration test in a throwaway workspace (see [Testing](#testing)). |
| `clean` | Remove the local `.terraform` directory and clear the `trivy` cache. |

`apply`, `destroy`, and `test` run `validate` and/or workspace checks as
prerequisites, so you don't have to remember to validate first.

## Input variables

Set these on the command line (`make apply TF_OPTS='-lock=false'`), via
environment variables, or in a [config file](#config-and-env-files).

### Used by every target

| Variable | Default | Purpose |
| --- | --- | --- |
| `WORKSPACE` | current workspace | Workspace to create/select. Also selects the `vars/<WORKSPACE>.tfvars` file. |
| `TF_OPTS` | – | Extra **options** appended to the command, e.g. `-lock=false -out=foo.tfplan`. |
| `TF_ARGS` | – | Extra **arguments**, e.g. an output name for `output`, or a state subcommand. |
| `TF_CONVERGE_FROM` | – | Resource address to apply **first**, before converging the rest (see [Converge-from](#converge-from)). |
| `TF_PLAN` | – | Plan file path. `plan` writes to it; `apply`/`destroy`/`show` read from it. |
| `TF_RES_ADDR` | – | Resource address for `state` and `import`. |
| `TF_RES_ID` | – | Resource ID for `import`. |
| `TF_ENCRYPT_STATE` | varies | `true` to encrypt state (see [State encryption](#state-encryption)). |
| `TF_ENCRYPT_METHOD` | varies | Encryption method — `sops` or (OpenTofu only) `tofu`. |
| `NON_INTERACTIVE` | `false` | `true` disables the makefile's own prompts. Does **not** disable prompts from the underlying tool. |
| `NO_TERM` | `false` | `true` disables colored output (useful when `$TERM` is unset, e.g. CI). |

### Used only by `init`

The GCS-backed makefiles ([`terraform-gcp`](terraform-gcp.md),
[`tofu-gcp`](tofu-gcp.md)) accept additional GCP variables — `GCP_PROJECT`,
`GCP_PREFIX`, `GCP_POSTFIX`, `QUOTA_PROJECT` — documented on their own pages. The
local [`tofu`](tofu.md) makefile only needs `WORKSPACE`.

## Workspaces and `tfvars`

The `WORKSPACE` variable does double duty: it's the tool workspace to select, and
it points at the variable-definitions file `vars/<WORKSPACE>.tfvars`, which is
passed to `plan`/`apply`/`destroy` as `-var-file`. `init` will create the
workspace if it doesn't exist yet.

```bash
# operate on the 'staging' workspace using vars/staging.tfvars
WORKSPACE=staging make init
WORKSPACE=staging make plan
```

!!! warning "The `default` workspace"
    Running against the `default` workspace is usually not what you want, so the
    makefile asks you to confirm before proceeding (unless `NON_INTERACTIVE=true`).

### Encrypted `tfvars`

Before each run the makefile prepares a `terraform.tfvars` from encrypted sources
if present (all optional):

- `terraform.tfvars.sops` — decrypted with [SOPS](https://github.com/getsops/sops).
- `vars/<WORKSPACE>.tfvars.sops` — decrypted and appended.
- Lines in `terraform.tfvars` tagged with a trailing `# <workspace>` comment are
  toggled on/off based on the active `WORKSPACE`.

Temporary decrypted files are cleaned up after the command runs.

## Config and env files

Instead of passing variables on every invocation, put them in a file:

- `.conf` (default `CONFFILE`) — takes precedence if present.
- `.env` (default `ENVFILE`) — used if no `.conf` exists.

Both are plain `make`-style `KEY=value` files that are `include`d by the makefile.
Override the paths with `CONFFILE=…` / `ENVFILE=…`.

```makefile
# .conf
WORKSPACE=staging
GCP_PROJECT=my-staging-project
TF_OPTS=-lock-timeout=60s
```

## Converge-from

`TF_CONVERGE_FROM` is a shortcut for the common "apply this one resource first,
then everything else" pattern — instead of running `apply` twice with a manual
`-target`:

```bash
# apply google_project.this first, then converge the whole config
make apply TF_CONVERGE_FROM='google_project.this'
```

With `plan`, it runs a targeted `plan` **and** `apply` for that resource first,
then plans the rest — because the full plan may depend on the targeted resource
already existing.

## State encryption

Two mechanisms are available; which is the default depends on the makefile:

- **SOPS** (`TF_ENCRYPT_METHOD=sops`) — encrypts the state file(s) with SOPS.
  Used by the local [`tofu`](tofu.md) makefile (on by default) and available for
  the Terraform makefile.
- **Native OpenTofu encryption** (`TF_ENCRYPT_METHOD=tofu`, OpenTofu only) —
  uses OpenTofu's built-in
  [state & plan encryption](https://opentofu.org/docs/language/state/encryption/)
  with a PBKDF2 passphrase. Supply the passphrase via `TF_ENCRYPTION_PASS`
  (you'll be prompted if it's unset and interactive).

See each makefile's page for its defaults.

## Testing

`make test` runs a **blue-green style integration test** so you can verify a
change actually applies cleanly on top of the current mainline:

1. Refuses to run if the working tree is dirty or you're on the default git
   branch (`main`).
2. Creates a throwaway workspace `test-<uuid>`.
3. Applies `origin/main` as a baseline, then applies your branch's changes on top.
4. Offers to destroy the test infrastructure and delete the temporary workspace
   afterwards (done automatically when `NON_INTERACTIVE=true`).

Because it applies real infrastructure, expect it to cost money and take time.

## Good to know

- **Remote state is pulled on every run** (GCS-backed makefiles), which can make
  iteration slightly slower.
- The makefiles use `.ONESHELL`, which isn't available in every `make`
  implementation — GNU Make is assumed.
- Private helper targets (prefixed `_`, e.g. `_set-env`, `_check-ws`) run
  automatically as prerequisites. You never invoke them directly.
