# tofu

An opinionated [OpenTofu](https://opentofu.org/) workflow with a **local** state backend, with state files encrypted at rest using [SOPS](https://github.com/getsops/sops). Not tied to any cloud.

**Full documentation:** <https://serpro69.github.io/devex-makefile/iac/tofu/>

## Quick start

```bash
# from your project root
git submodule add https://github.com/serpro69/devex-makefile.git
cd tofu   # your OpenTofu root module directory
ln -s ../devex-makefile/tofu/Makefile Makefile

# initialize + select a workspace (state stays local, SOPS-encrypted)
WORKSPACE=demo make init
make plan
make apply

# discover everything the makefile can do
make help
```

See the [installation guide](https://serpro69.github.io/devex-makefile/installation/) and [common concepts](https://serpro69.github.io/devex-makefile/iac/concepts/) for targets, input variables, config files, state encryption, and testing.
