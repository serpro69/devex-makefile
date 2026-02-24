# [Terraform](https://www.terraform.io/) Makefile

![TF](https://img.shields.io/badge/Terraform%20Version-%3E%3D1.0.0-purple.svg)

<!--toc:start-->

- [About](#about)
- [Installation](#installation)
- [Usage](#usage)
  - [State Lock](#state-lock)
  - [Considerations](#considerations)
- [Ack](#ack)
- [TODO](#todo)
<!--toc:end-->

## About

This is my [terraform](https://www.terraform.io/) workflow for every terraform project that I use personally/professionaly when working with Google Cloud Platform.

## Installation

I usually add this project as a [git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to the terraform [root module](https://developer.hashicorp.com/terraform/language/modules#the-root-module) directory, and then create a symlink to the makefile, for example:

```bash
# add submodule
git submodule add https://github.com/serpro69/terraform-makefile.git
# create a symlink
ln -s terraform-makefile/Makefile Makefile
# test it out
make help
```

Using a git submodule makes it easier to pull latest changes and fixes, if you're interested in those.

You can, of course, just download the [raw version of Makefile](https://raw.githubusercontent.com/serpro69/terraform-makefile/master/Makefile) and add it directly to your project.

## Usage

View a description of Makefile targets with `help` via the [self-documenting makefile](https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html).

```text
➜ make
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
This Makefile contains opinionated targets that wrap terraform commands,
providing sane defaults, initialization shortcuts for terraform environment,
and support for remote terraform backends via Google Cloud Storage.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Usage:
> GCP_PROJECT=demo WORKSPACE=demo make init
> make plan

Tip: Add a <space> before the command if it contains sensitive information,
to keep it from bash history!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Available commands ⌨️
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

apply                         Set course and full speed ahead! ⛵ This will cost you! 💰
clean                         Nuke local .terraform directory and tools' caches! 💥
destroy                       Release the Kraken! 🐙 This can't be undone! ☠️
format                        Swab the deck and tidy up! 🧹
help                          Save our souls! 🛟
import                        Import state 📦
init                          Hoist the sails and prepare for the voyage! 🌬️💨
output                        Explore the outcomes of the trip! 💰
plan                          Chart the course before you sail! 🗺️
show                          Show the current state of the world! 🌍
state                         Make the world dance to your tunes! 🎻
test                          Run some drills before we plunder! ⚔️  🏹
validate                      Inspect the rigging and report any issues! 🔍

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input variables for 'init' 🧮
(Note: these are only used with 'init' target!)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<WORKSPACE>                    󱁢 terraform workspace to (potentially create and) switch to
<GCP_PROJECT>                  󱇶 GCP project name (usually, but not always, the project
                               that terraform changes are being applied to)
                               Default: `gcloud config get project`
<GCP_PREFIX>                   󰾺 Prefix to use for QUOTA_PROJECT
                               (e.g., short company name)
<GCP_POSTFIX>                  󰾺 Postfix to use for QUOTA_PROJECT
                               (e.g., id hash string)
<QUOTA_PROJECT>                 Override GCP quota project id
                               (NB! we assume quota project contains the .tfstate bucket)
                               Default: <GCP_PREFIX>-tfstate-<GCP_POSTFIX>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input variables 🧮
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<TF_OPTS>                      󱁢 Additional terraform command options
                               (e.g., make apply TF_OPTS='-out=foo.out -lock=false')
<TF_ARGS>                      󱁢 Additional terraform command arguments
                               (e.g., make output TF_OPTS='-raw' TF_ARGS='project_id')
<TF_CONVERGE_FROM>             󱁢 Resource path to apply first
                               (before fully converging the entire configuration)
<TF_PLAN>                      󱁢 terraform plan file path
                               (used with 'plan', 'apply', 'destroy' and 'show' targets)
<TF_RES_ADDR>                  󱁢 Resource ADDR for terraform state/import commands
<TF_RES_ID>                    󱁢 Resource ID for terraform import command
<TF_ENCRYPT_STATE>             󱁢 Set to 'true' to encrypt the state file
<TF_ENCRYPT_METHOD>            󱁢 Method to use for state encryption
                               Values: (sops)
                               Default: sops

<CONFFILE>                      Path to an conf file with these input variables
                               (use to set some or all input variables for this makefile)
                               (if exists, takes precedence over ENVFILE)
                               Default: ./.conf
<ENVFILE>                       Path to an env file with these input variables
                               (use to set some or all input variables for this makefile)
                               Default: ./.env

<NON_INTERACTIVE>               Set to 'true' to disable Makefile prompts
                               (Default: false)
                               (NB! This does not disable prompts coming from terraform)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dependencies 📦
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

gcloud                       https://cloud.google.com/sdk/docs/install
jq                           https://github.com/jqlang/jq?tab=readme-ov-file#installation
terraform                    https://www.terraform.io/downloads.html
tflint                       https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation
trivy                        https://github.com/aquasecurity/trivy?tab=readme-ov-file#get-trivy

Optional:

nerd font                    https://www.nerdfonts.com/
(for outputs and this help)
```

> [!NOTE]
> Before each target, several private Makefile functions run to configure the remote state backend: `_set-env`, `_check-ws`, ...
> You should never have to run these yourself.

### State Lock

The GCS backend implements it's own locking mechanism by creating a `.lock` file in the same bucket for each workspace.
See more in the [State Locking](https://developer.hashicorp.com/terraform/language/state/locking) docs.

### Considerations

- Each time this makefile is used, the remote state will be pulled from the GCS backend. This can result in slightly longer iteration times.
- The makefile uses `.ONESHELL`, which may not be available in all make implementations.

## Ack

This makefile was inspired by:

- [pgporada/terraform-makefile](https://github.com/pgporada/terraform-makefile)

## TODO

- [ ] `init`
  - ask user if they want to re-initialize the config, and only proceed with `init` on positive answer
  - with this, we can safely call `init` target from other targets, i.e. `plan` or `apply` (currently this would produce too much noise from init on each plan/apply/... command)
