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
.SHELL := $(shell which bash)
.SHELLFLAGS := -ec

################################################################################################
#                                             INCLUDES

__MAKE_DIR  ?= $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

################################################################################################
#                                             COMMANDS

_TF     = tofu

# NB! include after commands are set since there are conditionals based on e.g. _GCLOUD being empty or not
# TODO: consider including right before targets? Or maybe at the very end of the makefile? Not sure what's the best practice here
include $(__MAKE_DIR)../base/tf.mk

################################################################################################
#                                             VARIABLES

### Tofu

WORKSPACE        ?=
# Additional, space-separated, tofu command options
TF_OPTS          ?=
# Additional, space-separated, tofu command arguments
TF_ARGS          ?=
# Set a resource path to apply first, before fully converging the entire configuration
# This is a shortcut to avoid calling make apply twice, i.e. 'make apply TF_ARGS='-target="some_resource.name"' && make apply'
# NB! this will apply the changes to the `some_resource.name` even when used with 'plan' target.
TF_CONVERGE_FROM ?=
# Plan file path (used with plan, apply, and destroy targets)
TF_PLAN          ?=
# Import resource address and ID
TF_RES_ADDR      ?=
TF_RES_ID        ?= 
# Encrypt state file with sops
TF_ENCRYPT_STATE  := true
# sops|tofu
TF_ENCRYPT_METHOD ?= sops

# State file paths
__TFSTATE_PATH         = terraform.tfstate.d/$(WORKSPACE)/terraform.tfstate
__TFSTATE_BACKUP_PATH  = $(__TFSTATE_PATH).backup

### Terminal

# Set to 'true' for non-interactive usage
NON_INTERACTIVE ?=
# Set to 'true' to disable some options like colors in environments where $TERM is not set
NO_TERM         ?=

################################################################################################
#                                             RULES

################################################################################################
#                                             FUNCTIONS

define tfvars
	@enc_tfvars_file=''; \
	rm -f terraform.tfvars 2>/dev/null || true; \
	touch terraform.tfvars; \
	if [ -f terraform.tfvars.sops ]; then \
		enc_tfvars_file='terraform.tfvars.sops'; \
	fi; \
	if [ -n "$${enc_tfvars_file}" ]; then \
		if ! command -v sops &> /dev/null; then \
			printf "$(__BOLD)$(__YELLOW)Warning: sops is not installed$(__RESET)\n"; \
		else \
			if [ "$(__BACKUP_TFVARS)" == "true" ] && [ -f terraform.tfvars ]; then \
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

define tfstate_encrypt
	if [ "$(TFSTATE_ENCRYPT)" = "true" ]; then \
		printf "$(__BOLD)$(__GREEN)Encrypting tfstate files$(__RESET)\n"; \
		if [ -f "$(__TFSTATE_PATH)" ] && [ $$(cat $(__TFSTATE_PATH) | jq 'has("sops")') = false ]; then \
			sops encrypt --input-type=json --output-type=json -i $(__TFSTATE_PATH); \
		else \
			printf "$(__DIM)$(__TFSTATE_PATH) already encrypted or does not exist\n$(__RESET)"
		fi; \
		if [ -f "$(__TFSTATE_BACKUP_PATH)" ] && [ $$(cat $(__TFSTATE_BACKUP_PATH) | jq 'has("sops")') = false ]; then \
			sops encrypt --input-type=json --output-type=json -i $(__TFSTATE_BACKUP_PATH); \
		else \
			printf "$(__DIM)$(__TFSTATE_BACKUP_PATH) already encrypted or does not exist\n$(__RESET)"
		fi; \
	else \
		printf "$(__BOLD)$(__YELLOW)Skipping tfstate encryption$(__RESET)\n"; \
	fi
endef

define tfstate_decrypt
	if [ "$(TFSTATE_ENCRYPT)" = "true" ]; then \
		printf "$(__BOLD)$(__GREEN)Decrypting tfstate files$(__RESET)\n"; \
		if [ -f "$(__TFSTATE_PATH)" ] && [ $$(cat $(__TFSTATE_PATH) | jq 'has("sops")') = true ]; then \
			sops decrypt --input-type=json --output-type=json -i $(__TFSTATE_PATH); \
		else \
			printf "$(__DIM)$(__TFSTATE_PATH) already decrypted or does not exist\n$(__RESET)"
		fi; \
		if [ -f "$(__TFSTATE_BACKUP_PATH)" ] && [ $$(cat $(__TFSTATE_BACKUP_PATH) | jq 'has("sops")') = true ]; then \
			sops decrypt --input-type=json --output-type=json -i $(__TFSTATE_BACKUP_PATH); \
		else \
			printf "$(__DIM)$(__TFSTATE_BACKUP_PATH) already decrypted or does not exist\n$(__RESET)"
		fi; \
	else \
		printf "$(__BOLD)$(__YELLOW)Skipping tfstate decryption$(__RESET)\n"; \
	fi
endef

define tfstate_checkout
	if [ "$(TFSTATE_ENCRYPT)" = "true" ]; then \
		git checkout terraform.tfstate.d || true; \
	fi
endef

################################################################################################
#                                             TARGETS

## NB! Empty targets for tf.mk overrides to get autocompletion to work

help:

init:

format:

validate:

plan:

apply:

destroy:

show:

state:

output:

clean:

import:

test:
