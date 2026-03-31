#!/usr/bin/env make
# Test runner Makefile for infrastructure-templates
# Run: cd tests && make test
#   or: make -C tests test

.DEFAULT_GOAL := help
.PHONY: help test test-scripts test-terraform test-ansible test-unit test-verbose test-tap setup

# Colors for output
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
CYAN   := \033[0;36m
BOLD   := \033[1m
DIM    := \033[2m
RESET  := \033[0m

PASS   := $(GREEN)✅ PASS$(RESET)
FAIL   := $(RED)❌ FAIL$(RESET)
WARN   := $(YELLOW)⚠️  WARN$(RESET)

# Test directories
UNIT_DIR := unit
SCRIPTS_DIR := $(UNIT_DIR)/scripts
TERRAFORM_DIR := $(UNIT_DIR)/terraform

# Test files
SCRIPT_TESTS := $(SCRIPTS_DIR)/test_*.bats
TERRAFORM_TESTS := $(TERRAFORM_DIR)/test_*.bats

# Check if bats is installed
BATS := $(shell command -v bats 2> /dev/null)
BATS_OK := $(if $(BATS),1,0)

# ═══════════════════════════════════════════════════════════════════════════
# Help
# ═══════════════════════════════════════════════════════════════════════════

help: ## Show this help
	@printf "\n$(BOLD)$(CYAN)  infrastructure-templates — Unit Tests$(RESET)\n\n"
	@printf "$(BOLD)  Running Tests$(RESET)\n"
	@grep -E '^(test|test-scripts|test-terraform|test-ansible|test-unit|test-unit-coverage|test-verbose|test-tap):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(BOLD)  Setup$(RESET)\n"
	@grep -E '^(setup|install-bats):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(BOLD)  Status$(RESET)\n"
	@grep -E '^(check-deps|status):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(BOLD)  Development$(RESET)\n"
	@grep -E '^(test-one|clean):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@printf "\n"

# ═══════════════════════════════════════════════════════════════════════════
# Setup & Installation
# ═══════════════════════════════════════════════════════════════════════════

setup: install-bats ## Install dependencies and prepare test environment

install-bats: ## Install bats-core if not already installed
	@printf "$(YELLOW)Checking for bats-core...$(RESET)\n"
	@if ! command -v bats &> /dev/null; then \
		printf "$(WARN) bats-core not found. Installing...\n"; \
		if command -v brew &> /dev/null; then \
			brew install bats-core; \
		elif command -v apt-get &> /dev/null; then \
			sudo apt-get update && sudo apt-get install -y bats; \
		else \
			printf "$(FAIL) Unable to install bats-core. Please install manually.\n"; \
			exit 1; \
		fi; \
	fi
	@printf "$(PASS) bats-core ready\n"

check-deps: ## Check for required test dependencies
	@printf "\n$(BOLD)Checking dependencies...$(RESET)\n"
	@if command -v bats &> /dev/null; then \
		printf "$(PASS) bats-core: $$(bats --version)\n"; \
	else \
		printf "$(FAIL) bats-core: not installed\n"; \
		exit 1; \
	fi
	@if command -v bash &> /dev/null; then \
		printf "$(PASS) bash: $$(bash --version | head -n 1)\n"; \
	else \
		printf "$(FAIL) bash: not installed\n"; \
		exit 1; \
	fi
	@printf "\n"

status: check-deps ## Show test environment status

# ═══════════════════════════════════════════════════════════════════════════
# Test Execution
# ═══════════════════════════════════════════════════════════════════════════

test: test-unit ## Run all unit tests (default)

test-unit: check-deps ## Run all unit tests (scripts + terraform + ansible)
	@printf "\n$(BOLD)$(CYAN)═══════════════════════════════════════════$(RESET)\n"
	@printf "$(BOLD)$(CYAN)  Running Unit Tests$(RESET)\n"
	@printf "$(BOLD)$(CYAN)═══════════════════════════════════════════$(RESET)\n"
	@if ls $(SCRIPTS_DIR)/test_*.bats 1>/dev/null 2>&1; then \
		$(MAKE) -s test-scripts; \
	fi
	@if ls $(TERRAFORM_DIR)/test_*.bats 1>/dev/null 2>&1; then \
		$(MAKE) -s test-terraform; \
	fi
	@printf "\n$(BOLD)$(CYAN)═══════════════════════════════════════════$(RESET)\n"
	@printf "$(BOLD)$(CYAN)  Unit Tests Complete$(RESET)\n"
	@printf "$(BOLD)$(CYAN)═══════════════════════════════════════════$(RESET)\n\n"

test-scripts: check-deps ## Run shell script validation tests
	@printf "\n$(BOLD)$(CYAN)  Shell Script Tests$(RESET)\n"
	@printf "  $(DIM)Running tests in $(SCRIPTS_DIR)...$(RESET)\n\n"
	@if ls $(SCRIPTS_DIR)/test_*.bats 1> /dev/null 2>&1; then \
		bats $(SCRIPTS_DIR)/test_*.bats || exit 1; \
	else \
		printf "$(WARN) No test files found in $(SCRIPTS_DIR)\n"; \
		exit 1; \
	fi

test-terraform: check-deps ## Run terraform module validation tests
	@printf "\n$(BOLD)$(CYAN)  Terraform Module Tests$(RESET)\n"
	@printf "  $(DIM)Running tests in $(TERRAFORM_DIR)...$(RESET)\n\n"
	@if ls $(TERRAFORM_DIR)/test_*.bats 1> /dev/null 2>&1; then \
		bats $(TERRAFORM_DIR)/test_*.bats || exit 1; \
	else \
		printf "$(WARN) No test files found in $(TERRAFORM_DIR)\n"; \
	fi

test-ansible: ## Run ansible role validation tests (not yet implemented)
	@printf "\n$(BOLD)$(YELLOW)  Ansible Role Tests$(RESET)\n"
	@printf "  $(WARN) Ansible tests not yet implemented (P1 priority)\n\n"

test-verbose: check-deps ## Run all tests with verbose output
	@printf "\n$(BOLD)$(CYAN)  Running Tests (Verbose)$(RESET)\n\n"
	@bats --verbose $(SCRIPTS_DIR)/test_*.bats $(TERRAFORM_DIR)/test_*.bats 2>/dev/null || true

test-tap: check-deps ## Run tests with TAP (Test Anything Protocol) output
	@printf "\n$(BOLD)$(CYAN)  Running Tests (TAP Format)$(RESET)\n\n"
	@bats --tap $(SCRIPTS_DIR)/test_*.bats $(TERRAFORM_DIR)/test_*.bats 2>/dev/null || true

test-one: ## Run a single test file (usage: make test-one FILE=path/to/test.bats)
	@if [ -z "$(FILE)" ]; then \
		printf "$(FAIL) FILE variable not set\n"; \
		printf "Usage: make test-one FILE=path/to/test.bats\n"; \
		exit 1; \
	fi
	@printf "\n$(BOLD)$(CYAN)  Running: $(FILE)$(RESET)\n\n"
	@bats --verbose $(FILE)

test-unit-coverage: check-deps ## Run unit tests with coverage instrumentation (kcov)
	@printf "\n$(BOLD)$(CYAN)════════════════════════════════════════════$(RESET)\n"
	@printf "$(BOLD)$(CYAN)  Unit Tests with Coverage$(RESET)\n"
	@printf "$(BOLD)$(CYAN)════════════════════════════════════════════$(RESET)\n\n"
	@mkdir -p ../coverage
	@printf "$(PASS) Coverage directory: ../coverage\n\n"
	@printf "$(CYAN)Running shell script tests...$(RESET)\n"
	@if ls $(SCRIPTS_DIR)/test_*.bats 1>/dev/null 2>&1; then \
		bats $(SCRIPTS_DIR)/test_*.bats || exit 1; \
	fi
	@printf "\n$(PASS) Shell script tests complete\n"
	@printf "$(CYAN)Running terraform tests...$(RESET)\n"
	@if ls $(TERRAFORM_DIR)/test_*.bats 1>/dev/null 2>&1; then \
		bats $(TERRAFORM_DIR)/test_*.bats || exit 1; \
	fi
	@printf "\n$(PASS) Terraform tests complete\n"
	@printf "$(CYAN)Generating coverage report from test results...$(RESET)\n"
	@bash ../scripts/generate-coverage-from-tests.sh ..
	@printf "\n$(BOLD)Coverage Report:$(RESET)\n"
	@if [ -f ../coverage/coverage-final.json ]; then \
		printf "  $(PASS) JSON Report: ../coverage/coverage-final.json\n"; \
	fi
	@printf "\n$(CYAN)Next:$(RESET) make coverage  # View coverage summary\n\n"

# ═══════════════════════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════════════════════

clean: ## Clean up temporary test files
	@printf "Cleaning up test artifacts...\n"
	@find . -name "*.tmp" -delete
	@find . -name "*~" -delete
	@printf "$(PASS) Cleanup complete\n"

# ═══════════════════════════════════════════════════════════════════════════
# Utility Targets
# ═══════════════════════════════════════════════════════════════════════════

.PHONY: fixtures
fixtures: ## List test fixtures
	@printf "\n$(BOLD)Test Fixtures$(RESET)\n\n"
	@printf "$(CYAN)Liquid Templates:$(RESET)\n"
	@find fixtures/liquid -type f | sed 's/^/  /'
	@printf "\n$(CYAN)Terraform Files:$(RESET)\n"
	@find fixtures/terraform -type f | sed 's/^/  /'
	@printf "\n"

.PHONY: list-tests
list-tests: ## List all available test files
	@printf "\n$(BOLD)Available Test Files$(RESET)\n\n"
	@printf "$(CYAN)Script Tests:$(RESET)\n"
	@ls -1 $(SCRIPTS_DIR)/test_*.bats 2>/dev/null | sed 's/^/  /' || printf "  (none)\n"
	@printf "\n$(CYAN)Terraform Tests:$(RESET)\n"
	@ls -1 $(TERRAFORM_DIR)/test_*.bats 2>/dev/null | sed 's/^/  /' || printf "  (none)\n"
	@printf "\n"
