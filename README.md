**devex-makefile**

[![pulumi-gcp](https://img.shields.io/badge/pulumi-gcp-orange?logo=pulumi&style=for-the-badge&logoSize=auto)](./pulumi-gcp)
[![terraform-gcp](https://img.shields.io/badge/terraform-gcp-purple?logo=terraform&style=for-the-badge&logoSize=auto)](./terraform-gcp)
[![tofu-gcp](https://img.shields.io/badge/tofu-gcp-yellow?logo=opentofu&style=for-the-badge&logoSize=auto)](./tofu-gcp)

[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=for-the-badge&logoSize=auto)](LICENSE)

A collection of Makefile recipes for... all sorts of dev things that I use personally or profesionally with the aim to improve development experience when working with various dev ecosystems and tools. 🚀

> Wait... but why? 🤨

Well... because make commands are short and easy to remember. They can be autocompleted. And you can document them easily taking the approach of [self-documenting makefiles](https://www.cmcrossroads.com/print/article/self-documenting-makefiles).
So I usually prefer running `make test`, `make apply`, `make whatnot` over `./gradlew clean test ...`, or `terraform apply ...`, or `docker-compose up ...` etc. 😏

Also, because... why not? 🤓

## Installation

I usually add this project as a [git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules), and then create a symlink to the necessary makefile, for example:

```bash
# add submodule 
git submodule add https://github.com/serpro69/devex-makefile.git
# create a symlink
ln -s devex-makefile/terraform-gcp/Makefile Makefile
# test it out
make help
```

Using a git submodule makes it easier to pull latest changes and fixes, if you're interested in those.

You can, of course, just download the [raw version of Makefile](https://raw.githubusercontent.com/serpro69/devex-makefile/master/terraform-gcp/Makefile) and add it directly to your project. The choice, as they say, is yours.

## Usage

Each directory should usually contain a readme with usage details for a given makefile. If not - do try to run `make help`.

## Contents

- [`terraform-gcp`](./terraform-gcp) - recipes that make life a little easier when working with Terraform and Google Cloud Platform

## License

This code is licensed under the [MIT License](LICENSE).

(C) [Serhii Prodanov](https://github.com/serpro69)

## Contribute

So, you've made it this far 🤓 Congrats! 🎉
I've made these makefile to simplify my own workflows, but I'm happy if you've found any of this code useful as well.
If you want to contribute anything: fixes, new commands to existing makefiles (or new makefiles altogether), customizable configuration, documentation; like, literally, anything - you should definitely do so.

Steps:

- Open a new issue (Totally optional. I'll accept PR's w/o having an open issue, so long as it's clear what the change is all about.)
- Fork this repository 🍴
- Install dependencies (I guess you already have `make` installed? 🤨)
- Bang your head against the keyboard from frustration 😡😤🤬 (Who said coding was easy?)
- Open a pull request once you're finished 😮‍💨
- Profit 🤑
