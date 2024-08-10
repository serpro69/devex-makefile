# Copyright 2024- Serhii Prodanov
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.ONESHELL:
.SHELL := /usr/bin/env bash
.SHELLFLAGS := -ec
.PHONY: apply clean destroy format help init plan plan-destroy test validate
# https://stackoverflow.com/a/63771055
__MAKE_DIR=$(dir $(realpath $(lastword $(MAKEFILE_LIST))))
# Use below for reference on how to use variables in a Makefile:
# - https://www.gnu.org/software/make/manual/html_node/Using-Variables.html
# - https://www.gnu.org/software/make/manual/html_node/Flavors.html
# - https://www.gnu.org/software/make/manual/html_node/Setting.html
# - https://www.gnu.org/software/make/manual/html_node/Shell-Function.html
WORKSPACE ?= $(shell terraform workspace show | tr -d '[:space:]')
GCP_PROJECT ?= $(shell gcloud config get project | tr -d '[:space:]')
GCP_PREFIX=wlcm
GCP_POSTFIX=ffcb87
QUOTA_PROJECT=$(GCP_PREFIX)-tfstate-$(GCP_POSTFIX)
# Additional, space-separated, terraform command options
TF_ARGS ?=
# Set to 'true' for non-interactive usage
NON_INTERACTIVE ?=
# Environment options
__ENVIRONMENT ?=
__BUCKET_DIR=terraform/state
__PROD_BUCKET_SUBDIR=prod
__TEST_BUCKET_SUBDIR=test
__TFVARS_PATH=vars/$(WORKSPACE).tfvars
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

# Check for necessary tools
ifeq (, $(shell which gcloud))
	$(error "No gcloud in $(PATH), go to https://cloud.google.com/sdk/docs/install, pick your OS, and follow the instructions")
endif
ifeq (, $(shell which jq))
	$(error "No jq in $(PATH), please install jq: https://github.com/jqlang/jq?tab=readme-ov-file#installation")
endif
ifeq (, $(shell which terraform))
	$(error "No terraform in $(PATH), get it from https://www.terraform.io/downloads.html")
endif
ifeq (, $(shell which tflint))
	$(info "No tflint in $(PATH), get it from https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation")
endif
ifeq (, $(shell which trivy))
	$(info "No trivy in $(PATH), get it from https://github.com/aquasecurity/trivy?tab=readme-ov-file#get-trivy")
endif

# Reusable "function" for 'apply', 'destroy' and 'plan' commands
# Additional, space-separated arguments to the terraform command are provided via $(TF_ARGS) variable
define tf
	$(eval $@_CMD = $(1))
	$(eval $@_VAR_FILE = $(2))
	$(eval $@_ARGS = $(foreach arg,$(3),$(arg)))
	if [ ! "${$@_ARGS}" = "" ]; then
		terraform ${$@_CMD} \
			-lock=true \
			-input=false \
			-refresh=true \
			-var-file='${$@_VAR_FILE}' \
			${$@_ARGS}
	else
		terraform ${$@_CMD} \
			-lock=true \
			-input=false \
			-refresh=true \
			-var-file='${$@_VAR_FILE}'
	fi
endef

help: ## Save our souls! 🛟
	@echo "$(__BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"
	echo "$(__BLUE)This Makefile contains opinionated targets that wrap terraform commands,$(__RESET)"
	echo "$(__BLUE)providing sane defaults, initialization shortcuts for terraform environment,$(__RESET)"
	echo "$(__BLUE)and support for remote terraform backends via Google Cloud Storage.$(__RESET)"
	echo "$(__BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"
	echo ""
	echo "$(__YELLOW)Usage:$(__RESET)"
	echo "$(__BOLD)> GCP_PROJECT=demo WORKSPACE=demo make init$(__RESET)"
	echo "$(__BOLD)> make plan$(__RESET)"
	echo ""
	echo "$(__DIM)$(__SITM)Tip: Add a $(__BLINK)<space>$(__RESET) $(__DIM)$(__SITM)before the command if it contains sensitive information,$(__RESET)"
	echo "$(__DIM)$(__SITM)to keep it from bash history!$(__RESET)"
	echo ""
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"
	echo "$(__YELLOW)$(__SITM)Available commands$(__RESET) ⌨️ "
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"
	echo ""
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	echo ""
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"
	echo "$(__YELLOW)$(__SITM)Input variables for 'init'$(__RESET) 🧮"
	echo "$(__YELLOW)$(__SITM)$(__DIM)(Note: these are only used with 'init' target!)$(__RESET)"
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"
	echo ""
	echo "$(__MAGENTA)<WORKSPACE>                    $(__MAGENTA)󱁢$(__RESET) Terraform workspace to (potentially create and) switch to"
	echo "$(__MAGENTA)<GCP_PROJECT>                  $(__BLUE)󱇶$(__RESET) GCP project name $(__SITM)(usually, but not always, the project$(__RESET)"
	echo "                               $(__SITM)that terraform changes are being applied to)$(__RESET)"
	echo "$(__MAGENTA)<GCP_PREFIX>                   $(__GREEN)󰾺$(__RESET) Prefix to use in some other GCP-related variables"
	echo "                               $(__SITM)(e.g., short company name)$(__RESET)"
	echo "$(__MAGENTA)<QUOTA_PROJECT>                $(__CYAN)$(__RESET) GCP quota project name"
	echo "                               $(__SITM)(NB! we assume quota project contains the .tfstate bucket)$(__RESET)"
	echo ""
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"
	echo "$(__YELLOW)$(__SITM)Input variables$(__RESET) 🧮"
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"
	echo ""
	echo "$(__MAGENTA)<TF_ARGS>                      $(__MAGENTA)󱁢$(__RESET) Additional terraform command arguments"
	echo "                               $(__SITM)(e.g., make apply TF_ARGS='-out=foo.out -lock=false')$(__RESET)"
	echo "$(__MAGENTA)<NON_INTERACTIVE>              $(__MAGENTA)$(__RESET) Set to 'true' to disable Makefile prompts"
	echo "                               $(__SITM)(NB! This does not disable prompts coming from terraform)$(__RESET)"
	echo ""
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"
	echo "$(__YELLOW)$(__SITM)Dependencies$(__RESET) 📦"
	echo "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)"
	echo ""
	echo "$(__BLUE)- gcloud                       $(__GREEN)https://cloud.google.com/sdk/docs/install$(__RESET)"
	echo "$(__BLUE)- jq                           $(__GREEN)https://github.com/jqlang/jq?tab=readme-ov-file#installation$(__RESET)"
	echo "$(__BLUE)- terraform                    $(__GREEN)https://www.terraform.io/downloads.html$(__RESET)"
	echo "$(__BLUE)- tflint                       $(__GREEN)https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation$(__RESET)"
	echo "$(__BLUE)- trivy                        $(__GREEN)https://github.com/aquasecurity/trivy?tab=readme-ov-file#get-trivy$(__RESET)"
	echo ""
	echo "$(__SITM)$(__DIM)Optional:$(__RESET)"
	echo "$(__BLUE)$(__DIM)- nerd font (for this help)    $(__GREEN)https://www.nerdfonts.com/$(__RESET)"
	echo ""

_set-env:
	@echo "$(__BOLD)Setting environment variables...$(__RESET)"
	if [ -z $(WORKSPACE) ]; then \
		echo "$(__BOLD)$(__RED)WORKSPACE was not set$(__RESET)"; \
		_ERROR=1; \
	fi; \
	if [ ! -f "$(__TFVARS_PATH)" ]; then \
		echo "$(__BOLD)$(__RED)Could not find variables file: $(__TFVARS_PATH)$(__RESET)"; \
		_ERROR=1; \
	fi; \
	if [ ! -z "$${_ERROR}" ] && [ "$${_ERROR}" -eq 1 ]; then \
		# https://stackoverflow.com/a/3267187
		echo "$(__BOLD)$(__RED)Failed to set environment variables\nRun $(__DIM)$(__BLINK)make help$(__RESET) $(__BOLD)$(__RED)for usage details$(__RESET)"
		exit 1; \
	fi
	echo "$(__BOLD)$(__GREEN)Done setting environment variables$(__RESET)"
	echo ""

_check-ws: _set-env
	@if [ "$(WORKSPACE)" = "default" ]; then \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)It is usually not desirable to use ($(WORKSPACE)) workspace. Do you want to proceed? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" != "y" ] && [ "$${ANSWER}" != "Y" ]; then \
			echo "$(__BOLD)$(__YELLOW)Exiting...$(__RESET)"; \
			exit 0; \
		fi; \
	fi

init: _check-ws ## Hoist the sails and prepare for the voyage! 🌬️💨
	@echo "$(__BOLD)Initializing terraform...$(__RESET)"
	echo "$(__BOLD)Checking GCP project...$(__RESET)"
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
	fi

	_CURRENT_QUOTA_PROJECT=$$(cat ~/.config/gcloud/application_default_credentials.json | jq '.quota_project_id' | tr -d '"'); \
	if [ "$(QUOTA_PROJECT)" != "$${_CURRENT_QUOTA_PROJECT}" ]; then \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Do you want to update ADC quota-project from ($${_CURRENT_QUOTA_PROJECT}) to ($(QUOTA_PROJECT))? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			gcloud auth application-default set-quota-project $(QUOTA_PROJECT) ; \
			echo "$(__BOLD)$(__CYAN)Quota-project is set to ($(QUOTA_PROJECT))$(__RESET)"; \
		fi; \
	fi

	# Configure GCS backend
	echo "$(__BOLD)Configuring the terraform backend...$(__RESET)"; \
	_BUCKET_NAME=$$(gcloud storage buckets list --project $(QUOTA_PROJECT) --format='get(name)' | grep 'tfstate' | head -n1 | tr -d '[:space:]'); \
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
		exit 0; \
	fi

	# Need to switch to default workspace, since the target WORKSPACE might not exist in the selected bucket
	# (when changing between prod and non-prod state bucket sub-dirs)
	_CURRENT_WORKSPACE=$$(terraform workspace show | tr -d '[:space:]') && \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" != "$${_CURRENT_WORKSPACE}" ]; then \
		echo "$(__BOLD)Temporarily switching to 'default' workspace$(__RESET)"
		terraform workspace select default; \
	fi

	terraform init \
		-reconfigure \
		-input=false \
		-force-copy \
		-lock=true \
		-upgrade \
		-backend=true \
		-backend-config="bucket=$${_BUCKET_NAME}" \
		-backend-config="prefix=$${_BUCKET_PATH}"

	echo "$(__BOLD)Checking terraform workspace...$(__RESET)"
	_CURRENT_WORKSPACE=$$(terraform workspace show | tr -d '[:space:]'); \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" != "$${_CURRENT_WORKSPACE}" ]; then \
		echo "$(__BOLD)Switching to workspace ($(WORKSPACE))$(__RESET)"
		terraform workspace select -or-create $(WORKSPACE); \
	else
		echo "$(__BOLD)$(__CYAN)Using workspace ($${_CURRENT_WORKSPACE})$(__RESET)"; \
	fi
	echo "$(__BOLD)$(__GREEN)Done initializing terraform$(__RESET)"
	echo "$(__BOLD)$(__CYAN)You can now run other commands, for example:\nrun $(__DIM)$(__BLINK)make plan$(__RESET) $(__BOLD)$(__CYAN)to preview what terraform thinks it will do when applying changes,\nor $(__DIM)$(__BLINK)make help$(__RESET) $(__BOLD)$(__CYAN)to see all available make targets$(__RESET)"

format: ## Swab the deck and tidy up! 🧹
	@terraform fmt \
		-write=true \
		-recursive

# https://github.com/terraform-linters/tflint
# https://aquasecurity.github.io/trivy
validate: _set-env ## Inspect the rigging and report any issues! 🔍
	@echo "$(__BOLD)Validate terraform configuration...$(__RESET)"
	terraform validate
	echo "$(__BOLD)Lint terraform files...$(__RESET)"
	tflint --var-file "$(__TFVARS_PATH)"
	# https://aquasecurity.github.io/trivy/v0.53/docs/coverage/iac/terraform/
	# TIP: suppress issues via inline comments:
	# https://aquasecurity.github.io/trivy/v0.46/docs/configuration/filtering/#by-inline-comments
	echo "$(__BOLD)\nScan for vulnerabilities...$(__RESET)"
	trivy conf --exit-code 42 --tf-vars "$(__TFVARS_PATH)" .
	echo ""

test: validate _check-ws ## Run some drills before we plunder! ⚔️  🏹
	@# suppress make output
	_GIT_STATUS=$$(git status --porcelain --untracked-files=no); \
	_GIT_CURRENT_BRANCH=$$(git rev-parse --abbrev-ref HEAD | tr -d '[:space:]'); \
	if [ -n "$${_GIT_STATUS}" ]; then \
		echo "$(__BOLD)$(__RED)Working directory has uncommitted changes. Commit or stash your changes before proceeding!$(__RESET)"; \
		exit 1; \
	elif [ "$${_GIT_CURRENT_BRANCH}" = "$(__GIT_DEFAULT_BRANCH)" ]; then \
		echo "$(__BOLD)$(__RED)Unable to proceed in a default git branch. Switch to another branch before proceeding$(__RESET)"; \
		exit 1; \
	fi; \
	_INITIAL_WORKSPACE=$$(terraform workspace show | tr -d '[:space:]'); \
	_TEMP_WORKSPACE="test-$$(uuidgen | cut -d '-' -f 1)"; \
	# use latest changes in default, upstream branch as baseline
	git pull origin $(__GIT_DEFAULT_BRANCH) && git checkout origin/$(__GIT_DEFAULT_BRANCH); \
	# ensure vars and inputs are available for testing
	cp vars/$${_INITIAL_WORKSPACE}.tfvars vars/$${_TEMP_WORKSPACE}.tfvars; \
	cp -r inputs/$${_INITIAL_WORKSPACE} inputs/$${_TEMP_WORKSPACE}; \
	# init
	make init __ENVIRONMENT="test" NON_INTERACTIVE=true WORKSPACE="$${_TEMP_WORKSPACE}"; \
	# check if we're running in a temp workspace
	_CURRENT_WORKSPACE=$$(terraform workspace show | xargs) && if [ "$${_CURRENT_WORKSPACE}" != "$${_TEMP_WORKSPACE}" ]; then \
		echo "$(__BOLD)$(__RED)Current workspace does equal ($${_TEMP_WORKSPACE})$(__RESET)"; \
		exit 1; \
	fi
	# apply against origin baseline
	make apply NON_INTERACTIVE=true; \
	# switch back to initial branch
	git switch -; \
	# re-initialize terraform to pull latest modules, providers, etc from the changeset under test
	make init __ENVIRONMENT="test" NON_INTERACTIVE=true; \
	# apply to test the changeset
	make apply NON_INTERACTIVE=true; \
	echo "$(__BOLD)$(__GREEN)$(__BLINK)All tests passed!$(__RESET)"; \
	# always ask before destroying!
	read -p "$(__BOLD)$(__MAGENTA)Would you like to destroy the test infrastructure? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		make destroy; \
	fi; \
	read -p "$(__BOLD)$(__MAGENTA)Switch back to ($${_INITIAL_WORKSPACE}) workspace and delete ($${_TEMP_WORKSPACE}) workspace? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		terraform workspace select "$${_INITIAL_WORKSPACE}"; \
		terraform workspace delete --force "$${_TEMP_WORKSPACE}"; \
	fi

plan: _check-ws ## Chart the course before you sail! 🗺️
	@# hide target content
	$(call tf,plan,$(__TFVARS_PATH),$(TF_ARGS))

plan-destroy: _check-ws ## What would happen if we blow it all to smithereens? 💣
	@terraform plan \
		-input=false \
		-refresh=true \
		-destroy \
		-var-file="$(__TFVARS_PATH)"

apply: validate _check-ws ## Set course and full speed ahead! ⛵ This will cost you! 💰
	@# hide target content
	$(call tf,apply,$(__TFVARS_PATH),$(TF_ARGS))

destroy: validate _check-ws ## Release the Kraken! 🐙 This can't be undone! ☠️
	@# hide target content
	$(call tf,destroy,$(__TFVARS_PATH),$(TF_ARGS))

clean: _check-ws ## Nuke local .terraform directory! 💥
	echo "$(__BOLD)Cleaning up...$(__RESET)"
	_DIR="$(CURDIR)/.terraform" ; \
	[ ! "$(NON_INTERACTIVE)" = "true" ] && \
	read -p "$(__BOLD)$(__MAGENTA)Do you want to remove ($${_DIR})? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		rm -rf "$${_DIR}"; \
		echo "$(__BOLD)$(__CYAN)Removed ($${_DIR})$(__RESET)"; \
	fi
