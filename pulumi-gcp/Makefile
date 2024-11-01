########################################################################## MIT License ##########################################################################
#                                                                                                                                                               #
# Copyright 2024- Serhii Prodanov                                                                                                                               #
#                                                                                                                                                               #
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),            #
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,            #
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:                    #
#                                                                                                                                                               #
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.                                #
#                                                                                                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,           #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, #
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.    #
#                                                                                                                                                               #
#################################################################################################################################################################

############################# Useful docs #############################
#
# Pulumi vs. Terraform - Terms & Command Equivalents
# - https://www.pulumi.com/docs/iac/concepts/vs/terraform/terminology/
#
#######################################################################

### TODO:
# - initialize stack with configuration values taken from an example/template config file
#   - init stack, then for each configuration property name run `pulumi config set $name`, 
#     potentially adding `--secret` flag for secure ones
#
# - improve non-interactive usage
#   - pick a "default" backend (local or gcs?) unless otherwise specified via __PL_BACKEND arg
#   - if a stack wasn't selected from before - error out and prompt user to use STACK arg
# 
# - support getting/setting encryption passphrase for stacks' secrets via google secret manager
#   - use stack-name as secret name
#   - assume passphrases are stored in the same project as state files

.ONESHELL:
.SHELL:=/bin/bash
.SHELLFLAGS := -ec
.PHONY: up clean destroy format help init preview preview-destroy test validate
# https://stackoverflow.com/a/63771055
__MAKE_DIR=$(dir $(realpath $(lastword $(MAKEFILE_LIST))))
# Use below for reference on how to use variables in a Makefile:
# - https://www.gnu.org/software/make/manual/html_node/Using-Variables.html
# - https://www.gnu.org/software/make/manual/html_node/Flavors.html
# - https://www.gnu.org/software/make/manual/html_node/Setting.html
# - https://www.gnu.org/software/make/manual/html_node/Shell-Function.html

### Pulumi
# workaround for when user is logged in to pulumi cloud (default behavior of pulumi)
# STACK ?= $(shell if [ -f "$${HOME}/.pulumi/credentials.json" ]; then pulumi stack --show-name | tr -d '[:space:]'; else echo "null"; fi)
STACK ?= $(shell pulumi stack --show-name 2>/dev/null || echo "null" | tr -d '[:space:]')
# Additional, space-separated, pulumi command options
PL_ARGS ?=
# Set a resource path to apply first, before fully converging the entire configuration
# This is a shortcut to avoid calling make apply twice, i.e. 'make apply PL_ARGS='--target="some_resource.name" --target-dependents' && make apply'
PL_CONVERGE_FROM ?=

### Google Cloud Platform
GCP_PROJECT ?= $(shell gcloud config get project | tr -d '[:space:]')
GCP_PREFIX=test-state-wlcm
GCP_POSTFIX=c21b45
QUOTA_PROJECT=$(GCP_PREFIX)-plstate-$(GCP_POSTFIX)

### Terminal
# Set to 'true' for non-interactive usage
NON_INTERACTIVE ?=
# Set to 'true' to disable some options like colors in environments where $TERM is not set
NO_TERM ?=

### Environment and hidden options
# test | prod
__ENVIRONMENT ?=
__GCS_BUCKET=plstate
__BUCKET_DIR=state
__PROD_BUCKET_SUBDIR=prod
__TEST_BUCKET_SUBDIR=test
# use 'local' or a fully-qualified backend url
__PL_BACKEND ?=
__PL_CONF_PATH=Pulumi.$(STACK).yaml
__GIT_DEFAULT_BRANCH=main
# Change output
# https://www.mankier.com/5/terminfo#Description-Highlighting,_Underlining,_and_Visible_Bells
# https://www.linuxquestions.org/questions/linux-newbie-8/tput-for-bold-dim-italic-underline-blinking-reverse-invisible-4175704737/#post6308097
__RESET=$(shell tput sgr0)
__BLINK=$(shell tput blink)
__BOLD=$(shell tput bold)
__DIM=$(shell tput dim)
__SITM=$(shell tput sitm)
__REV=$(shell tput rev)
__SMSO=$(shell tput smso)
__SMUL=$(shell tput smul)
# https://www.mankier.com/5/terminfo#Description-Color_Handling
__BLACK=$(shell tput setaf 0)
__RED=$(shell tput setaf 1)
__GREEN=$(shell tput setaf 2)
__YELLOW=$(shell tput setaf 3)
__BLUE=$(shell tput setaf 4)
__MAGENTA=$(shell tput setaf 5)
__CYAN=$(shell tput setaf 6)
__WHITE=$(shell tput setaf 7)
# set to 'true' to disable colors
__NO_COLORS=false

ifeq ($(NO_TERM),true)
  __NO_COLORS=true
endif

ifeq ($(origin TERM), undefined)
  __NO_COLORS=true
endif

ifeq ($(__NO_COLORS),true)
  __RESET=
  __BLINK=
  __BOLD=
  __DIM=
  __SITM=
  __REV=
  __SMSO=
  __SMUL=
  __BLACK=
  __RED=
  __GREEN=
  __YELLOW=
  __BLUE=
  __MAGENTA=
  __CYAN=
  __WHITE=
endif

# Check for necessary tools
ifneq ($(filter help,$(MAKECMDGOALS)),)
  # Skip checks for help target
else
  ifeq (, $(shell which gcloud))
    $(error "No gcloud in $(PATH), go to https://cloud.google.com/sdk/docs/install, pick your OS, and follow the instructions")
  else ifeq (, $(shell which jq))
    $(error "No jq in $(PATH), please install jq: https://github.com/jqlang/jq?tab=readme-ov-file#installation")
  else ifeq (, $(shell which pulumi))
    $(error "No pulumi in $(PATH), get it from https://www.pulumi.com/docs/iac/download-install/")
	# TODO: uncomment when validate is implemented
  # else ifeq (, $(shell which tflint))
  #   $(error "No tflint in $(PATH), get it from https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation")
  # else ifeq (, $(shell which trivy))
  #   $(error "No trivy in $(PATH), get it from https://github.com/aquasecurity/trivy?tab=readme-ov-file#get-trivy")
  endif
endif

# Reusable "function" for 'up', 'destroy' and 'preview' commands
# Additional, space-separated arguments to the pulumi command are provided via $(PL_ARGS) variable
define pl
	$(eval $@_CMD = $(1))
	$(eval $@_CONF_FILE = $(2))
	$(eval $@_ARGS = $(foreach arg,$(3),$(arg)))

	if [ ! "${PL_CONVERGE_FROM}" = "" ]; then \
		if [ ! "${$@_ARGS}" = "" ]; then \
			pulumi ${$@_CMD} \
				--refresh=true \
				 --config-file='${$@_CONF_FILE}' \
				--stack='${STACK}' \
				--target='${PL_CONVERGE_FROM}' \
				--target-dependents \
				${$@_ARGS}; \
		else \
			pulumi ${$@_CMD} \
				--refresh=true \
				 --config-file='${$@_CONF_FILE}' \
				--stack='${STACK}' \
				--target='${PL_CONVERGE_FROM}' \
				--target-dependents; \
		fi; \
	fi; \

	if [ ! "${$@_ARGS}" = "" ]; then \
		pulumi ${$@_CMD} \
			--refresh=true \
			--stack='${STACK}' \
			--config-file='${$@_CONF_FILE}' \
			${$@_ARGS}; \
	else \
		pulumi ${$@_CMD} \
			--refresh=true \
			--stack='${STACK}' \
			--config-file='${$@_CONF_FILE}'; \
	fi
endef

help: ## Save our souls! 🛟
	@echo "$(__BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"; \
	echo "$(__BLUE)This Makefile contains opinionated targets that wrap pulumi commands,$(__RESET)"; \
	echo "$(__BLUE)providing sane defaults, initialization shortcuts for pulumi environment,$(__RESET)"; \
	echo "$(__BLUE)and support for remote pulumi backends via Google Cloud Storage.$(__RESET)"; \
	echo "$(__BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"; \
	echo ""; \
	echo "$(__YELLOW)Usage:$(__RESET)"; \
	echo "$(__BOLD)> GCP_PROJECT=demo STACK=demo make init$(__RESET)"; \
	echo "$(__BOLD)> make preview$(__RESET)"; \
	echo ""; \
	echo "$(__DIM)$(__SITM)Tip: Add a $(__BLINK)<space>$(__RESET) $(__DIM)$(__SITM)before the command if it contains sensitive information,$(__RESET)"; \
	echo "$(__DIM)$(__SITM)to keep it from bash history!$(__RESET)"; \
	echo ""; \
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"; \
	echo "$(__YELLOW)$(__SITM)Available commands$(__RESET) ⌨️ "; \
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"; \
	echo ""; \
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'; \
	echo ""; \
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"; \
	echo "$(__YELLOW)$(__SITM)Input variables for 'init'$(__RESET) 🧮"; \
	echo "$(__YELLOW)$(__SITM)$(__DIM)(Note: these are only used with 'init' target!)$(__RESET)"; \
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"; \
	echo ""; \
	echo "$(__MAGENTA)<STACK>                        $(__MAGENTA)󰮄$(__RESET) Pulumi stack to (potentially create and) switch to"; \
	echo "$(__MAGENTA)<GCP_PROJECT>                  $(__BLUE)󱇶$(__RESET) GCP project name $(__SITM)(usually, but not always, the project$(__RESET)"; \
	echo "                               $(__SITM)that pulumi changes are being applied to)$(__RESET)"; \
	echo "$(__MAGENTA)<GCP_PREFIX>                   $(__GREEN)󰾺$(__RESET) Prefix to use in some other GCP-related variables"; \
	echo "                               $(__SITM)(e.g., short company name)$(__RESET)"; \
	echo "$(__MAGENTA)<QUOTA_PROJECT>                $(__CYAN)$(__RESET) GCP quota project name"; \
	echo "                               $(__SITM)(NB! we assume quota project contains the state bucket)$(__RESET)"; \
	echo ""; \
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"; \
	echo "$(__YELLOW)$(__SITM)Input variables$(__RESET) 🧮"; \
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"; \
	echo ""; \
	echo "$(__MAGENTA)<PL_ARGS>                      $(__MAGENTA)󰮄$(__RESET) Additional pulumi command arguments"; \
	echo "                               $(__SITM)(e.g., make up PL_ARGS='--yes --expect-no-changes')$(__RESET)"; \
	echo "$(__MAGENTA)<NON_INTERACTIVE>              $(__MAGENTA)$(__RESET) Set to 'true' to disable Makefile prompts"; \
	echo "                               $(__SITM)(NB! This does not disable prompts coming from pulumi)$(__RESET)"; \
	echo ""; \
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"; \
	echo "$(__YELLOW)$(__SITM)Dependencies$(__RESET) 📦"; \
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"; \
	echo ""; \
	echo "$(__BLUE)- gcloud                       $(__GREEN)https://cloud.google.com/sdk/docs/install$(__RESET)"; \
	echo "$(__BLUE)- jq                           $(__GREEN)https://github.com/jqlang/jq?tab=readme-ov-file#installation$(__RESET)"; \
	echo "$(__BLUE)- pulumi                       $(__GREEN)https://www.pulumi.com/docs/iac/download-install/$(__RESET)"; \
	# echo "$(__BLUE)- tflint                       $(__GREEN)https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation$(__RESET)"; \
	# echo "$(__BLUE)- trivy                        $(__GREEN)https://github.com/aquasecurity/trivy?tab=readme-ov-file#get-trivy$(__RESET)"; \
	echo ""; \
	echo "$(__SITM)$(__DIM)Optional:$(__RESET)"; \
	echo "$(__BLUE)$(__DIM)- nerd font (for this help)    $(__GREEN)https://www.nerdfonts.com/$(__RESET)"; \
	echo ""

_set-env:
	@echo "$(__BOLD)Setting environment variables...$(__RESET)"
	if [ -z $(STACK) ]; then \
		echo "$(__BOLD)$(__RED)STACK was not set$(__RESET)"; \
		_ERROR=1; \
	fi; \
	if [ ! -f "$(__PL_CONF_PATH)" ]; then \
		echo "$(__BOLD)$(__RED)Could not find variables file: $(__PL_CONF_PATH)$(__RESET)"; \
		_ERROR=1; \
	fi; \
	if [ ! -z "$${_ERROR}" ] && [ "$${_ERROR}" -eq 1 ]; then \
		# https://stackoverflow.com/a/3267187
		echo "$(__BOLD)$(__RED)Error: failed to set environment variables$(__RESET)"; \
		echo "$(__BOLD)$(__RED)Run $(__DIM)$(__BLINK)make help$(__RESET) $(__BOLD)$(__RED)for usage details$(__RESET)"; \
		exit 1; \
	fi
	echo "$(__BOLD)$(__GREEN)Done setting environment variables$(__RESET)"
	echo ""

init: SHELL:=/bin/bash
init: ## Hoist the sails and prepare for the voyage! 🌬️💨
	@echo "$(__BOLD)Initializing pulumi...$(__RESET)"; \

	# Auth and configure GCP project
	echo "$(__BOLD)Checking GCP project...$(__RESET)"; \
	_CURRENT_PROJECT=$$(gcloud config get project | tr -d '[:space:]'); \
	if [ ! -z $(GCP_PROJECT) ] && [ "$(GCP_PROJECT)" != "$${_CURRENT_PROJECT}" ]; then \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Current project $${_CURRENT_PROJECT}. Do you want to switch project? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			gcloud config set project $(GCP_PROJECT) && \
			gcloud auth login --update-adc ; \
			echo "$(__BOLD)$(__GREEN)Project changed to $(GCP_PROJECT)$(__RESET)"; \
		else
			echo "$(__BOLD)$(__CYAN)Using project ($${_CURRENT_PROJECT})$(__RESET)"; \
		fi; \
	else
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Do you want to re-login and update ADC with ($${_CURRENT_PROJECT}) project? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			gcloud auth login --update-adc ; \
		fi; \
		echo "$(__BOLD)$(__CYAN)Project is set to ($${_CURRENT_PROJECT})$(__RESET)"; \
	fi; \
	# Configure ADC quota project
	_CURRENT_QUOTA_PROJECT=$$(cat ~/.config/gcloud/application_default_credentials.json | jq '.quota_project_id' | tr -d '"'); \
	if [ "$(QUOTA_PROJECT)" != "$${_CURRENT_QUOTA_PROJECT}" ]; then \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Do you want to update ADC quota-project from ($${_CURRENT_QUOTA_PROJECT}) to ($(QUOTA_PROJECT))? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			gcloud auth application-default set-quota-project $(QUOTA_PROJECT) ; \
			echo "$(__BOLD)$(__CYAN)Quota-project is set to ($(QUOTA_PROJECT))$(__RESET)"; \
		fi; \
	fi; \

	# Configure pulumi backend
	echo "$(__BOLD)Configuring the pulumi backend...$(__RESET)"; \
	_PULUMI_BACKEND=""; \
	if [ -f "$${HOME}/.pulumi/credentials.json" ]; then \
		_PULUMI_BACKEND=$$(cat $${HOME}/.pulumi/credentials.json | jq -r '.current'); \
	else \
		_PULUMI_BACKEND="null"; \
	fi; \
	echo "$(__BOLD)$(__CYAN)Current backend: $(__DIM)$${_PULUMI_BACKEND}$(__RESET)"; \

	if [ "$(__PL_BACKEND)" != "" ]; then \
		pulumi logout; \
		if [ "$(__PL_BACKEND)" = "local" ]; then \
			pulumi login --local; \
		else \
			pulumi login "$(__PL_BACKEND)"; \
		fi; \
	fi; \

	[ "$(__PL_BACKEND)" = "" ] && read -p "$(__BOLD)$(__MAGENTA)Use local backend? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		if [ "$${_PULUMI_BACKEND}" = "null" ]; then \
			pulumi login --local; \
		else \
			if [ "$${_PULUMI_BACKEND}" != "file://~" ]; then \
				pulumi logout; \
				pulumi login --local; \
			fi; \
		fi; \
	else # use remote backend \
		if ! echo "$${_PULUMI_BACKEND}" | grep -q "^gs://"; then \
			pulumi logout; \
			_BUCKET_NAME=$$(gcloud storage buckets list --project $(QUOTA_PROJECT) --format='get(name)' | grep '$(__GCS_BUCKET)' | head -n1 | tr -d '[:space:]'); \
			_BUCKET_SUBDIR=$(__TEST_BUCKET_SUBDIR); \
			_COLOR=$(__GREEN); \
			([ ! "$(NON_INTERACTIVE)" = "true" ] && [ ! "$(__ENVIRONMENT)" = "test" ]) && \
			read -p "$(__BOLD)$(__MAGENTA)Use $(__BLINK)$(__YELLOW)production$(__RESET) $(__BOLD)$(__MAGENTA)state bucket subdir? [y/Y]: $(__RESET)" ANSWER && \
			if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
				_BUCKET_SUBDIR=$(__PROD_BUCKET_SUBDIR); \
				_COLOR=$(__RED); \
			fi; \
			if ([ "$(NON_INTERACTIVE)" = "true" ] && [ "$(__ENVIRONMENT)" = "prod" ]); then \
				_BUCKET_SUBDIR=$(__PROD_BUCKET_SUBDIR); \
				_COLOR=$(__RED); \
			fi; \
			_BUCKET_PATH="$(__BUCKET_DIR)/$${_BUCKET_SUBDIR}"; \
			echo "$(__BOLD)Using bucket ($(__DIM)$${_BUCKET_NAME}$(__RESET)) $(__BOLD)with path ($(__DIM)$${_COLOR}$${_BUCKET_PATH}$(__RESET)$(__BOLD))$(__RESET)"; \
			[ ! "$(NON_INTERACTIVE)" = "true" ] && \
			read -p "$(__BOLD)$(__MAGENTA)Do you want to proceed? [y/Y]: $(__RESET)" ANSWER && \
			if [ "$${ANSWER}" != "y" ] && [ "$${ANSWER}" != "Y" ]; then \
				echo "$(__BOLD)$(__YELLOW)Exiting...$(__RESET)"; \
				exit 1; \
			fi; \

			pulumi login "gs://$${_BUCKET_NAME}/$${_BUCKET_PATH}"; \
		fi; \
	fi; \

	if [ ! -f "Pulumi.yaml" ]; then \
		echo "$(__BOLD)Initializing new pulumi project...$(__RESET)"; \
		pulumi new; \
	fi; \

	echo "$(__BOLD)Checking pulumi stack...$(__RESET)"; \
	_CURRENT_STACK=$$(pulumi stack --show-name 2>/dev/null || echo "null" | tr -d '[:space:]'); \
	if [ '$(STACK)' = 'null' ] && [ "$${_CURRENT_STACK}" = 'null' ]; then \
		_AVAILABLE_STACKS=($$(pulumi stack ls --json | jq -r '.[].name')); \
		echo "Available stacks: $${_AVAILABLE_STACKS[@]}"; \
		select stack in "$${_AVAILABLE_STACKS[@]}"; do \
			if [[ -n "$$stack" ]]; then \
				pulumi stack select "$${stack}"; \
				break; \
			else \
				echo "$(__BOLD)$(__RED)Error: no stack set or selected$(__RESET)"; \
				echo "$(__BOLD)$(__RED)Exiting...$(__RESET)"; \
				exit 42; \
			fi; \
		done; \
	elif [ ! -z $(STACK) ] && [ "$(STACK)" != 'null' ] && [ "$(STACK)" != "$${_CURRENT_STACK}" ]; then \
		echo "$(__BOLD)Switching to stack ($(STACK))$(__RESET)"; \
		pulumi stack select --create $(STACK); \
	else \
		echo "$(__BOLD)$(__CYAN)Using stack ($${_CURRENT_STACK})$(__RESET)"; \
	fi; \

	# TODO: not implemented
	# # Initialize tflint
	# if [ -f ".tflint.hcl" ]; then \
	# 	echo "$(__BOLD)Initializing tflint...$(__RESET)"; \
	# 	tflint --init; \
	# fi; \

	# Done
	echo "$(__BOLD)$(__GREEN)Done initializing pulumi$(__RESET)"; \
	echo "$(__BOLD)$(__CYAN)You can now run other commands, for example:$(__RESET)"; \
	echo "$(__BOLD)$(__CYAN)run $(__DIM)$(__BLINK)make preview$(__RESET) $(__BOLD)$(__CYAN)to preview what pulumi thinks it will do when applying changes,$(__RESET)"; \
	echo "$(__BOLD)$(__CYAN)or $(__DIM)$(__BLINK)make help$(__RESET) $(__BOLD)$(__CYAN)to see all available make targets$(__RESET)"

# TODO: not implemented
# format: ## Swab the deck and tidy up! 🧹
# 	@terraform fmt \
# 		-write=true \
# 		-recursive

# TODO:
# https://github.com/terraform-linters/tflint
# https://aquasecurity.github.io/trivy
# validate: _set-env ## Inspect the rigging and report any issues! 🔍
# 	@echo "$(__BOLD)Check terraform formatting...$(__RESET)"; \
# 	terraform fmt -check=true -recursive; \
# 	echo "$(__BOLD)Validate terraform configuration...$(__RESET)"; \
# 	terraform validate; \
# 	echo "$(__BOLD)Lint terraform files...$(__RESET)"; \
# 	tflint --var-file "$(__PL_CONF_PATH)"; \
# 	# https://aquasecurity.github.io/trivy/v0.53/docs/coverage/iac/terraform/
# 	# TIP: suppress issues via inline comments:
# 	# https://aquasecurity.github.io/trivy/v0.46/docs/configuration/filtering/#by-inline-comments
# 	echo "$(__BOLD)\nScan for vulnerabilities...$(__RESET)"; \
# 	trivy conf --exit-code 42 --tf-vars "$(__PL_CONF_PATH)" .; \
# 	echo ""

# TODO: uncomment when validate is implemented 
# test: validate ## Run some drills before we plunder! ⚔️  🏹
test: ## Run some drills before we plunder! ⚔️  🏹
	@# suppress target contents output
	_GIT_STATUS=$$(git status --porcelain --untracked-files=no); \
	_GIT_CURRENT_BRANCH=$$(git rev-parse --abbrev-ref HEAD | tr -d '[:space:]'); \
	if [ -n "$${_GIT_STATUS}" ]; then \
		echo "$(__BOLD)$(__RED)Working directory has uncommitted changes. Commit or stash your changes before proceeding!$(__RESET)"; \
		exit 1; \
	elif [ "$${_GIT_CURRENT_BRANCH}" = "$(__GIT_DEFAULT_BRANCH)" ]; then \
		echo "$(__BOLD)$(__RED)Unable to proceed in a default git branch. Switch to another branch before proceeding$(__RESET)"; \
		exit 1; \
	fi; \
	_INITIAL_STACK=$$(terraform workspace show | tr -d '[:space:]'); \
	_TEMP_STACK="test-$$(uuidgen | cut -d '-' -f 1)"; \
	# use latest changes in default, upstream branch as baseline
	git pull origin $(__GIT_DEFAULT_BRANCH) && git checkout origin/$(__GIT_DEFAULT_BRANCH); \
	# ensure vars and inputs are available for testing
	cp vars/$${_INITIAL_STACK}.tfvars vars/$${_TEMP_STACK}.tfvars; \
	if [ -f "inputs/${{_INITIAL_STACK}}" ]; then cp -r inputs/$${_INITIAL_STACK} inputs/$${_TEMP_STACK}; fi; \
	# init
	make init __ENVIRONMENT="test" NON_INTERACTIVE=true STACK="$${_TEMP_STACK}"; \
	# check if we're running in a temp workspace
	_CURRENT_STACK=$$(terraform workspace show | xargs) && if [ "$${_CURRENT_STACK}" != "$${_TEMP_STACK}" ]; then \
		echo "$(__BOLD)$(__RED)Current workspace does equal ($${_TEMP_STACK})$(__RESET)"; \
		exit 1; \
	fi; \
	# check backend configuration
	if ! (cat .terraform/terraform.tfstate | jq '.backend.config.prefix' | grep -q '$(__BUCKET_DIR)/$(__TEST_BUCKET_SUBDIR)'); then \
		echo "$(__BOLD)$(__RED)Terraform state is configured with NON-test backend!$(__RESET)"; \
		exit 1; \
	fi; \
	# apply against origin baseline
	make apply NON_INTERACTIVE=true; \
	# switch back to initial branch
	git switch -; \
	# re-initialize terraform to pull latest modules, providers, etc from the changeset under test
	make init __ENVIRONMENT="test" NON_INTERACTIVE=true STACK="$${_TEMP_STACK}"; \
	# check if we're running in a temp workspace
	_CURRENT_STACK=$$(terraform workspace show | xargs) && if [ "$${_CURRENT_STACK}" != "$${_TEMP_STACK}" ]; then \
		echo "$(__BOLD)$(__RED)Current workspace does equal ($${_TEMP_STACK})$(__RESET)"; \
		exit 1; \
	fi; \
	# check backend configuration
	if ! (cat .terraform/terraform.tfstate | jq '.backend.config.prefix' | grep -q '$(__BUCKET_DIR)/$(__TEST_BUCKET_SUBDIR)'); then \
		echo "$(__BOLD)$(__RED)Terraform state is configured with NON-test backend!$(__RESET)"; \
		exit 1; \
	fi; \
	# apply to test the changeset
	make apply NON_INTERACTIVE=true; \
	# check if there are any changes pending afterwards
	# TODO: make preview NON_INTERACTIVE=true PL_ARGS='--expect-no-changes'; \
	echo "$(__BOLD)$(__GREEN)$(__BLINK)All tests passed!$(__RESET)"; \
	# cleanup
	if [ "$(NON_INTERACTIVE)" = "true" ]; then \
		make destroy PL_ARGS='--remove'; \
		pulumi stack select "$${_INITIAL_STACK}"; \
	fi; \
	[ ! "$(NON_INTERACTIVE)" = "true" ] && \
	read -p "$(__BOLD)$(__MAGENTA)Would you like to destroy the test infrastructure? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		make destroy; \
	fi; \
	[ ! "$(NON_INTERACTIVE)" = "true" ] && \
	read -p "$(__BOLD)$(__MAGENTA)Switch back to ($${_INITIAL_STACK}) workspace and delete ($${_TEMP_STACK}) workspace? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		pulumi stack select "$${_INITIAL_STACK}"; \
		pulumi stack rm "$${_TEMP_STACK}"; \
	fi

preview: ## Chart the course before you sail! 🗺️
	@# hide target content
	$(call pl,preview,$(__PL_CONF_PATH),$(PL_ARGS))

# TODO: Not implemented
# preview-destroy: ## What would happen if we blow it all to smithereens? 💣
# 	@terraform plan \
# 		-input=false \
# 		-refresh=true \
# 		-destroy \
# 		-var-file="$(__PL_CONF_PATH)"

# TODO: uncomment when validate is implemented 
# up: validate ## Set course and full speed ahead! ⛵ This will cost you! 💰
up: ## Set course and full speed ahead! ⛵ This will cost you! 💰
	@# hide target content
	$(call pl,up,$(__PL_CONF_PATH),$(PL_ARGS))

# TODO: uncomment when validate is implemented 
# destroy: validate ## Release the Kraken! 🐙 This can't be undone! ☠️
destroy: ## Release the Kraken! 🐙 This can't be undone! ☠️
	@# hide target content
	$(call pl,destroy,$(__PL_CONF_PATH),$(PL_ARGS))

# TODO: not implemented
# clean: ## Nuke local .terraform directory! 💥
# 	echo "$(__BOLD)Cleaning up...$(__RESET)"
# 	_DIR="$(CURDIR)/.terraform" ; \
# 	[ ! "$(NON_INTERACTIVE)" = "true" ] && \
# 	read -p "$(__BOLD)$(__MAGENTA)Do you want to remove ($${_DIR})? [y/Y]: $(__RESET)" ANSWER && \
# 	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
# 		rm -rf "$${_DIR}"; \
# 		echo "$(__BOLD)$(__CYAN)Removed ($${_DIR})$(__RESET)"; \
# 	fi
