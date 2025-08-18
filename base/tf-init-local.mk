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
.PHONY: _init

.SHELL      := $(shell which bash)
.SHELLFLAGS := -ec

__MAKE_DIR  ?= $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

################################################################################################
#                                             COMMANDS

################################################################################################
#                                             VARIABLES

### Terraform|Tofu

# Encrypt state file
TF_ENCRYPT_STATE ?= true

################################################################################################
#                                             RULES

# Check for necessary tools
ifneq ($(filter help,$(MAKECMDGOALS)),)
  # Skip checks for help target
else
	ifeq ($(TF_ENCRYPT_STATE),true)
		ifeq ($(shell which sops),)
			$(error "No sops in $(PATH), get it from https://github.com/getsops/sops?tab=readme-ov-file#stable-release")
		endif
	endif
endif

################################################################################################
#                                             FUNCTIONS


define tfstate_encrypt
	if [ "$(TF_ENCRYPT_STATE)" = "true" ]; then \
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
	if [ "$(TF_ENCRYPT_STATE)" = "true" ]; then \
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
	if [ "$(TF_ENCRYPT_STATE)" = "true" ]; then \
		git checkout terraform.tfstate.d || true; \
	fi
endef


_init: SHELL:=$(shell which bash)
_init:
	@$(call tfstate_decrypt,); \
	printf "$(__BOLD)Initializing tofu...$(__RESET)\n"; \
	$(_TF) init \
		-reconfigure \
		-input=false \
		-force-copy \
		-lock=true \
		-upgrade; \
	`# check/switch workspace`; \
	printf "$(__BOLD)Checking tofu workspace...$(__RESET)\n"; \
	_CURRENT_WORKSPACE=$$($(_TF) workspace show | tr -d '[:space:]'); \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" != "$${_CURRENT_WORKSPACE}" ]; then \
		printf "$(__BOLD)Switching to workspace ($(WORKSPACE))$(__RESET)\n"; \
		$(_TF) workspace select -or-create $(WORKSPACE); \
	else \
		printf "$(__BOLD)$(__CYAN)Using workspace ($${_CURRENT_WORKSPACE})$(__RESET)\n"; \
	fi; \
	`# Initialize tflint`; \
	if [ -f ".tflint.hcl" ]; then \
		printf "$(__BOLD)Initializing tflint...$(__RESET)\n"; \
		tflint --init; \
	fi; \
	`# checkout state files to re-encrypt them`; \
	$(call tfstate_checkout,); \
	`# done`; \
	printf "$(__BOLD)$(__GREEN)Done initializing tofu$(__RESET)\n"; \
	printf "$(__BOLD)$(__CYAN)You can now run other commands, for example:$(__RESET)\n"; \
	printf "$(__BOLD)$(__CYAN)run $(__DIM)$(__BLINK)make plan$(__RESET) $(__BOLD)$(__CYAN)to preview what tofu thinks it will do when applying changes,$(__RESET)\n"; \
	printf "$(__BOLD)$(__CYAN)or $(__DIM)$(__BLINK)make help$(__RESET) $(__BOLD)$(__CYAN)to see all available make targets$(__RESET)\n"; \
	$(call tfstate_encrypt,)
