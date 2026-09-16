SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

.DEFAULT_GOAL := help

ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

TERRAFORM ?= terraform
CHECKOV ?= checkov
TFLINT ?= tflint
TERRAFORM_DOCS ?= terraform-docs
CONFTEST ?= conftest

export ROOT_DIR TERRAFORM CHECKOV TFLINT TERRAFORM_DOCS CONFTEST

# --- help ---

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# --- checks ---

.PHONY: check
check: ## Run every gate a commit has to pass
	@$(ROOT_DIR)/scripts/check.sh

.PHONY: fmt
fmt: ## Rewrite every file to canonical formatting
	@$(TERRAFORM) fmt -recursive $(ROOT_DIR)

.PHONY: fmt-check
fmt-check: ## Fail if any file is not canonically formatted
	@$(TERRAFORM) fmt -check -recursive -diff $(ROOT_DIR)

.PHONY: validate
validate: ## Initialise and validate every module and example
	@$(ROOT_DIR)/scripts/validate.sh

.PHONY: plan-test
plan-test: ## Plan every example against mock providers, with real values
	@$(ROOT_DIR)/scripts/plan.sh

.PHONY: lint
lint: ## Run tflint over every module and example
	@$(ROOT_DIR)/scripts/lint.sh

.PHONY: security
security: ## Run checkov over the repository
	@$(ROOT_DIR)/scripts/security.sh

.PHONY: policy
policy: ## Check the repository's own conventions, and that each rule still refuses
	@$(ROOT_DIR)/scripts/policy.sh

.PHONY: docs
docs: ## Regenerate the input and output tables in every module README
	@$(ROOT_DIR)/scripts/docs.sh

.PHONY: docs-check
docs-check: ## Fail if a module README is out of step with its variables
	@CHECK_ONLY=1 $(ROOT_DIR)/scripts/docs.sh

# --- housekeeping ---

.PHONY: clean
clean: ## Remove .terraform directories and the modules' lock files
	@$(ROOT_DIR)/scripts/clean.sh
