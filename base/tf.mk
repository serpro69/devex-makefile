# Copyright 2024-present serpro69
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

################################################################################################
#                                      NOTE TO DEVELOPERS
#
# While editing this file, please respect the following:
#
# 1. Various variables, rules, functions, etc should be defined in their corresponding section,
#    with variables also separated into relevant subsections
# 2. "Hidden" make variables should start with two underscores `__`
# 3. All shell variables defined in a given target should start with a single underscore `_`
#    to avoid name conflicts with any other variables
# 4. Every new target should be defined in the Targets section
#
################################################################################################

.ONESHELL:
.PHONY: apply clean destroy format help init plan show state test validate import

.SHELL      := $(shell which bash)
.SHELLFLAGS := -ec

__MAKE_DIR  ?= $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

include $(__MAKE_DIR)base.mk

################################################################################################
#                                             COMMANDS

_TF 	  ?=

################################################################################################
#                                             VARIABLES

### Terraform|Tofu

WORKSPACE                ?= $(shell $(_TF) workspace show | tr -d '[:space:]')
# Additional, space-separated, tofu command options
TF_ARGS                  ?=
# Set a resource path to apply first, before fully converging the entire configuration
# This is a shortcut to avoid calling make apply twice, i.e. 'make apply TF_ARGS='-target="some_resource.name"' && make apply'
# NB! this will apply the changes to the `some_resource.name` even when used with 'plan' target.
TF_CONVERGE_FROM         ?=
# Plan file path (used with plan, apply, and destroy targets)
TF_PLAN                  ?=
# Resource address for 'state' and 'import' targets
TF_RES_ADDR              ?=
# Import resource ID
TF_RES_ID                ?=
TF_ENCRYPT_STATE         ?= false
# encryption passphrase for the state file
TF_ENCRYPTION_PASSPHRASE ?=

### Environment options

__ENVIRONMENT        ?= $(shell cat .terraform/terraform.tfstate | jq -r '.backend.config.prefix // ""' | cut -d '/' -f 3)
__BUCKET_DIR          =  terraform/state
__PROD_BUCKET_SUBDIR  =  prod
__TEST_BUCKET_SUBDIR  =  test
__TFVARS_PATH         =  vars/$(WORKSPACE).tfvars
# backup terraform.tfvars before overwriting it with decrypted content
__BACKUP_TFVARS       =  false
__GIT_DEFAULT_BRANCH  =  main
__DEBUG              ?=

### Misc

__TF_ICON       = $(__YELLOW)$(__RESET)

################################################################################################
#                                             RULES

# Check for necessary tools
ifneq ($(filter help,$(MAKECMDGOALS)),)
	# Skip checks for help target
else
	ifeq ($(shell which jq),)
	  $(error "No jq in $(PATH), please install jq: https://github.com/jqlang/jq?tab=readme-ov-file#installation")
	else ifeq ($(_TF),tofu)
		ifeq ($(shell which tofu),)
	  	$(error "No tofu in $(PATH), get it from https://opentofu.org/docs/intro/install")
		endif
	else ifeq ($(_TF),terraform)
		ifeq ($(shell which terraform),)
	  	$(error "No terraform in $(PATH), get it from https://www.terraform.io/downloads.html")
		endif
	else ifeq ($(shell which tflint),)
	  $(error "No tflint in $(PATH), get it from https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation")
	else ifeq ($(shell which trivy),)
	  $(error "No trivy in $(PATH), get it from https://github.com/aquasecurity/trivy?tab=readme-ov-file#get-trivy")
	endif
endif

ifeq ($(_TF),terraform)
	__TF_ICON = $(__MAGENTA)󱁢$(__RESET)
endif

ifneq ($(_GCLOUD),)
	include $(__MAKE_DIR)gcloud.mk
endif

################################################################################################
#                                             FUNCTIONS

# decrypt terraform.$(__ENVIRONMENT).tfvars file if it's encrypted
# comment out the variables based on a workspace otherwise
define tfvars
	@enc_tfvars_file=''; \
	if [ -f terraform.tfvars.sops ]; then \
		enc_tfvars_file='terraform.tfvars.sops'; \
	elif [ -f "terraform.tfvars-$(__ENVIRONMENT).sops" ]; then \
		enc_tfvars_file="terraform.tfvars-$(__ENVIRONMENT).sops"; \
	fi; \
	if [ -n "$${enc_tfvars_file}" ]; then \
		if ! command -v sops &> /dev/null; then \
			printf "$(__BOLD)$(__YELLOW)Warning: sops is not installed$(__RESET)\n"; \
		else \
			if [ "$(__BACKUP_TFVARS)" == "true" ] && [ -f terraform.tfvars ]; then \
				cp terraform.tfvars{,.bak.$$(date +%s%N)}; \
			fi; \
			sops decrypt "$${enc_tfvars_file}" > terraform.tfvars; \
			printf "" >> terraform.tfvars; \
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
			printf "" >> terraform.tfvars; \
		fi; \
	fi
endef

# Reusable "function" for 'apply', 'destroy' and 'plan' commands
# Additional, space-separated arguments to the terraform|tofu command are provided via $(TF_ARGS) variable
define tf
	$(eval $@_CMD = $(1))
	$(eval $@_VAR_FILE = $(2))
	$(eval $@_ARGS = $(foreach arg,$(3),$(arg)))

	@if [ "$(TF_ENCRYPT_STATE)" = "true" ]; then \
		_passphrase=$$(echo "$(TF_ENCRYPTION_PASSPHRASE)" | xargs); \
		if [ -z "$(TF_ENCRYPTION_PASSPHRASE)" ]; then \
			read -s -p "Enter encryption passphrase: " _passphrase; \
			printf "\n"; \
		fi; \
		_config=$$(printf 'key_provider "pbkdf2" "main" {\n  passphrase = "%s"\n  key_length = 32\n  salt_length = 32\n  iterations = 600000\n}' "$${_passphrase}"); \
		export TF_ENCRYPTION="$${_config}"; \
	fi; \
	case "$($@_CMD)" in \
		apply|destroy|import|plan) \
			cmd=("$(_TF)" "$($@_CMD)" "-lock=true" "-input=false"); \
			if [ "$($@_CMD)" != "import" ]; then \
				cmd+=("-refresh=true"); \
			fi; \
			if [ ! "$($@_ARGS)" = "" ]; then \
				cmd+=("$($@_ARGS)"); \
			fi; \
			if [ ! "$(TF_CONVERGE_FROM)" = "" ]; then \
				_tmp_cmd=("$${cmd[@]}"); \
				if [ -f "$($@_VAR_FILE)" ]; then \
					_tmp_cmd+=("-var-file=$($@_VAR_FILE)"); \
				fi; \
				_tmp_cmd+=("-target=$(TF_CONVERGE_FROM)"); \
				if [ "$($@_CMD)" = "plan" ]; then \
					if [ "$(__DEBUG)" == "true" ]; then \
						printf "$(__MAGENTA)$(_TF) converge plan: $(__BOLD)$(__SITM)$${_tmp_cmd[@]}$(__RESET)\n"; \
					fi; \
					"$${_tmp_cmd[@]}"; \
					for i in "$${!_tmp_cmd[@]}"; do \
						if [ "$${_tmp_cmd[$$i]}" = "plan" ]; then \
							_tmp_cmd[$$i]="apply"; \
						fi; \
					done; \
					if [ "$(__DEBUG)" == "true" ]; then \
						printf "$(__MAGENTA)$(_TF) converge apply: $(__BOLD)$(__SITM)$${_tmp_cmd[@]}$(__RESET)\n"; \
					fi; \
					"$${_tmp_cmd[@]}"; \
				else \
					if [ "$(__DEBUG)" == "true" ]; then \
						printf "$(__MAGENTA)$(_TF) converge $($@_CMD): $(__BOLD)$(__SITM)$${_tmp_cmd[@]}$(__RESET)\n"; \
					fi; \
					"$${_tmp_cmd[@]}"; \
				fi; \
			fi; \
			final_cmd=("$${cmd[@]}"); \
			if [ ! "$(TF_PLAN)" = "" ]; then \
				if [ "$($@_CMD)" = "plan" ]; then \
					if [ -f "$($@_VAR_FILE)" ]; then \
						final_cmd+=("-var-file=$($@_VAR_FILE)"); \
					fi; \
					final_cmd+=("-out=$(TF_PLAN)"); \
				else \
					final_cmd+=("$(TF_PLAN)"); \
				fi; \
			elif [ "$($@_CMD)" = "import" ]; then \
				if [ -z '$(TF_RES_ADDR)' ] || [ -z '$(TF_RES_ID)' ]; then \
					printf "$(__BOLD)$(__RED)TF_RES_ADDR and TF_RES_ID must be set$(__RESET)\n\n"; \
					"$(_TF)" import --help; \
					printf "\n"; \
					exit 1; \
				fi; \
				if [ -f "$($@_VAR_FILE)" ]; then \
					final_cmd+=("-var-file=$($@_VAR_FILE)"); \
				fi; \
				final_cmd+=("$(TF_RES_ADDR)"); \
				final_cmd+=("$(TF_RES_ID)"); \
			else \
				if [ -f "$($@_VAR_FILE)" ]; then \
					final_cmd+=("-var-file=$($@_VAR_FILE)"); \
				fi; \
			fi; \
			if [ "$(__DEBUG)" == "true" ]; then \
				printf "\n$(__MAGENTA)Encryption config $($@_CMD):\n$(__BOLD)$(__SITM)%s$(__RESET)\n" "$${TF_ENCRYPTION}"; \
				printf "\n$(__MAGENTA)$(_TF) $($@_CMD): $(__BOLD)$(__SITM)%s$(__RESET)\n" "$${cmd[*]}"; \
				exit 0; \
			fi; \
			"$${final_cmd[@]}"; \
			if [ -f terraform.tfvars.sops ] || [ -f terraform.tfvars-$(__ENVIRONMENT).sops ]; then \
				rm -f terraform.tfvars; \
			fi; \
			;; \
		show|state|output) \
			cmd=("$(_TF)" "$($@_CMD)"); \
			if [ ! "$($@_ARGS)" = "" ]; then \
				cmd+=("$($@_ARGS)"); \
			fi; \
			if [ "$($@_CMD)" = "state" ]; then \
				if [ ! "$(TF_RES_ADDR)" = "" ]; then \
					cmd+=("show" "$(TF_RES_ADDR)"); \
				elif [ -z "$($@_ARGS)" ]; then \
					cmd+=("list"); \
				fi; \
			elif [ "$($@_CMD)" = "show" ]; then \
				if [ ! "$(TF_PLAN)" = "" ]; then \
					cmd+=("-plan" "$(TF_PLAN)"); \
				else \
					cmd+=("-state"); \
				fi; \
			fi; \
			if [ "$(__DEBUG)" == "true" ]; then \
				printf "\n$(__MAGENTA)Encryption config $($@_CMD):\n$(__BOLD)$(__SITM)%s$(__RESET)\n" "$${TF_ENCRYPTION}"; \
				printf "\n$(__MAGENTA)$(_TF) $($@_CMD): $(__BOLD)$(__SITM)%s$(__RESET)\n" "$${cmd[*]}"; \
				exit 0; \
			fi; \
			"$${cmd[@]}"; \
			;; \
	esac
endef

################################################################################################
#                                             TARGETS

help: ## Save our souls! 🛟
	@printf "$(__BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__BLUE)This Makefile contains opinionated targets that wrap $(_TF) commands,$(__RESET)\n"; \
	printf "$(__BLUE)providing sane defaults, initialization shortcuts for $(_TF) environment,$(__RESET)\n"; \
	printf "$(__BLUE)and support for remote $(_TF) backends via Google Cloud Storage.$(__RESET)\n"; \
	printf "$(__BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__YELLOW)Usage:$(__RESET)\n"; \
	printf "$(__BOLD)> GCP_PROJECT=demo WORKSPACE=demo make init$(__RESET)\n"; \
	printf "$(__BOLD)> make plan$(__RESET)\n"; \
	printf "\n"; \
	`# TODO: make a list of fun and simple bash/make tips in a separate file -> print a random one -> profit`; \
	printf "$(__DIM)$(__SITM)Tip: Add a $(__BLINK)<space>$(__RESET) $(__DIM)$(__SITM)before the command if it contains sensitive information,$(__RESET)\n"; \
	printf "$(__DIM)$(__SITM)to keep it from bash history!$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__YELLOW)$(__SITM)Available commands$(__RESET) ⌨️\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	mklist="$(MAKEFILE_LIST)"; \
	mkarr=($$mklist); \
	for mkfile in "$${mkarr[@]}"; do \
	  grep -E '^[a-zA-Z_-]+:.*?## .*$$' "$$mkfile" | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n\n", $$1, $$2}'; \
	done; \
	printf "\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__YELLOW)$(__SITM)Input variables for 'init'$(__RESET) 🧮\n"; \
	printf "$(__YELLOW)$(__SITM)$(__DIM)(Note: these are only used with 'init' target!)$(__RESET)\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__MAGENTA)<WORKSPACE>                    $(__TF_ICON) $(_TF) workspace to (potentially create and) switch to\n"; \
	printf "$(__MAGENTA)<GCP_PROJECT>                  $(__BLUE)󱇶$(__RESET) GCP project name $(__SITM)(usually, but not always, the project$(__RESET)\n"; \
	printf "                               $(__SITM)that $(_TF) changes are being applied to)$(__RESET)\n"; \
	printf "$(__MAGENTA)<GCP_PREFIX>                   $(__GREEN)󰾺$(__RESET) Prefix to use in some other GCP-related variables\n"; \
	printf "                               $(__SITM)(e.g., short company name)$(__RESET)\n"; \
	printf "$(__MAGENTA)<QUOTA_PROJECT>                $(__CYAN)$(__RESET) GCP quota project name\n"; \
	printf "                               $(__SITM)(NB! we assume quota project contains the .tfstate bucket)$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__YELLOW)$(__SITM)Input variables$(__RESET) 🧮\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__MAGENTA)<TF_ARGS>                      $(__TF_ICON) Additional $(_TF) command arguments\n"; \
	printf "                               $(__SITM)(e.g., make apply TF_ARGS='-out=foo.out -lock=false')$(__RESET)\n"; \
	printf "$(__MAGENTA)<TF_CONVERGE_FROM>             $(__TF_ICON) Resource path to apply first\n"; \
	printf "                               $(__SITM)(before fully converging the entire configuration)$(__RESET)\n"; \
	printf "$(__MAGENTA)<TF_PLAN>                      $(__TF_ICON) $(_TF) plan file path\n"; \
	printf "                               $(__SITM)(used with 'plan', 'apply', 'destroy' and 'show' targets)$(__RESET)\n"; \
	printf "$(__MAGENTA)<TF_RES_ADDR>                  $(__TF_ICON) Resource ADDR for $(_TF) state/import commands\n"; \
	printf "$(__MAGENTA)<TF_RES_ID>                    $(__TF_ICON) Resource ID for $(_TF) import command\n"; \
	printf "$(__MAGENTA)<NON_INTERACTIVE>              $(__MAGENTA)$(__RESET) Set to 'true' to disable Makefile prompts\n"; \
	printf "                               $(__SITM)(NB! This does not disable prompts coming from $(_TF))$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__YELLOW)$(__SITM)Dependencies$(__RESET) 📦\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	if [ ! -z $(_GCLOUD) ]; then \
	  printf "$(__BLUE)gcloud                       $(__GREEN)https://cloud.google.com/sdk/docs/install$(__RESET)\n"; \
	fi; \
	printf "$(__BLUE)jq                           $(__GREEN)https://github.com/jqlang/jq?tab=readme-ov-file#installation$(__RESET)\n"; \
	if [ "$(_TF)" = "tofu" ]; then \
	  printf "$(__BLUE)tofu                         $(__GREEN)https://opentofu.org/docs/intro/install/$(__RESET)\n"; \
	else \
	  printf "$(__BLUE)terraform                    $(__GREEN)https://www.terraform.io/downloads.html$(__RESET)\n"; \
	fi; \
	printf "$(__BLUE)tflint                       $(__GREEN)https://github.com/terraform-linters/tflint?tab=readme-ov-file#installation$(__RESET)\n"; \
	printf "$(__BLUE)trivy                        $(__GREEN)https://github.com/aquasecurity/trivy?tab=readme-ov-file#get-trivy$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__SITM)$(__DIM)Optional:$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__BLUE)$(__DIM)sops                         $(__GREEN)https://github.com/getsops/sops?tab=readme-ov-file#download$(__RESET)\n"; \
	printf "$(__BLUE)$(__DIM)nerd font (for this help)    $(__GREEN)https://www.nerdfonts.com/$(__RESET)\n"; \
	printf "\n"

.PHONY: _set-env
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

.PHONY: _check-ws
_check-ws: _set-env
	@if [ "$(WORKSPACE)" = "default" ] && [ ! "$(NON_INTERACTIVE)" = "true" ]; then \
		read -p "$(__BOLD)$(__MAGENTA)It is usually not desirable to use ($(WORKSPACE)) workspace. Do you want to proceed? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" != "y" ] && [ "$${ANSWER}" != "Y" ]; then \
			printf "$(__BOLD)$(__YELLOW)Exiting...$(__RESET)\n"; \
			exit 1; \
		fi; \
	fi

.PHONY: _update-tfvars
_update-tfvars:
	$(call tfvars,)

.PHONY: _init-gcp-config
_init-gcp-config:

.PHONY: _init-gcp-project
_init-gcp-project:

.PHONY: _init-adc
_init-adc:

.PHONY: _init-gcs-backend
_init-gcs-backend:

_init-tf-ws:
	@`# check/switch workspace`; \
	printf "$(__BOLD)Checking $(_TF) workspace...$(__RESET)\n"; \
	_CURRENT_WORKSPACE=$$($(_TF) workspace show | tr -d '[:space:]'); \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" != "$${_CURRENT_WORKSPACE}" ]; then \
		printf "$(__BOLD)Switching to workspace ($(WORKSPACE))$(__RESET)\n"; \
		$(_TF) workspace select -or-create $(WORKSPACE); \
	else \
		printf "$(__BOLD)$(__CYAN)Using workspace ($${_CURRENT_WORKSPACE})$(__RESET)\n"; \
	fi

_init-tflint:
	@`# Initialize tflint`; \
	if [ -f ".tflint.hcl" ]; then \
		printf "$(__BOLD)Initializing tflint...$(__RESET)\n"; \
		tflint --init; \
	fi

init: SHELL:=$(shell which bash)
init: _check-ws _init-gcp-config _init-gcp-project _init-adc _init-gcs-backend _init-tf-ws _init-tflint ## Hoist the sails and prepare for the voyage! 🌬️💨
	@printf "$(__BOLD)$(__GREEN)Done initializing $(_TF)$(__RESET)\n"; \
	printf "$(__BOLD)$(__CYAN)You can now run other commands, for example:$(__RESET)\n"; \
	printf "$(__BOLD)$(__CYAN)run $(__DIM)$(__BLINK)make plan$(__RESET) $(__BOLD)$(__CYAN)to preview what $(_TF) thinks it will do when applying changes,$(__RESET)\n"; \
	printf "$(__BOLD)$(__CYAN)or $(__DIM)$(__BLINK)make help$(__RESET) $(__BOLD)$(__CYAN)to see all available make targets$(__RESET)\n"

format: ## Swab the deck and tidy up! 🧹
	@$(_TF) fmt \
		-write=true \
		-recursive

# https://github.com/terraform-linters/tflint
# https://aquasecurity.github.io/trivy
validate: ## Inspect the rigging and report any issues! 🔍
	@if [ "$(__NO_VALIDATE)" = "true" ]; then \
		printf "$(__BOLD)$(__YELLOW)Skipping validation$(__RESET)\n"; \
		printf "\n"; \
	else \
		printf "$(__BOLD)Check $(_TF) formatting...$(__RESET)\n"; \
		$(_TF) fmt -check=true -recursive || exit 42; \
		printf "$(__BOLD)Validate $(_TF) configuration...$(__RESET)\n"; \
		$(_TF) validate || exit 42; \
		printf "$(__BOLD)Lint terraform files...$(__RESET)\n"; \
		_tf_vars_file="$(__TFVARS_PATH)"; \
		if [ ! -f "$${_tf_vars_file}" ] && [ -f terraform.tfvars.sops ]; then \
			_tf_vars_file=terraform.tfvars; \
		fi; \
		if [ -f "$${_tf_vars_file}" ]; then \
			tflint --var-file "$${_tf_vars_file}" || exit 42; \
		else \
			tflint || exit 42; \
		fi; \
		`# https://aquasecurity.github.io/trivy/v0.53/docs/coverage/iac/terraform/`; \
		`# TIP: suppress issues via inline comments:`; \
		`# https://aquasecurity.github.io/trivy/v0.46/docs/configuration/filtering/#by-inline-comments`; \
		printf "$(__BOLD)\nScan for vulnerabilities...$(__RESET)\n"; \
		if [ -f "$${_tf_vars_file}" ]; then \
			trivy conf --skip-dirs "**/.terraform" --exit-code 42 --tf-vars "$${_tf_vars_file}" .; \
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
	_INITIAL_WORKSPACE=$$($(_TF) workspace show | tr -d '[:space:]'); \
	_TEMP_WORKSPACE="test-$$(uuidgen | cut -d '-' -f 1)"; \
	`# use latest changes in default, upstream branch as baseline`; \
	git pull origin $(__GIT_DEFAULT_BRANCH) && git checkout origin/$(__GIT_DEFAULT_BRANCH); \
	`# ensure vars and inputs are available for testing`; \
	_initial_vars_file_path="vars/$${_INITIAL_WORKSPACE}.tfvars"; \
	[ -f "$${_initial_vars_file_path}" ] && cp "$${_initial_vars_file_path}" "vars/$${_TEMP_WORKSPACE}.tfvars"; \
	[ -f "$${_initial_vars_file_path}.sops" ] && cp "$${_initial_vars_file_path}.sops" "vars/$${_TEMP_WORKSPACE}.tfvars.sops"; \
	[ -f "inputs/${_INITIAL_WORKSPACE}" ] && cp -r "inputs/$${_INITIAL_WORKSPACE}" "inputs/$${_TEMP_WORKSPACE}"; fi; \
	`# init`; \
	$(MAKE) init __ENVIRONMENT="test" NON_INTERACTIVE=true WORKSPACE="$${_TEMP_WORKSPACE}"; \
	`# check if we're running in a temp workspace`; \
	_CURRENT_WORKSPACE=$$($(_TF) workspace show | xargs) && if [ "$${_CURRENT_WORKSPACE}" != "$${_TEMP_WORKSPACE}" ]; then \
		printf "$(__BOLD)$(__RED)Current workspace does equal ($${_TEMP_WORKSPACE})$(__RESET)\n"; \
		exit 1; \
	fi; \
	`# check backend configuration`; \
	if ! (cat .terraform/terraform.tfstate | jq '.backend.config.prefix' | grep -q '$(__BUCKET_DIR)/$(__TEST_BUCKET_SUBDIR)'); then \
		printf "$(__BOLD)$(__RED)$(_TF) state is configured with NON-test backend!$(__RESET)\n"; \
		exit 1; \
	fi; \
	`# apply against origin baseline`; \
	$(MAKE) apply NON_INTERACTIVE=true; \
	`# switch back to initial branch`; \
	git switch -; \
	`# re-initialize $(_TF) to pull latest modules, providers, etc from the changeset under test`; \
	$(MAKE) init __ENVIRONMENT="test" NON_INTERACTIVE=true WORKSPACE="$${_TEMP_WORKSPACE}"; \
	`# check if we're running in a temp workspace`; \
	_CURRENT_WORKSPACE=$$($(_TF) workspace show | xargs) && if [ "$${_CURRENT_WORKSPACE}" != "$${_TEMP_WORKSPACE}" ]; then \
		printf "$(__BOLD)$(__RED)Current workspace does equal ($${_TEMP_WORKSPACE})$(__RESET)\n"; \
		exit 1; \
	fi; \
	`# check backend configuration`; \
	if ! (cat .terraform/terraform.tfstate | jq '.backend.config.prefix' | grep -q '$(__BUCKET_DIR)/$(__TEST_BUCKET_SUBDIR)'); then \
		printf "$(__BOLD)$(__RED)$(_TF) state is configured with NON-test backend!$(__RESET)\n"; \
		exit 1; \
	fi; \
	`# apply to test the changeset`; \
	$(MAKE) apply NON_INTERACTIVE=true; \
	printf "$(__BOLD)$(__GREEN)$(__BLINK)All tests passed!$(__RESET)\n"; \
	`# cleanup`; \
	if [ "$(NON_INTERACTIVE)" = "true" ]; then \
		$(MAKE) destroy; \
		$(_TF) workspace select "$${_INITIAL_WORKSPACE}"; \
		$(_TF) workspace delete --force "$${_TEMP_WORKSPACE}"; \
	fi; \
	[ ! "$(NON_INTERACTIVE)" = "true" ] && \
	read -p "$(__BOLD)$(__MAGENTA)Would you like to destroy the test infrastructure? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		$(MAKE) destroy; \
	fi; \
	[ ! "$(NON_INTERACTIVE)" = "true" ] && \
	read -p "$(__BOLD)$(__MAGENTA)Switch back to ($${_INITIAL_WORKSPACE}) workspace and delete ($${_TEMP_WORKSPACE}) workspace? [y/Y]: $(__RESET)" ANSWER && \
	if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
		$(_TF) workspace select "$${_INITIAL_WORKSPACE}"; \
		$(_TF) workspace delete --force "$${_TEMP_WORKSPACE}"; \
	fi

plan: SHELL:=/bin/bash
plan: _check-ws ## Chart the course before you sail! 🗺️
	@$(call tf,plan,$(__TFVARS_PATH),$(TF_ARGS))

apply: SHELL:=/bin/bash
apply: validate _check-ws ## Set course and full speed ahead! ⛵ This will cost you! 💰
	@$(call tf,apply,$(__TFVARS_PATH),$(TF_ARGS))

destroy: SHELL:=/bin/bash
destroy: validate _check-ws ## Release the Kraken! 🐙 This can't be undone! ☠️
	@$(call tf,destroy,$(__TFVARS_PATH),$(TF_ARGS))

show: SHELL:=/bin/bash
show: _check-ws ## Show the current state of the world! 🌍
	@$(call tf,show,$(__TFVARS_PATH),$(TF_ARGS))

state: SHELL:=/bin/bash
state: _check-ws ## Make the world dance to your tunes! 🎻
	@$(call tf,state,$(__TFVARS_PATH),$(TF_ARGS))

output: SHELL:=/bin/bash
output: _check-ws ## Explore the outcomes of the trip! 💰
	@$(call tf,output,$(__TFVARS_PATH),$(TF_ARGS))

clean: SHELL:=/bin/bash
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

import: SHELL:=/bin/bash
import: _check-ws ## Import state 📦
	@`# hide target content`; \
	printf "$(__BOLD)Importing resource state...$(__RESET)\n\n"; \
	$(call tf,import,$(__TFVARS_PATH),$(TF_ARGS)); \
	printf "\n$(__BOLD)$(__GREEN)Done importing resource$(__RESET)\n"
