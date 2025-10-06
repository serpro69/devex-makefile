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
TF_OPTS                  ?=
# Additional, space-separated, tofu command arguments
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
# Encrypt state file
TF_ENCRYPT_STATE         ?= false
TF_ENCRYPT_METHOD        ?=
# encryption passphrase for the state file
TF_ENCRYPTION_PASS       ?=

### Environment options

__ENVIRONMENT        ?= $(shell cat .terraform/terraform.tfstate | jq -r '.backend.config.prefix // ""' | cut -d '/' -f 3)
__TFVARS_PATH         =  vars/$(WORKSPACE).tfvars
# backup terraform.tfvars before overwriting it with decrypted content
__BACKUP_TFVARS       =  false
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
	include $(__MAKE_DIR)tf-gcloud.mk
else
	include $(__MAKE_DIR)tf-local.mk
endif

# NOTE: not sure why I need to do this here, after gcloud.mk include, but otherwise it fails with:
# gmake: *** No rule to make target '/Users/sergio/Projects/test/gcloud.mk'.  Stop.
ifneq ($(wildcard $(ENVFILE)),)
	include $(ENVFILE)
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
			printf "\n" >> terraform.tfvars; \
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
			printf "\n" >> terraform.tfvars; \
		fi; \
	fi
endef

define tfstate_encrypt
	`# default definition for tf-init-local overrides`
endef

define tfstate_decrypt
	`# default definition for tf-init-local overrides`
endef

define tfstate_checkout
	`# default definition for tf-init-local overrides`
endef

# Reusable "function" for terraform|tofu commands
# Additional, space-separated options and/or arguments to the terraform|tofu command are provided via $(TF_OPTS) and $(TF_ARGS) variables
define tf
	$(eval $@_CMD = $(1))
	$(eval $@_VAR_FILE = $(2))
	$(eval $@_OPTS = $(foreach opt,$(3),$(opt)))
	$(eval $@_ARGS = $(foreach arg,$(4),$(arg)))

	@if [ "$(TF_ENCRYPT_STATE)" = "true" ] && [ "$(TF_ENCRYPT_METHOD)" = "$(_TF)" ]; then \
		_passphrase=$$(echo "$(TF_ENCRYPTION_PASS)" | xargs); \
		if [ -z "$(TF_ENCRYPTION_PASS)" ]; then \
			read -s -p "Enter encryption passphrase: " _passphrase; \
			printf "\n"; \
		fi; \
		_config=$$(printf 'key_provider "pbkdf2" "main" {\n  passphrase = "%s"\n  key_length = 32\n  salt_length = 32\n  iterations = 600000\n}' "$${_passphrase}"); \
		export TF_ENCRYPTION="$${_config}"; \
	elif [ "$(TF_ENCRYPT_STATE)" = "true" ] && [ "$(TF_ENCRYPT_METHOD)" = "sops" ]; then \
		$(call tfstate_decrypt,); \
	fi; \
	case "$($@_CMD)" in \
		apply|destroy|import|plan) \
			cmd=("$(_TF)" "$($@_CMD)" "-lock=true" "-input=false"); \
			if [ "$($@_CMD)" != "import" ]; then \
				cmd+=("-refresh=true"); \
			fi; \
			if [ ! "$($@_OPTS)" = "" ]; then \
				cmd+=($($@_OPTS)); \
			fi; \
			if [ ! "$($@_ARGS)" = "" ]; then \
				cmd+=($($@_ARGS)); \
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
				final_cmd+=($(TF_RES_ADDR)); \
				final_cmd+=($(TF_RES_ID)); \
			else \
				if [ -f "$($@_VAR_FILE)" ]; then \
					final_cmd+=("-var-file=$($@_VAR_FILE)"); \
				fi; \
			fi; \
			if [ "$(__DEBUG)" == "true" ]; then \
				printf "\n$(__MAGENTA)Encryption config $($@_CMD):\n$(__BOLD)$(__SITM)%s$(__RESET)\n" "$${TF_ENCRYPTION}"; \
				printf "\n$(__MAGENTA)$(_TF) $($@_CMD): $(__BOLD)$(__SITM)%s$(__RESET)\n" "$${final_cmd[*]}"; \
				exit 0; \
			fi; \
			"$${final_cmd[@]}"; \
			`# clean up temporary-decrypted tfvars`; \
			if [ -f terraform.tfvars.sops ] || [ -f terraform.tfvars-$(__ENVIRONMENT).sops ]; then \
				rm -f terraform.tfvars; \
			fi; \
			`# no need to re-encrypt on 'plan' since it does not change the state`; \
			if [ "$($@_CMD)" = "plan" ]; then \
				$(call tfstate_checkout,); \
			else \
				$(call tfstate_encrypt,); \
			fi
			;; \
		show|state|output) \
			cmd=("$(_TF)" "$($@_CMD)"); \
			if [ ! "$($@_OPTS)" = "" ]; then \
				cmd+=($($@_OPTS)); \
			fi; \
			if [ ! "$($@_ARGS)" = "" ]; then \
				cmd+=($($@_ARGS)); \
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
			`# no need to re-encrypt on 'plan' since it does not change the state`; \
			$(call tfstate_checkout,); \
			;; \
	esac
endef

################################################################################################
#                                             TARGETS

help: SHELL:=$(shell which bash)
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
	$(MAKE) --quiet _help_init; \
	printf "\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "$(__YELLOW)$(__SITM)Input variables$(__RESET) 🧮\n"; \
	printf "$(__YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__MAGENTA)<TF_OPTS>                      $(__TF_ICON) Additional $(_TF) command options\n"; \
	printf "                               $(__SITM)(e.g., make apply TF_OPTS='-out=foo.out -lock=false')$(__RESET)\n"; \
	printf "$(__MAGENTA)<TF_ARGS>                      $(__TF_ICON) Additional $(_TF) command arguments\n"; \
	printf "                               $(__SITM)(e.g., make output TF_OPTS='-raw' TF_ARGS='project_id')$(__RESET)\n"; \
	printf "$(__MAGENTA)<TF_CONVERGE_FROM>             $(__TF_ICON) Resource path to apply first\n"; \
	printf "                               $(__SITM)(before fully converging the entire configuration)$(__RESET)\n"; \
	printf "$(__MAGENTA)<TF_PLAN>                      $(__TF_ICON) $(_TF) plan file path\n"; \
	printf "                               $(__SITM)(used with 'plan', 'apply', 'destroy' and 'show' targets)$(__RESET)\n"; \
	printf "$(__MAGENTA)<TF_RES_ADDR>                  $(__TF_ICON) Resource ADDR for $(_TF) state/import commands\n"; \
	printf "$(__MAGENTA)<TF_RES_ID>                    $(__TF_ICON) Resource ID for $(_TF) import command\n"; \
	printf "$(__MAGENTA)<TF_ENCRYPT_STATE>             $(__TF_ICON) Set to 'true' to encrypt the state file\n"; \
	printf "$(__MAGENTA)<TF_ENCRYPT_METHOD>            $(__TF_ICON) Method to use for state encryption\n"; \
	if [ ! -z $(_GCLOUD) ] && [ "$(_TF)" == "tofu" ]; then \
		printf "                               $(__SITM)(Read more about tofu state encryption:$(__RESET)\n"; \
		printf "                               $(__SITM)  https://opentofu.org/docs/language/state/encryption/)$(__RESET)\n"; \
		printf "                               $(__SITM)Values: (tofu|sops)$(__RESET)\n"; \
		printf "                               $(__SITM)Default: tofu$(__RESET)\n"; \
		printf "$(__MAGENTA)<TF_ENCRYPTION_PASS>           $(__TF_ICON) Passphrase for tofu-based encryption method\n"; \
	else \
		printf "                               $(__SITM)Values: (sops)$(__RESET)\n"; \
		printf "                               $(__SITM)Default: sops$(__RESET)\n"; \
	fi; \
	printf "\n"; \
	printf "$(__MAGENTA)<ENVFILE>                      $(__YELLOW)$(__RESET) Path to an env file with these input variables\n"; \
	printf "                               $(__SITM)(use to set some or all input variables for this makefile)$(__RESET)\n"; \
	printf "                               $(__SITM)Default: ./.env$(__RESET)\n"; \
	printf "\n"; \
	printf "$(__MAGENTA)<NON_INTERACTIVE>              $(__MAGENTA)$(__RESET) Set to 'true' to disable Makefile prompts\n"; \
	printf "                               $(__SITM)(Default: false)$(__RESET)\n"; \
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
	if [ -z $(_GCLOUD) ]; then \
		printf "$(__BLUE)$(__DIM)sops                         $(__GREEN)https://github.com/getsops/sops?tab=readme-ov-file#download$(__RESET)\n"; \
	fi; \
	printf "$(__BLUE)$(__DIM)nerd font                    $(__GREEN)https://www.nerdfonts.com/$(__RESET)\n"; \
	printf "$(__BLUE)$(__DIM)$(__SITM)(for outputs and this help)$(__RESET)\n"; \
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

.PHONY: _init-gcp-config _init-gcp-project _init-adc
_init-gcp-config:
_init-gcp-project:
_init-adc:

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
init: _check-ws _init-gcp-config _init-gcp-project _init-adc _init _init-tf-ws _init-tflint ## Hoist the sails and prepare for the voyage! 🌬️💨
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
test: validate _check-ws _test ## Run some drills before we plunder! ⚔️  🏹

plan: SHELL:=/bin/bash
plan: _check-ws ## Chart the course before you sail! 🗺️
	@$(call tf,plan,$(__TFVARS_PATH),$(TF_OPTS),$(TF_ARGS))

apply: SHELL:=/bin/bash
apply: validate _check-ws ## Set course and full speed ahead! ⛵ This will cost you! 💰
	@$(call tf,apply,$(__TFVARS_PATH),$(TF_OPTS),$(TF_ARGS))

destroy: SHELL:=/bin/bash
destroy: validate _check-ws ## Release the Kraken! 🐙 This can't be undone! ☠️
	@$(call tf,destroy,$(__TFVARS_PATH),$(TF_OPTS),$(TF_ARGS))

show: SHELL:=/bin/bash
show: _check-ws ## Show the current state of the world! 🌍
	@$(call tf,show,$(__TFVARS_PATH),$(TF_OPTS),$(TF_ARGS))

state: SHELL:=/bin/bash
state: _check-ws ## Make the world dance to your tunes! 🎻
	@$(call tf,state,$(__TFVARS_PATH),$(TF_OPTS),$(TF_ARGS))

output: SHELL:=/bin/bash
output: _check-ws ## Explore the outcomes of the trip! 💰
	@$(call tf,output,$(__TFVARS_PATH),$(TF_OPTS),$(TF_ARGS))

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
	@printf "$(__BOLD)Importing resource state...$(__RESET)\n\n"; \
	$(call tf,import,$(__TFVARS_PATH),$(TF_OPTS),); \
	printf "\n$(__BOLD)$(__GREEN)Done importing resource$(__RESET)\n"; \
