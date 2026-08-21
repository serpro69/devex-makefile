# Installation

Each makefile is self-contained (the IaC makefiles pull in shared logic from the
[`base/`](https://github.com/serpro69/devex-makefile/tree/master/base) directory).
There are two ways to use one in your project.

## Option 1 — git submodule + symlink (recommended)

Adding the repo as a [git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
and symlinking the makefile you want keeps it easy to pull in later fixes and
improvements.

```bash
# from your project root, add the submodule
git submodule add https://github.com/serpro69/devex-makefile.git

# symlink the makefile you want into place, e.g. terraform-gcp:
ln -s devex-makefile/terraform-gcp/Makefile Makefile

# try it out
make help
```

!!! note "Keep the `base/` directory reachable"
    The IaC makefiles `include` files from `devex-makefile/base/` using a path
    **relative to the real makefile location**. As long as you symlink the
    makefile out of a cloned/submoduled copy of this repo (so `../base/` still
    resolves), includes work automatically. Copying a single `Makefile` out on
    its own will break those includes — see Option 2.

To pull the latest changes later:

```bash
git submodule update --remote devex-makefile
```

## Option 2 — download the raw file

You can also grab the raw makefile and drop it into your project:

```bash
curl -o Makefile \
  https://raw.githubusercontent.com/serpro69/devex-makefile/master/terraform-gcp/Makefile
```

!!! warning "You also need `base/`"
    The IaC makefiles are thin wrappers that `include ../base/tf.mk`. If you take
    this route, download the matching `base/*.mk` files too and preserve the
    relative directory layout (`base/` next to the directory holding your
    `Makefile`), or the include will fail.

## Requirements

Every makefile checks for its required tools on startup and prints an install
link if something is missing. The exact list depends on the makefile — see each
makefile's page for details. Common dependencies across the IaC makefiles:

- [`jq`](https://github.com/jqlang/jq) — JSON processing
- the underlying tool: [`terraform`](https://www.terraform.io/downloads.html),
  [`tofu`](https://opentofu.org/docs/intro/install/), or
  [`pulumi`](https://www.pulumi.com/docs/install/)
- [`gcloud`](https://cloud.google.com/sdk/docs/install) — for the GCP-backed makefiles

!!! tip "Nerd Font (optional)"
    The help output and some prompts use [Nerd Font](https://www.nerdfonts.com/)
    glyphs. Everything works without one — the glyphs just render as tofu boxes.
