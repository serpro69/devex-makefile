**terraform-makefile**

![TF](https://img.shields.io/badge/Terraform%20Version-%3E%3D1.0.0-purple.svg)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)

<!--toc:start-->
- [About](#about)
- [Installation](#installation)
- [Usage](#usage)
  - [State Lock](#state-lock)
  - [Considerations](#considerations)
- [License](#license)
- [Contribute](#contribute)
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

apply                          Set course and full speed ahead! ⛵ This will cost you! 💰
clean                          Nuke local .terraform directory! 💥
destroy                        Release the Kraken! 🐙 This can't be undone! ☠️
format                         Swab the deck and tidy up! 🧹
help                           Save our souls! 🛟
init                           Hoist the sails and prepare for the voyage! 🌬️💨
plan-destroy                   What would happen if we blow it all to smithereens? 💣
plan                           Chart the course before you sail! 🗺️
validate                       Inspect the rigging and report any issues! 🔍

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input variables for 'init' 🧮
(Note: these are only used with 'init' target!)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<WORKSPACE>                    󱁢 Terraform workspace to (potentially create and) switch to
<GCP_PROJECT>                  󱇶 GCP project name (usually, but not always, the project
                               that terraform changes are being applied to)
<GCP_PREFIX>                   󰾺 Prefix to use in some other GCP-related variables
                               (e.g., short company name)
<QUOTA_PROJECT>                 GCP quota project name
                               (NB! we assume quota project contains the .tfstate bucket)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input variables 🧮
(Note: these are used with other targets!)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<TF_ARGS>                      󱁢 Additional terraform command arguments
                               (e.g., make apply TF_ARGS='-out=foo.out -lock=false')

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dependencies 📦
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- gcloud                       https://cloud.google.com/sdk/docs/install
- jq                           https://github.com/jqlang/jq?tab=readme-ov-file#installation
- terraform                    https://www.terraform.io/downloads.html
- tflint                       https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation
- trivy                        https://github.com/aquasecurity/trivy?tab=readme-ov-file#get-trivy

Optional:
- nerd font (for this help)    https://www.nerdfonts.com/
```

> [!NOTE]
> Before each target, several private Makefile functions run to configure the remote state backend: `_set-env`, `_check-ws`, ... 
> You should never have to run these yourself.

### State Lock

The GCS backend implements it's own locking mechanism by creating a `.lock` file in the same bucket for each workspace.
See more in the [State Locking](https://developer.hashicorp.com/terraform/language/state/locking) docs.

### Considerations

* Each time this makefile is used, the remote state will be pulled from the GCS backend. This can result in slightly longer iteration times.
* The makefile uses `.ONESHELL`, which may not be available in all make implementations.

## License

This code is licensed under the [MIT License](LICENSE).

(C) [Serhii Prodanov](https://github.com/serpro69)

## Contribute

So, you've made it this far 🤓 Congrats! 🎉
I've made this makefile to simplify my own workflow when dealing with Terraform and GCP, but I'm happy if you've found this makefile useful as well.
If you want to contribute anything: fixes, new commands, customizable configuration, documentation; like, literally, anything - you should definitely do so.

Steps:

- Open a new issue (Totally optional. I'll accept PR's w/o having an open issue, so long as it's clear what the change is all about.)
- Fork this repository 🍴
- Install dependencies (I guess you already have `make` installed? 🤨)
- Bang your head against the keyboard from frustration 😡😤🤬 (Who said coding was easy?)
- Open a pull request once you're finished 😮‍💨
- Profit 🤑

## Ack

This makefile was inspired by:

- [pgporada/terraform-makefile](https://github.com/pgporada/terraform-makefile)

## TODO

- [ ] `init`
  - ask user if they want to re-initialize the config, and only proceed with `init` on positive answer
  - with this, we can safely call `init` target from other targets, i.e. `plan` or `apply` (currently this would produce too much noise from init on each plan/apply/... command)
