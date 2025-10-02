# [OpenTofu](https://opentofu.org/) Makefile

![TF](https://img.shields.io/badge/OpenTofu%20Version-%3E%3D1.8.x-yellow.svg)

<!--toc:start-->
- [About](#about)
- [Installation](#installation)
- [Usage](#usage)
  - [State Lock](#state-lock)
  - [Considerations](#considerations)
- [TODO](#todo)
<!--toc:end-->

## About

This is my [opentofu](https://opentofu.org/) workflow for every opentofu project that I use personally/professionaly when working with Google Cloud Platform.

## Installation

I usually add this project as a [git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) and then simlink the Makefile to the tofu [root module](https://opentofu.org/docs/language/modules/#the-root-module) directory:

```bash
# add submodule to the project root dir
git submodule add https://github.com/serpro69/devex-makefile.git
# cd to the root module dir, e.g. tofu:
cd tofu
# create a symlink
ln -s ../devex-makefile/tofu-gcp/Makefile Makefile
# test it out
make help
```

Using a git submodule makes it easier to pull latest changes and fixes, if you're interested in those.

You can, of course, just download the [raw version of Makefile](https://raw.githubusercontent.com/serpro69/devex-makefile/master/tofu-gcp/Makefile) and add it directly to your project.

## Usage

View a description of Makefile targets with `help` via the [self-documenting makefile](https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html).

```text
➜ make
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
This Makefile contains opinionated targets that wrap tofu commands,
providing sane defaults, initialization shortcuts for tofu environment,
and support for remote tofu backends via Google Cloud Storage.
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

<WORKSPACE>                     tofu workspace to (potentially create and) switch to
<GCP_PROJECT>                  󱇶 GCP project name (usually, but not always, the project
                               that tofu changes are being applied to)
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

<TF_OPTS>                       Additional tofu command options
                               (e.g., make apply TF_OPTS='-out=foo.out -lock=false')
<TF_ARGS>                       Additional tofu command arguments
                               (e.g., make output TF_OPTS='-raw' TF_ARGS='project_id')
<TF_CONVERGE_FROM>              Resource path to apply first
                               (before fully converging the entire configuration)
<TF_PLAN>                       tofu plan file path
                               (used with 'plan', 'apply', 'destroy' and 'show' targets)
<TF_RES_ADDR>                   Resource ADDR for tofu state/import commands
<TF_RES_ID>                     Resource ID for tofu import command
<TF_ENCRYPT_STATE>              Set to 'true' to encrypt the state file
<TF_ENCRYPT_METHOD>             Method to use for state encryption
                               (Read more about tofu state encryption:
                                 https://opentofu.org/docs/language/state/encryption/)
                               Values: (tofu|sops)
                               Default: tofu
<TF_ENCRYPTION_PASS>            Passphrase for tofu-based encryption method

<ENVFILE>                       Path to an env file with these input variables
                               (use to set some or all input variables for this makefile)
                               Default: ./.env

<NON_INTERACTIVE>               Set to 'true' to disable Makefile prompts
                               (Default: false)
                               (NB! This does not disable prompts coming from tofu)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dependencies 📦
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

gcloud                       https://cloud.google.com/sdk/docs/install
jq                           https://github.com/jqlang/jq?tab=readme-ov-file#installation
tofu                         https://opentofu.org/docs/intro/install/
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
See more in the [State Locking](https://opentofu.org/docs/language/state/locking/) docs.

### Considerations

- Each time this makefile is used, the remote state will be pulled from the GCS backend. This can result in slightly longer iteration times.
- The makefile uses `.ONESHELL`, which may not be available in all make implementations.

## TODO

- [ ] `init`
  - ask user if they want to re-initialize the config, and only proceed with `init` on positive answer
  - with this, we can safely call `init` target from other targets, i.e. `plan` or `apply` (currently this would produce too much noise from init on each plan/apply/... command)
