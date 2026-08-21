# Infrastructure as Code

These makefiles wrap an IaC tool (Terraform, OpenTofu, or Pulumi) with
opinionated targets, sane defaults, backend initialization shortcuts, and a few
guard-rails so your everyday workflow becomes:

```bash
make init      # configure backend, project, workspace/stack
make plan      # preview changes   (pulumi: make preview)
make apply     # apply changes     (pulumi: make up)
```

## Which one should I use?

| Makefile | Tool | State backend | Workspaces / stacks | State encryption |
| --- | --- | --- | --- | --- |
| [`terraform-gcp`](terraform-gcp.md) | Terraform | GCS bucket | Terraform workspaces | optional, via [SOPS](https://github.com/getsops/sops) |
| [`tofu-gcp`](tofu-gcp.md) | OpenTofu | GCS bucket | OpenTofu workspaces | optional, native OpenTofu or SOPS |
| [`tofu`](tofu.md) | OpenTofu | local files | OpenTofu workspaces | on by default, via SOPS |
| [`pulumi-gcp`](pulumi-gcp.md) | Pulumi | GCS bucket or local | Pulumi stacks | Pulumi-managed |

- Working on **GCP with Terraform**? → [`terraform-gcp`](terraform-gcp.md)
- Prefer **OpenTofu** and a **remote GCS backend**? → [`tofu-gcp`](tofu-gcp.md)
- Want OpenTofu with **local, SOPS-encrypted state** (no cloud backend)? → [`tofu`](tofu.md)
- Using **Pulumi**? → [`pulumi-gcp`](pulumi-gcp.md)

The three Terraform/OpenTofu makefiles share the same engine
([`base/tf.mk`](https://github.com/serpro69/devex-makefile/blob/master/base/tf.mk)),
so they expose the **same targets and input variables**. Read the
[Common concepts](concepts.md) page once, then jump to the page for your specific
makefile for the differences that matter.

Pulumi is different enough (stacks instead of workspaces, per-stack YAML config
instead of `.tfvars`) that it has its own [dedicated page](pulumi-gcp.md).

## Shared design principles

- **Self-documenting.** `make help` prints every target, the input variables,
  and the required tools. This site documents the *why* and the *how* — it does
  not repeat the full `help` output.
- **`make init` first.** Every workflow starts with `make init`, which wires up
  the backend, GCP project, and workspace/stack. Other targets assume this has
  run.
- **Guard-rails.** Prompts before destructive or unusual actions (using the
  `default` workspace, switching GCP projects, destroying infra). Set
  `NON_INTERACTIVE=true` to skip the makefile's own prompts in CI.
- **Sensitive input?** Prefix the command with a space to keep it out of your
  shell history:
  ```bash
   GCP_PROJECT=demo WORKSPACE=demo make init
  ```
