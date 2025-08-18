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

# https://stackoverflow.com/a/63771055
__MAKE_DIR=$(dir $(realpath $(lastword $(MAKEFILE_LIST))))
# Use below for reference on how to use variables in a Makefile:
# - https://www.gnu.org/software/make/manual/html_node/Using-Variables.html
# - https://www.gnu.org/software/make/manual/html_node/Flavors.html
# - https://www.gnu.org/software/make/manual/html_node/Setting.html
# - https://www.gnu.org/software/make/manual/html_node/Shell-Function.html

################################################################################################
#                                             VARIABLES

### Environment

ENVFILE ?= $(realpath $(PWD)/.env)

### Terminal

# Set to 'true' for non-interactive usage
NON_INTERACTIVE ?=
# Set to 'true' to disable some options like colors in environments where $TERM is not set
NO_TERM         ?=
# Set to `true` to skip validate
__NO_VALIDATE   ?=

### Misc

# Change output
# https://www.mankier.com/5/terminfo#Description-Highlighting,_Underlining,_and_Visible_Bells
# https://www.linuxquestions.org/questions/linux-newbie-8/tput-for-bold-dim-italic-underline-blinking-reverse-invisible-4175704737/#post6308097
__RESET          = $(shell tput sgr0)
__BLINK          = $(shell tput blink)
__BOLD           = $(shell tput bold)
__DIM            = $(shell tput dim)
__SITM           = $(shell tput sitm)
__REV            = $(shell tput rev)
__SMSO           = $(shell tput smso)
__SMUL           = $(shell tput smul)
# https://www.mankier.com/5/terminfo#Description-Color_Handling
__BLACK          = $(shell tput setaf 0)
__RED            = $(shell tput setaf 1)
__GREEN          = $(shell tput setaf 2)
__YELLOW         = $(shell tput setaf 3)
__BLUE           = $(shell tput setaf 4)
__MAGENTA        = $(shell tput setaf 5)
__CYAN           = $(shell tput setaf 6)
__WHITE          = $(shell tput setaf 7)
# set to 'true' to disable colors
__NO_COLORS      = false

################################################################################################
#                                             RULES

ifeq ($(NO_TERM),true)
  __NO_COLORS=true
endif

ifeq ($(origin TERM), undefined)
  __NO_COLORS=true
endif

ifeq ($(__NO_COLORS),true)
  __RESET   =
  __BLINK   =
  __BOLD    =
  __DIM     =
  __SITM    =
  __REV     =
  __SMSO    =
  __SMUL    =
  __BLACK   =
  __RED     =
  __GREEN   =
  __YELLOW  =
  __BLUE    =
  __MAGENTA =
  __CYAN    =
  __WHITE   =
endif

################################################################################################
#                                             FUNCTIONS

################################################################################################
#                                             TARGETS
