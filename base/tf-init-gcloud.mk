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
.PHONY: _init-gcp-config _init-gcp-project _init-adc _init

.SHELL      := $(shell which bash)
.SHELLFLAGS := -ec

################################################################################################
#                                             COMMANDS

_GCLOUD  = gcloud

################################################################################################
#                                             VARIABLES

### Google Cloud Platform

GCP_DEFAULT_CONFIGURATION  = default
GCP_PROJECT               ?= $(shell $(_GCLOUD) config get project 2>/dev/null | tr -d '[:space:]')
GCP_PREFIX                ?=
GCP_POSTFIX               ?=
QUOTA_PROJECT              = $(GCP_PREFIX)-tfstate-$(GCP_POSTFIX)

################################################################################################
#                                             RULES

# Check for necessary tools
ifneq ($(filter help,$(MAKECMDGOALS)),)
	# Skip checks for help target
else
	ifeq ($(shell which gcloud),)
	  $(error "No gcloud in $(PATH), go to https://cloud.google.com/sdk/docs/install, pick your OS, and follow the instructions")
	endif
endif

################################################################################################
#                                             FUNCTIONS

################################################################################################
#                                             TARGETS

_init-gcp-config: SHELL:=$(shell which bash)
_init-gcp-config:
	@printf "$(__BOLD)Checking active GCP configuration...$(__RESET)\n"; \
	_CURRENT_CONFIG=$$($(_GCLOUD) config configurations list --filter='is_active=true' --format='value(name)'); \
	if [ "$${_CURRENT_CONFIG}" != "$(GCP_DEFAULT_CONFIGURATION)" ]; then \
		read -p "$(__BOLD)$(__MAGENTA)Current configuration ($${_CURRENT_CONFIG}) does not match default config ($(GCP_DEFAULT_CONFIGURATION)). Do you want to proceed? [y/Y]: $(__RESET)" ANSWER && \
		if [ ! "$${ANSWER}" = "y" ] && [ ! "$${ANSWER}" = "Y" ]; then \
			read -p "$(__BOLD)$(__MAGENTA)Do you want to switch to ($(GCP_DEFAULT_CONFIGURATION)) configuration? [y/Y]: $(__RESET)" ANSWER && \
			if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
				$(_GCLOUD) config configurations activate $(GCP_DEFAULT_CONFIGURATION); \
			fi; \
		fi; \
	fi

_init-gcp-project: SHELL:=$(shell which bash)
_init-gcp-project:
	@printf "$(__BOLD)Checking GCP project...$(__RESET)\n"; \
	_DEFAULT_PROJECT=$$($(_GCLOUD) config configurations list --filter='is_active=true' --format='value(properties.core.project)'); \
	_CURRENT_PROJECT=$$($(_GCLOUD) config get project 2>/dev/null | tr -d '[:space:]'); \
	if [ "$(GCP_PROJECT)" != "(unset)" ] && [ ! -z "$(GCP_PROJECT)" ] && [ "$(GCP_PROJECT)" != "$${_DEFAULT_PROJECT}" ]; then \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Default project: $${_DEFAULT_PROJECT}, current project: $${_CURRENT_PROJECT}. Do you want to switch project? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			$(_GCLOUD) config set project $(GCP_PROJECT) && \
			$(_GCLOUD) auth login --update-adc ; \
			printf "$(__BOLD)$(__GREEN)Project changed to $(GCP_PROJECT)$(__RESET)\n"; \
		else \
			printf "$(__BOLD)$(__CYAN)Using project ($${_CURRENT_PROJECT})$(__RESET)\n"; \
		fi; \
	fi; \
	if [ "$${_CURRENT_PROJECT}" != "$${_DEFAULT_PROJECT}" ]; then \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Do you want to re-login and update ADC with ($${_DEFAULT_PROJECT}) project? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			$(_GCLOUD) auth login --update-adc ; \
		fi; \
		printf "$(__BOLD)$(__CYAN)Project is set to ($${_CURRENT_PROJECT})$(__RESET)\n"; \
	else \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Do you want to re-login and update ADC with ($${_CURRENT_PROJECT}) project? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			$(_GCLOUD) auth login --update-adc ; \
		fi; \
		printf "$(__BOLD)$(__CYAN)Project is set to ($${_CURRENT_PROJECT})$(__RESET)\n"; \
	fi

_init-adc: SHELL:=$(shell which bash)
_init-adc:
	@`# Check ADC`; \
	_CURRENT_QUOTA_PROJECT=$$(cat ~/.config/gcloud/application_default_credentials.json | jq '.quota_project_id' | tr -d '"'); \
	if [ "$(QUOTA_PROJECT)" != "$${_CURRENT_QUOTA_PROJECT}" ]; then \
		[ ! "$(NON_INTERACTIVE)" = "true" ] && \
		read -p "$(__BOLD)$(__MAGENTA)Do you want to update ADC quota-project from ($${_CURRENT_QUOTA_PROJECT}) to ($(QUOTA_PROJECT))? [y/Y]: $(__RESET)" ANSWER && \
		if [ "$${ANSWER}" = "y" ] || [ "$${ANSWER}" = "Y" ]; then \
			$(_GCLOUD) auth application-default set-quota-project $(QUOTA_PROJECT) ; \
			printf "$(__BOLD)$(__CYAN)Quota-project is set to ($(QUOTA_PROJECT))$(__RESET)\n"; \
		fi; \
	fi

_init: SHELL:=$(shell which bash)
_init:
	@`# Configure GCS backend`; \
	printf "$(__BOLD)Configuring the $(_TF) backend...$(__RESET)\n"; \
	_BUCKET_NAME=$$($(_GCLOUD) storage buckets list --project $(QUOTA_PROJECT) --format='get(name)' | grep 'tfstate' | head -n1 | tr -d '[:space:]'); \
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
	_CURRENT_WORKSPACE=$$($(_TF) workspace show | tr -d '[:space:]') && \
	if [ ! -z $(WORKSPACE) ] && [ "$(WORKSPACE)" != "$${_CURRENT_WORKSPACE}" ]; then \
		printf "$(__BOLD)Temporarily switching to 'default' workspace$(__RESET)\n"; \
		$(_TF) workspace select default; \
	fi; \
	if [ "$(TF_ENCRYPT_STATE)" = "true" ]; then \
		_passphrase=$$(echo "$(TF_ENCRYPTION_PASSPHRASE)" | xargs); \
		if [ -z "$(TF_ENCRYPTION_PASSPHRASE)" ]; then \
			if [ "$(NON_INTERACTIVE)" = "true" ]; then \
				printf "$(__BOLD)$(__RED)TF_ENCRYPTION_PASSPHRASE variable is not set$(__RESET)\n"; \
				exit 9; \
			fi; \
			read -s -p "Enter encryption passphrase: " _passphrase; \
			printf "\n"; \
		fi; \
		_config=$$(printf 'key_provider "pbkdf2" "main" {\n  passphrase = "%s"\n  key_length = 32\n  salt_length = 32\n  iterations = 600000\n}' "$${_passphrase}"); \
		export TF_ENCRYPTION="$${_config}"; \
	fi; \
	`# initialize`; \
	$(_TF) init \
		-reconfigure \
		-input=false \
		-force-copy \
		-lock=true \
		-upgrade \
		-backend=true \
		-backend-config="bucket=$${_BUCKET_NAME}" \
		-backend-config="prefix=$${_BUCKET_PATH}"
