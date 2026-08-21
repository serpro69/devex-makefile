# tofu-gcp

An opinionated [OpenTofu](https://opentofu.org/) workflow with a **Google Cloud Storage** state backend. The OpenTofu twin of [`terraform-gcp`](../terraform-gcp), with native OpenTofu state encryption by
default.

**Full documentation:** <https://serpro69.github.io/devex-makefile/iac/tofu-gcp/>

## Quick start

```bash
# from your project root
git submodule add https://github.com/serpro69/devex-makefile.git
ln -s devex-makefile/tofu-gcp/Makefile Makefile

# configure GCP + GCS backend + workspace, then plan/apply
GCP_PROJECT=my-project WORKSPACE=demo make init
make plan
make apply

# discover everything the makefile can do
make help
```

See the [installation guide](https://serpro69.github.io/devex-makefile/installation/) and [common concepts](https://serpro69.github.io/devex-makefile/iac/concepts/) for targets, input variables, config files, state encryption, and testing.
