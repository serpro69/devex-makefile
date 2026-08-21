# devex-makefile

[![terraform-gcp](https://img.shields.io/badge/terraform-gcp-purple?logo=terraform&style=for-the-badge&logoSize=auto)](https://serpro69.github.io/devex-makefile/iac/terraform-gcp/)
[![tofu-gcp](https://img.shields.io/badge/tofu-gcp-yellow?logo=opentofu&style=for-the-badge&logoSize=auto)](https://serpro69.github.io/devex-makefile/iac/tofu-gcp/)
[![pulumi-gcp](https://img.shields.io/badge/pulumi-gcp-orange?logo=pulumi&style=for-the-badge&logoSize=auto)](https://serpro69.github.io/devex-makefile/iac/pulumi-gcp/)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=for-the-badge&logoSize=auto)](https://github.com/serpro69/devex-makefile/blob/master/LICENSE)

A collection of opinionated **Makefile recipes** for all sorts of dev things —
built to improve the developer experience when working with various ecosystems
and tools. 🚀

> Wait… but why? 🤨

Because `make` commands are short and easy to remember, they autocomplete, and
they document themselves using the
[self-documenting makefile](https://www.cmcrossroads.com/print/article/self-documenting-makefiles)
approach. Running `make apply` or `make plan` is simply nicer than remembering
the full `terraform apply -var-file=… -lock=true …` incantation every time. 😏

Also, because… why not? 🤓

## Documentation

Full usage docs live at **<https://serpro69.github.io/devex-makefile/>**.

## Quick start

Every makefile wraps a real tool with sane defaults, so your day-to-day workflow
collapses down to a handful of memorable commands:

```bash
make init      # prepare the working directory / backend
make plan      # preview changes
make apply     # apply changes
make help      # see everything the makefile can do
```

The easiest way to use a makefile is to add this repo as a
[git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) and symlink
the one you want:

```bash
git submodule add https://github.com/serpro69/devex-makefile.git
ln -s devex-makefile/terraform-gcp/Makefile Makefile
make help
```

See the [Installation guide](https://serpro69.github.io/devex-makefile/installation/)
for details (including the raw-download option).

## Contents

### Infrastructure as Code

| Makefile                                                                                | Tool                                   | State backend                 | Docs                                                              |
| --------------------------------------------------------------------------------------- | -------------------------------------- | ----------------------------- | ----------------------------------------------------------------- |
| [`terraform-gcp`](https://github.com/serpro69/devex-makefile/tree/master/terraform-gcp) | [Terraform](https://www.terraform.io/) | Google Cloud Storage          | [↗](https://serpro69.github.io/devex-makefile/iac/terraform-gcp/) |
| [`tofu-gcp`](https://github.com/serpro69/devex-makefile/tree/master/tofu-gcp)           | [OpenTofu](https://opentofu.org/)      | Google Cloud Storage          | [↗](https://serpro69.github.io/devex-makefile/iac/tofu-gcp/)      |
| [`tofu`](https://github.com/serpro69/devex-makefile/tree/master/tofu)                   | [OpenTofu](https://opentofu.org/)      | Local (encrypted with SOPS)   | [↗](https://serpro69.github.io/devex-makefile/iac/tofu/)          |
| [`pulumi-gcp`](https://github.com/serpro69/devex-makefile/tree/master/pulumi-gcp)       | [Pulumi](https://www.pulumi.com/)      | Google Cloud Storage or local | [↗](https://serpro69.github.io/devex-makefile/iac/pulumi-gcp/)    |

## License

This code is licensed under the [MIT License](https://github.com/serpro69/devex-makefile/blob/master/LICENSE).

## Contribute

I made these makefiles to simplify my own workflows, but I'm happy if you find them useful too. Fixes, new commands, new makefiles, customizable configuration, documentation — literally anything is welcome.

- Open an issue (optional — PRs without an issue are fine, as long as the change is clear).
- Fork this repository 🍴
- Make your change (you already have `make` installed, right? 🤨).
- Open a pull request. 😮‍💨
- Profit. 🤑
