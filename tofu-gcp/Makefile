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

################################################################################################
#                                             INCLUDES

__MAKE_DIR  ?= $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

include $(__MAKE_DIR)../base/tf.mk

################################################################################################
#                                             COMMANDS

_TF     = tofu
_GCLOUD = gcloud

################################################################################################
#                                             VARIABLES

## NB! Empty (conditional) variables for base.mk and tf.mk overrides to get autocompletion to work

### Terraform|Tofu

WORKSPACE                 ?=
# Additional, space-separated, tofu command options
TF_ARGS                   ?=
# Set a resource path to apply first, before fully converging the entire configuration
# This is a shortcut to avoid calling make apply twice, i.e. 'make apply TF_ARGS='-target="some_resource.name"' && make apply'
# NB! this will apply the changes to the `some_resource.name` even when used with 'plan' target.
TF_CONVERGE_FROM          ?=
# Plan file path (used with plan, apply, and destroy targets)
TF_PLAN                   ?=
# Resource address for 'state' and 'import' targets
TF_RES_ADDR               ?=
# Import resource ID
TF_RES_ID                 ?=
TF_ENCRYPT_STATE          ?=
# encryption passphrase for the state file
TF_ENCRYPTION_PASSPHRASE  ?=

### Google Cloud Platform

GCP_DEFAULT_CONFIGURATION ?= 
GCP_PROJECT               ?=
GCP_PREFIX                ?= 
GCP_POSTFIX               ?= 
QUOTA_PROJECT             ?= 

### Terminal

# Set to 'true' for non-interactive usage
NON_INTERACTIVE ?=
# Set to 'true' to disable some options like colors in environments where $TERM is not set
NO_TERM         ?=

################################################################################################
#                                             RULES

################################################################################################
#                                             FUNCTIONS

################################################################################################
#                                             TARGETS

## NB! Empty targets for tf.mk overrides to get autocompletion to work

help:

init:

format:

validate:

test:

plan:

apply:

destroy:

show:

state:

output:

clean:

import:
