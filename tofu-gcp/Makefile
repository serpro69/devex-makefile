# Copyright 2024- Serhii Prodanov
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.ONESHELL:
.SHELL := $(shell which bash)
.SHELLFLAGS := -ec
.PHONY: apply clean destroy format help init plan plan-destroy test validate
# https://stackoverflow.com/a/63771055
__MAKE_DIR=$(dir $(realpath $(lastword $(MAKEFILE_LIST))))
# Use below for reference on how to use variables in a Makefile:
# - https://www.gnu.org/software/make/manual/html_node/Using-Variables.html
# - https://www.gnu.org/software/make/manual/html_node/Flavors.html
# - https://www.gnu.org/software/make/manual/html_node/Setting.html
# - https://www.gnu.org/software/make/manual/html_node/Shell-Function.html
### OpenTofu
WORKSPACE ?= $(shell tofu workspace show | tr -d '[:space:]')
# Additional, space-separated, tofu command options
TF_ARGS ?=
# Set a resource path to apply first, before fully converging the entire configuration
# This is a shortcut to avoid calling make apply twice, i.e. 'make apply TF_ARGS='-target="some_resource.name"' && make apply'
# NB! this will apply the changes to the `some_resource.name` even when used with 'plan' target.
TF_CONVERGE_FROM ?=
# OpenTofu plan file path (used with plan, apply, and destroy targets)
TF_PLAN ?=
# Customize gcloud command
GCLOUD=gcloud
### Google Cloud Platform
GCP_PROJECT ?= $(shell $(GCLOUD) config get project 2>/dev/null | tr -d '[:space:]')
GCP_PREFIX=wlcm
GCP_POSTFIX=ffcb87
QUOTA_PROJECT=$(GCP_PREFIX)-tfstate-$(GCP_POSTFIX)
### Terminal
# Set to 'true' for non-interactive usage
NON_INTERACTIVE ?=
# Set to 'true' to disable some options like colors in environments where $TERM is not set
NO_TERM ?=
# Set to `true` to skip validate
__NO_VALIDATE ?=
### Environment options
__ENVIRONMENT ?= $(shell cat .terraform/terraform.tfstate | jq -r '.backend.config.prefix // ""' | cut -d '/' -f 3)
__BUCKET_DIR=terraform/state
__PROD_BUCKET_SUBDIR=prod
__TEST_BUCKET_SUBDIR=test
__TFVARS_PATH=vars/$(WORKSPACE).tfvars
# backup terraform.tfvars before overwriting it with decrypted content
__BACKUP_TFVARS=false
__GIT_DEFAULT_BRANCH=main
__DEBUG ?=
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
  else ifeq (, $(shell which tofu))
    $(error "No tofu in $(PATH), get it from https://opentofu.org/docs/intro/install")
  else ifeq (, $(shell which tflint))
    $(error "No tflint in $(PATH), get it from https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation")
  else ifeq (, $(shell which trivy))
    $(error "No trivy in $(PATH), get it from https://github.com/aquasecurity/trivy?tab=readme-ov-file#get-trivy")
  endif
endif

# decrypt terraform.$(__ENVIRONMENT).tfvars file if it's encrypted
# comment out the variables based on a workspace otherwise
define tfvars
	@enc_tfvars_file=''; \
	if [ -f terraform.tfvars.sops ]; then \
		enc_tfvars_file='terraform.tfvars.sops'; \
	elif [ -f terraform.tfvars-$(__ENVIRONMENT).sops ]; then \
		enc_tfvars_file='terraform.tfvars-$(__ENVIRONMENT).sops'; \
	fi; \
	if [ -n "$${enc_tfvars_file}" ]; then \
		if ! command -v sops &> /dev/null; then \
			printf "$(__BOLD)$(__YELLOW)Warning: sops is not installed$(__RESET)\n"; \
		else \
			if [ "(__BACKUP_TFVARS)" == "true" ] && [ -f terraform.tfvars ]; then \
				cp terraform.tfvars{,.bak.$$(date +%s%N)}; \
			fi; \
			sops decrypt "$${enc_tfvars_file}" > terraform.tfvars; \
		fi; \
	fi; \
	search_string="$(WORKSPACE)"; \
	perl -i -pe 'if (m/#\s*'"$${search_string}"'$$/) { \
		if (m/^\s*#\s*/) { \
				s/^\s*#\s*//; \
		} else { \
				s/^/# /; \
		} \
	}' terraform.tfvars; \
	enc_ws_tfvars_file='$(__TFVARS_PATH).sops'; \
	if [ -f "$${enc_ws_tfvars_file}" ]; then \
		if ! command -v sops &> /dev/null; then \
			printf "$(__BOLD)$(__YELLOW)Warning: sops is not installed$(__RESET)\n"; \
		else \
			sops decrypt "$${enc_ws_tfvars_file}" >> terraform.tfvars; \
		fi; \
	fi
endef

# Reusable "function" for 'apply', 'destroy' and 'plan' commands
# Additional, space-separated arguments to the tofu command are provided via $(TF_ARGS) variable
define tf
	$(eval $@_CMD = $(1))
	$(eval $@_VAR_FILE = $(2))
	$(eval $@_ARGS = $(foreach arg,$(3),$(arg)))

	@cmd=("tofu" "$($@_CMD)" "-lock=true" "-input=false" "-refresh=true"); \
	if [ ! "$($@_ARGS)" = "" ]; then \
		cmd+=("$($@_ARGS)"); \
	fi; \
	`# first handle tf_converge_from option`; \
	if [ ! "$(TF_CONVERGE_FROM)" = "" ]; then \
		_tmp_cmd=("$${cmd[@]}"); \
		`# NB! need to append var-file option here instead of top-level cmd variable`; \
		`#     because we need to support applying from pre-made plan files which don't take this option`; \
		if [ -f "$($@_VAR_FILE)" ]; then \
			_tmp_cmd+=("-var-file=$($@_VAR_FILE)"); \
		fi; \
		_tmp_cmd+=("-target=$(TF_CONVERGE_FROM)"); \
		`# always apply the target resource, even when running plan`; \
		if [ "$($@_CMD)" = "plan" ]; then \
			if [ "$(__DEBUG)" == "true" ]; then \
				printf "$(__MAGENTA)Tofu converge plan: $(__BOLD)$(__SITM)$${_tmp_cmd[@]}$(__RESET)\n"; \
			fi; \
			`# first run the plan`; \
			"$${_tmp_cmd[@]}"; \
			`# then update the tofu command`; \
			for i in "$${!_tmp_cmd[@]}"; do \
				if [ "$${_tmp_cmd[$$i]}" = "plan" ]; then \
					_tmp_cmd[$$i]="apply"; \
				fi; \
			done; \
			`# and apply the changes`; \
			if [ "$(__DEBUG)" == "true" ]; then \
				printf "$(__MAGENTA)Tofu converge apply: $(__BOLD)$(__SITM)$${_tmp_cmd[@]}$(__RESET)\n"; \
			fi; \
			"$${_tmp_cmd[@]}"; \
		else \
			if [ "$(__DEBUG)" == "true" ]; then \
				printf "$(__MAGENTA)Tofu converge $($@_CMD): $(__BOLD)$(__SITM)$${_tmp_cmd[@]}$(__RESET)\n"; \
			fi; \
			"$${_tmp_cmd[@]}"; \
		fi; \
	fi; \
	`# now we run the final plan/apply/destroy command`; \
	final_cmd=("$${cmd[@]}"); \
	`# handle the tf_plan option since it's used differently for plan and apply/destroy`; \
	if [ ! "$(TF_PLAN)" = "" ]; then \
		`# produce the plan file`; \
		if [ "$($@_CMD)" = "plan" ]; then \
			`# include vars if they exist`; \
			if [ -f "$($@_VAR_FILE)" ]; then \
				final_cmd+=("-var-file=$($@_VAR_FILE)"); \
			fi; \
			final_cmd+=("-out=$(TF_PLAN)"); \
		else \
			`# NB! when running apply/destroy we don't need to provide vars because they're embedded into the plan binary file`; \
			final_cmd+=("$(TF_PLAN)"); \
		fi; \
	else \
		if [ -f "$($@_VAR_FILE)" ]; then \
			final_cmd+=("-var-file=$($@_VAR_FILE)"); \
		fi; \
	fi; \
	if [ "$(__DEBUG)" == "true" ]; then \
		printf "$(__MAGENTA)Tofu $($@_CMD): $(__BOLD)$(__SITM)$${final_cmd[@]}$(__RESET)\n"; \
	fi; \
	`# run the command`; \
	"$${final_cmd[@]}"; \
	`# clean up temporary-decrypted tfvars`; \
	if [ -f terraform.tfvars.sops ] || [ -f terraform.tfvars-$(__ENVIRONMENT).sops ]; then \
		rm -f terraform.tfvars; \
	fi
endef

help: ## Save our souls! 🛟
	@printf "$(__BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__BLUE)This Makefile contains opinionated targets that wrap tofu commands,$(__RESET)\n"; \
	printf "$(__BLUE)providing sane defaults, initialization shortcuts for tofu environment,$(__RESET)\n"; \
	printf "$(__BLUE)and support for remote tofu backends via Google Cloud Storage.$(__RESET)\n"; \
	printf "$(__BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__YELLOW)Usage:$(__RESET)\n"; \
	printf "$(__BOLD)> GCP_PROJECT=demo WORKSPACE=demo make init$(__RESET)\n"; \
	printf "$(__BOLD)> make plan$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__DIM)$(__SITM)Tip: Add a $(__BLINK)<space>$(__RESET) $(__DIM)$(__SITM)before the command if it contains sensitive information,$(__RESET)\n"; \
	printf "$(__DIM)$(__SITM)to keep it from bash history!$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__YELLOW)$(__SITM)Available commands$(__RESET) ⌨️\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n\n", $$1, $$2}'; \
	printf "\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__YELLOW)$(__SITM)Input variables for 'init'$(__RESET) 🧮\n"; \
	printf "$(__YELLOW)$(__SITM)$(__DIM)(Note: these are only used with 'init' target!)$(__RESET)\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__MAGENTA)<WORKSPACE>                    $(__MAGENTA)$(__RESET) Tofu workspace to (potentially create and) switch to\n"; \
	printf "$(__MAGENTA)<GCP_PROJECT>                  $(__BLUE)󱇶$(__RESET) GCP project name $(__SITM)(usually, but not always, the project$(__RESET)\n"; \
	printf "                               $(__SITM)that tofu changes are being applied to)$(__RESET)\n"; \
	printf "$(__MAGENTA)<GCP_PREFIX>                   $(__GREEN)󰾺$(__RESET) Prefix to use in some other GCP-related variables\n"; \
	printf "                               $(__SITM)(e.g., short company name)$(__RESET)\n"; \
	printf "$(__MAGENTA)<QUOTA_PROJECT>                $(__CYAN)$(__RESET) GCP quota project name\n"; \
	printf "                               $(__SITM)(NB! we assume quota project contains the .tfstate bucket)$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__YELLOW)$(__SITM)Input variables$(__RESET) 🧮\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__MAGENTA)<TF_ARGS>                      $(__MAGENTA)󱁢$(__RESET) Additional tofu command arguments\n"; \
	printf "                               $(__SITM)(e.g., make apply TF_ARGS='-out=foo.out -lock=false')$(__RESET)\n"; \
	printf "$(__MAGENTA)<NON_INTERACTIVE>              $(__MAGENTA)$(__RESET) Set to 'true' to disable Makefile prompts\n"; \
	printf "                               $(__SITM)(NB! This does not disable prompts coming from tofu)$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__YELLOW)$(__SITM)Dependencies$(__RESET) 📦\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__BLUE)gcloud                       $(__GREEN)https://cloud.google.com/sdk/docs/install$(__RESET)\n"; \
	printf "$(__BLUE)jq                           $(__GREEN)https://github.com/jqlang/jq?tab=readme-ov-file#installation$(__RESET)\n"; \
	printf "$(__BLUE)tofu                         $(__GREEN)https://opentofu.org/docs/intro/install/$(__RESET)\n"; \
	printf "$(__BLUE)tflint                       $(__GREEN)https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation$(__RESET)\n"; \
	printf "$(__BLUE)trivy                        $(__GREEN)https://github.com/aquasecurity/trivy?tab=readme-ov-file#get-trivy$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__SITM)$(__DIM)Optional:$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__BLUE)$(__DIM)sops                         $(__GREEN)https://github.com/getsops/sops?tab=readme-ov-file#download$(__RESET)\n"; \
	printf "$(__BLUE)$(__DIM)nerd font (for this help)    $(__GREEN)https://www.nerdfonts.com/$(__RESET)\n"; \
	printf "\n"

_set-env: _update-tfvars
	@printf "$(__BOLD)Setting environment variables...$(__RESET)\n"; \
	if [ -z $(WORKSPACE) ]; then \
		printf "$(__BOLD)$(__RED)WORKSPACE was not set$(__RESET)\n"; \
		_ERROR=1; \
	fi; \
	if [ ! -f "$(__TFVARS_PATH)" ] && [ ! -f "$(__TFVARS_PATH).sops" ]; then \
		printf "$(__BOLD)$(__RED)Could not find variables file: $(__TFVARS_PATH)$(__RESET)\n"; \
		_ERROR=1; \
	fi; \
	if [ ! -z "$${_ERROR}" ] && [ "$${_ERROR}" -eq 1 ]; then \
		`# https://stackoverflow.com/a/3267187`; \
		printf "$(__BOLD)$(__RED)Failed to set environment variables\nRun $(__DIM)$(__BLINK)make help$(__RESET) $(__BOLD)$(__RED)for usage details$(__RESET)\n"; \
		exit 1; \
	fi; \
	printf "$(__BOLD)$(__GREEN)Done setting environment variables$(__RESET)\n"; \
	printf "\n"

_check-ws: _set-env
	@if [ "$(WORKSPACE)" = "default" ] && [ ! "$(NON_INTERACTIVE)" = "true" ]; then \
		read -p "$(__BOLD)$(__MAGENTA)It is usually not desirable to use ($(WORKSPACE)) workspace. Do you want to proceed? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" != "y" ] && [ "$${ANSWER}" != "Y" ]; then \
			printf "$(__BOLD)$(__YELLOW)Exiting...$(__RESET)\n"; \
			exit 1; \
		fi; \
	fi

_update-tfvars:
	$(call tfvars,)

init: SHELL:=/bin/bash
init: _check-ws ## Hoist the sails and prepare for the voyage! 🌬️💨
	@printf "$(__BOLD)Initializing tofu...$(__RESET)\n"; \
	printf "$(__BOLD)Checking GCP project...$(__RESET)\n"; \
	_CURRENT_PROJECT=$$($(GCLOUD) config get project 2>/dev/null | tr -d '[:space:]'); \
	if [ "$(GCP_PROJECT)" != "(unset)" ] && [ ! -z "$(GCP_PROJECT)" ] && [ "$(GCP_PROJECT)" != "$${_CURRENT_PROJECT}" ]; then \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Current project $${_CURRENT_PROJECT}. Do you want to switch project? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			$(GCLOUD) config set project $(GCP_PROJECT) && \
			$(GCLOUD) auth login --update-adc ; \
			printf "$(__BOLD)$(__GREEN)Project changed to $(GCP_PROJECT)$(__RESET)\n"; \
		else \
			printf "$(__BOLD)$(__CYAN)Using project ($${_CURRENT_PROJECT})$(__RESET)\n"; \
		fi; \
	else \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Do you want to re-login and update ADC with ($${_CURRENT_PROJECT}) project? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			$(GCLOUD) auth login --update-adc ; \
		fi; \
		printf "$(__BOLD)$(__CYAN)Project is set to ($${_CURRENT_PROJECT})$(__RESET)\n"; \
	fi; \
	`# Check ADC`; \
	_CURRENT_QUOTA_PROJECT=$$(cat ~/.config/gcloud/application_default_credentials.json | jq '.quota_project_id' | tr -d '"'); \
	if [ "$(QUOTA_PROJECT)" != "$${_CURRENT_QUOTA_PROJECT}" ]; then \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Do you want to update ADC quota-project from ($${_CURRENT_QUOTA_PROJECT}) to ($(QUOTA_PROJECT))? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			$(GCLOUD) auth application-default set-quota-project $(QUOTA_PROJECT) ; \
			printf "$(__BOLD)$(__CYAN)Quota-project is set to ($(QUOTA_PROJECT))$(__RESET)\n"; \
		fi; \
	fi; \
	`# Configure GCS backend`; \
	printf "$(__BOLD)Configuring the tofu backend...$(__RESET)\n"; \
	_BUCKET_NAME=$$($(GCLOUD) storage buckets list --project $(QUOTA_PROJECT) --format='get(name)' | grep 'tfstate' | head -n1 | tr -d '[:space:]'); \
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
	printf "$(__BOLD)Using bucket ($(__DIM)$${_BUCKET_NAME}$(__RESET)) $(__BOLD)with path ($(__DIM)$${_COLOR}$${_BUCKET_PATH}$(__RESET)$(__BOLD))$(__RESET)\n"; \
	[ ! "$(NON_INTERACTIVE)" = "true" ] && \
	read -p "$(__BOLD)$(__MAGENTA)Do you want to proceed? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" != "y" ] && [ "$${ANSWER}" != "Y" ]; then \
		printf "$(__BOLD)$(__YELLOW)Exiting...$(__RESET)\n"; \
		exit 1; \
	fi; \
	printf "Selected bucket $${_BUCKET_NAME}/$${_BUCKET_PATH}\n"; \
	`# Need to switch to default workspace, since the target WORKSPACE might not exist in the selected bucket`; \
	`# (when changing between prod and non-prod state bucket sub-dirs)`; \
	_CURRENT_WORKSPACE=$$(tofu workspace show | tr -d '[:space:]') && \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" != "$${_CURRENT_WORKSPACE}" ]; then \
		printf "$(__BOLD)Temporarily switching to 'default' workspace$(__RESET)\n"; \
		tofu workspace select default; \
	fi; \
	`# initialize tofu`; \
	tofu init \
		-reconfigure \
		-input=false \
		-force-copy \
		-lock=true \
		-upgrade \
		-backend=true \
		-backend-config="bucket=$${_BUCKET_NAME}" \
		-backend-config="prefix=$${_BUCKET_PATH}"; \
	`# check/switch workspace`; \
	printf "$(__BOLD)Checking terraform workspace...$(__RESET)\n"; \
	_CURRENT_WORKSPACE=$$(terraform workspace show | tr -d '[:space:]'); \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" != "$${_CURRENT_WORKSPACE}" ]; then \
		printf "$(__BOLD)Switching to workspace ($(WORKSPACE))$(__RESET)\n"; \
		terraform workspace select -or-create $(WORKSPACE); \
	else \
		printf "$(__BOLD)$(__CYAN)Using workspace ($${_CURRENT_WORKSPACE})$(__RESET)\n"; \
	fi; \
	`# Initialize tflint`; \
	if [ -f ".tflint.hcl" ]; then \
		printf "$(__BOLD)Initializing tflint...$(__RESET)\n"; \
		tflint --init; \
	fi; \
	`# done`; \
	printf "$(__BOLD)$(__GREEN)Done initializing tofu$(__RESET)\n"; \
	printf "$(__BOLD)$(__CYAN)You can now run other commands, for example:$(__RESET)\n"; \
	printf "$(__BOLD)$(__CYAN)run $(__DIM)$(__BLINK)make plan$(__RESET) $(__BOLD)$(__CYAN)to preview what tofu thinks it will do when applying changes,$(__RESET)\n"; \
	printf "$(__BOLD)$(__CYAN)or $(__DIM)$(__BLINK)make help$(__RESET) $(__BOLD)$(__CYAN)to see all available make targets$(__RESET)\n"

format: ## Swab the deck and tidy up! 🧹
	@tofu fmt \
		-write=true \
		-recursive

# https://github.com/terraform-linters/tflint
# https://aquasecurity.github.io/trivy
validate: ## Inspect the rigging and report any issues! 🔍
	@if [ "$(__NO_VALIDATE)" = "true" ]; then \
		printf "$(__BOLD)$(__YELLOW)Skipping validation$(__RESET)\n"; \
		printf "\n"; \
	else \
		printf "$(__BOLD)Check tofu formatting...$(__RESET)\n"; \
		tofu fmt -check=true -recursive || exit 42; \
		printf "$(__BOLD)Validate tofu configuration...$(__RESET)\n"; \
		tofu validate || exit 42; \
		printf "$(__BOLD)Lint terraform files...$(__RESET)\n"; \
		if [ -f $(__TFVARS_PATH) ]; then \
			tflint --var-file "$(__TFVARS_PATH)" || exit 42; \
		else \
			tflint || exit 42; \
		fi; \
		`# https://aquasecurity.github.io/trivy/v0.53/docs/coverage/iac/terraform/`; \
		`# TIP: suppress issues via inline comments:`; \
		`# https://aquasecurity.github.io/trivy/v0.46/docs/configuration/filtering/#by-inline-comments`; \
		printf "$(__BOLD)\nScan for vulnerabilities...$(__RESET)\n"; \
		if [ -f $(__TFVARS_PATH) ]; then \
			trivy conf --skip-dirs "**/.terraform" --exit-code 42 --tf-vars "$(__TFVARS_PATH)" .; \
		else \
			trivy conf --skip-dirs "**/.terraform" --exit-code 42 .; \
		fi; \
		printf "\n"; \
	fi

test: SHELL:=/bin/bash
test: validate _check-ws ## Run some drills before we plunder! ⚔️  🏹
	@`# suppress target contents output`; \
	_GIT_STATUS=$$(git status --porcelain --untracked-files=no); \
	_GIT_CURRENT_BRANCH=$$(git rev-parse --abbrev-ref HEAD | tr -d '[:space:]'); \
	if [ -n "$${_GIT_STATUS}" ]; then \
		printf "$(__BOLD)$(__RED)Working directory has uncommitted changes. Commit or stash your changes before proceeding!$(__RESET)\n"; \
		exit 1; \
	elif [ "$${_GIT_CURRENT_BRANCH}" = "$(__GIT_DEFAULT_BRANCH)" ]; then \
		printf "$(__BOLD)$(__RED)Unable to proceed in a default git branch. Switch to another branch before proceeding$(__RESET)\n"; \
		exit 1; \
	fi; \
	_INITIAL_WORKSPACE=$$(tofu workspace show | tr -d '[:space:]'); \
	_TEMP_WORKSPACE="test-$$(uuidgen | cut -d '-' -f 1)"; \
	`# use latest changes in default, upstream branch as baseline`; \
	git pull origin $(__GIT_DEFAULT_BRANCH) && git checkout origin/$(__GIT_DEFAULT_BRANCH); \
	`# ensure vars and inputs are available for testing`; \
	cp vars/$${_INITIAL_WORKSPACE}.tfvars vars/$${_TEMP_WORKSPACE}.tfvars; \
	if [ -f "inputs/${{_INITIAL_WORKSPACE}}" ]; then cp -r inputs/$${_INITIAL_WORKSPACE} inputs/$${_TEMP_WORKSPACE}; fi; \
	`# init`; \
	make init __ENVIRONMENT="test" NON_INTERACTIVE=true WORKSPACE="$${_TEMP_WORKSPACE}"; \
	`# check if we're running in a temp workspace`; \
	_CURRENT_WORKSPACE=$$(tofu workspace show | xargs) && if [ "$${_CURRENT_WORKSPACE}" != "$${_TEMP_WORKSPACE}" ]; then \
		printf "$(__BOLD)$(__RED)Current workspace does equal ($${_TEMP_WORKSPACE})$(__RESET)\n"; \
		exit 1; \
	fi; \
	`# check backend configuration`; \
	if ! (cat .terraform/terraform.tfstate | jq '.backend.config.prefix' | grep -q '$(__BUCKET_DIR)/$(__TEST_BUCKET_SUBDIR)'); then \
		printf "$(__BOLD)$(__RED)Tofu state is configured with NON-test backend!$(__RESET)\n"; \
		exit 1; \
	fi; \
	`# apply against origin baseline`; \
	make apply NON_INTERACTIVE=true; \
	`# switch back to initial branch`; \
	git switch -; \
	`# re-initialize tofu to pull latest modules, providers, etc from the changeset under test`; \
	make init __ENVIRONMENT="test" NON_INTERACTIVE=true WORKSPACE="$${_TEMP_WORKSPACE}"; \
	`# check if we're running in a temp workspace`; \
	_CURRENT_WORKSPACE=$$(tofu workspace show | xargs) && if [ "$${_CURRENT_WORKSPACE}" != "$${_TEMP_WORKSPACE}" ]; then \
		printf "$(__BOLD)$(__RED)Current workspace does equal ($${_TEMP_WORKSPACE})$(__RESET)\n"; \
		exit 1; \
	fi; \
	`# check backend configuration`; \
	if ! (cat .terraform/terraform.tfstate | jq '.backend.config.prefix' | grep -q '$(__BUCKET_DIR)/$(__TEST_BUCKET_SUBDIR)'); then \
		printf "$(__BOLD)$(__RED)Tofu state is configured with NON-test backend!$(__RESET)\n"; \
		exit 1; \
	fi; \
	`# apply to test the changeset`; \
	make apply NON_INTERACTIVE=true; \
	printf "$(__BOLD)$(__GREEN)$(__BLINK)All tests passed!$(__RESET)\n"; \
	`# cleanup`; \
	if [ "$(NON_INTERACTIVE)" = "true" ]; then \
		make destroy; \
		tofu workspace select "$${_INITIAL_WORKSPACE}"; \
		tofu workspace delete --force "$${_TEMP_WORKSPACE}"; \
	fi; \
	[ ! "$(NON_INTERACTIVE)" = "true" ] && \
	read -p "$(__BOLD)$(__MAGENTA)Would you like to destroy the test infrastructure? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		make destroy; \
	fi; \
	[ ! "$(NON_INTERACTIVE)" = "true" ] && \
	read -p "$(__BOLD)$(__MAGENTA)Switch back to ($${_INITIAL_WORKSPACE}) workspace and delete ($${_TEMP_WORKSPACE}) workspace? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		tofu workspace select "$${_INITIAL_WORKSPACE}"; \
		tofu workspace delete --force "$${_TEMP_WORKSPACE}"; \
	fi

plan: SHELL:=/bin/bash
plan: _check-ws ## Chart the course before you sail! 🗺️
	@`# hide target content`
	$(call tf,plan,$(__TFVARS_PATH),$(TF_ARGS))

plan-destroy: _check-ws ## What would happen if we blow it all to smithereens? 💣
	@tofu plan \
		-input=false \
		-refresh=true \
		-destroy \
		-var-file="$(__TFVARS_PATH)"

apply: SHELL:=/bin/bash
apply: validate _check-ws ## Set course and full speed ahead! ⛵ This will cost you! 💰
	@`# hide target content`; \
	$(call tf,apply,$(__TFVARS_PATH),$(TF_ARGS))

destroy: SHELL:=/bin/bash
destroy: validate _check-ws ## Release the Kraken! 🐙 This can't be undone! ☠️
	@`# hide target content`; \
	$(call tf,destroy,$(__TFVARS_PATH),$(TF_ARGS))

clean: _check-ws ## Nuke local .terraform directory and tools' caches! 💥
	@printf "$(__BOLD)Cleaning up...$(__RESET)\n"; \
	_DIR="$(CURDIR)/.terraform" ; \
	[ ! "$(NON_INTERACTIVE)" = "true" ] && \
	read -p "$(__BOLD)$(__MAGENTA)Do you want to remove ($${_DIR})? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		rm -rf "$${_DIR}"; \
		printf "$(__BOLD)$(__CYAN)Removed ($${_DIR})$(__RESET)\n"; \
	fi; \
	`# clean-up trivy cache`; \
	trivy clean --all
