SHELL := /bin/bash
.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
ROOT_DIR := $(shell pwd)
VENV     := $(ROOT_DIR)/.venv
VENV_BIN := $(VENV)/bin
SCRIPTS  := $(ROOT_DIR)/scripts

# ---------------------------------------------------------------------------
# Colors & Symbols
# ---------------------------------------------------------------------------
GREEN  := \033[0;32m
RED    := \033[0;31m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
BOLD   := \033[1m
DIM    := \033[2m
RESET  := \033[0m

PASS := $(GREEN)✅ PASS$(RESET)
FAIL := $(RED)❌ FAIL$(RESET)
WARN := $(YELLOW)⚠️  WARN$(RESET)
SEP  := $(DIM)─────────────────────────────────────────────────────$(RESET)

ACTIVATE := source $(VENV_BIN)/activate &&

# ---------------------------------------------------------------------------
# Phony targets
# ---------------------------------------------------------------------------
.PHONY: help \
	lint-ansible lint-terraform lint-yaml lint-shell lint-markdown \
	validate-liquid check-naming \
	lint-all security-scan pre-commit \
	check ci \
	setup clean update-deps \
	lint-fix lint-summary \
	test test-unit test-scripts test-terraform test-ansible test-verbose test-tap test-one \
	check-deps status list-tests fixtures

# ═══════════════════════════════════════════════════════════════════════════
# Help
# ═══════════════════════════════════════════════════════════════════════════

help: ## Show this help
	@printf "\n$(BOLD)$(CYAN)  infrastructure-templates — Make Targets$(RESET)\n\n"
	@printf "$(BOLD)  Testing$(RESET)$(DIM) (unit tests + linters)$(RESET)\n"
	@grep -E '^(test|test-unit|test-scripts|test-terraform|test-ansible|test-verbose|test-tap|lint-ansible|lint-terraform|lint-yaml|lint-shell|lint-markdown|validate-liquid|check-naming):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    $(CYAN)%-22s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(BOLD)  Test Management$(RESET)\n"
	@grep -E '^(test-one|check-deps|status|list-tests|fixtures):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    $(CYAN)%-22s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(BOLD)  Quality$(RESET)$(DIM) (aggregated checks)$(RESET)\n"
	@grep -E '^(lint-all|security-scan|pre-commit):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    $(CYAN)%-22s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(BOLD)  Combined$(RESET)$(DIM) (full pipelines)$(RESET)\n"
	@grep -E '^(check|ci):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    $(CYAN)%-22s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(BOLD)  Build / Setup$(RESET)\n"
	@grep -E '^(setup|clean|update-deps):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    $(CYAN)%-22s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(BOLD)  Utility$(RESET)\n"
	@grep -E '^(lint-fix|lint-summary):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    $(CYAN)%-22s$(RESET) %s\n", $$1, $$2}'
	@printf "\n"

# ═══════════════════════════════════════════════════════════════════════════
# Testing — unit tests + individual linters
# ═══════════════════════════════════════════════════════════════════════════

test: ## Run unit tests (shell scripts, terraform modules)
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Unit Tests$(RESET)\n$(SEP)\n"
	@export ROOT_DIR=$(ROOT_DIR) SCRIPTS=$(SCRIPTS) && $(MAKE) -C tests test && \
		printf "$(PASS)  Unit Tests\n" || \
		{ printf "$(FAIL)  Unit Tests\n"; exit 1; }

# Test delegation targets — forward to tests/Makefile
test-unit: ## Run all unit tests (scripts + terraform)
	@$(MAKE) -C tests test-unit

test-scripts: ## Run shell script validation tests
	@$(MAKE) -C tests test-scripts

test-terraform: ## Run terraform module validation tests
	@$(MAKE) -C tests test-terraform

test-ansible: ## Run ansible role validation tests
	@$(MAKE) -C tests test-ansible

test-verbose: ## Run all tests with verbose output
	@$(MAKE) -C tests test-verbose

test-tap: ## Run tests with TAP output
	@$(MAKE) -C tests test-tap

test-one: ## Run a single test file (usage: make test-one FILE=path/to/test.bats)
	@$(MAKE) -C tests test-one FILE=$(FILE)

check-deps: ## Check for required test dependencies
	@$(MAKE) -C tests check-deps

status: ## Show test environment status
	@$(MAKE) -C tests status

list-tests: ## List all available test files
	@$(MAKE) -C tests list-tests

fixtures: ## List test fixtures
	@$(MAKE) -C tests fixtures

lint-ansible: ## Run ansible-lint on Ansible roles & playbooks
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Ansible Lint$(RESET)\n$(SEP)\n"
	@$(ACTIVATE) ansible-lint --config-file=.ansible-lint && \
		printf "$(PASS)  Ansible Lint\n" || \
		{ printf "$(FAIL)  Ansible Lint\n"; exit 1; }

lint-terraform: ## Run terraform fmt check + tflint
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Terraform Lint$(RESET)\n$(SEP)\n"
	@pre-commit run terraform_fmt --all-files && \
	 pre-commit run terraform_tflint --all-files && \
		printf "$(PASS)  Terraform Lint\n" || \
		{ printf "$(FAIL)  Terraform Lint\n"; exit 1; }

lint-yaml: ## Run yamllint on YAML files
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  YAML Lint$(RESET)\n$(SEP)\n"
	@pre-commit run yamllint --all-files && \
		printf "$(PASS)  YAML Lint\n" || \
		{ printf "$(FAIL)  YAML Lint\n"; exit 1; }

lint-shell: ## Run shellcheck on shell scripts
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  ShellCheck$(RESET)\n$(SEP)\n"
	@pre-commit run shellcheck --all-files && \
		printf "$(PASS)  ShellCheck\n" || \
		{ printf "$(FAIL)  ShellCheck\n"; exit 1; }

lint-markdown: ## Run markdownlint on Markdown files
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Markdown Lint$(RESET)\n$(SEP)\n"
	@pre-commit run markdownlint --all-files && \
		printf "$(PASS)  Markdown Lint\n" || \
		{ printf "$(FAIL)  Markdown Lint\n"; exit 1; }

validate-liquid: ## Validate Liquid template syntax
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Liquid Templates$(RESET)\n$(SEP)\n"
	@bash $(SCRIPTS)/validate-liquid-templates.sh && \
		printf "$(PASS)  Liquid Templates\n" || \
		{ printf "$(FAIL)  Liquid Templates\n"; exit 1; }

check-naming: ## Check Terraform naming conventions
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Terraform Naming$(RESET)\n$(SEP)\n"
	@bash $(SCRIPTS)/check-terraform-naming.sh && \
		printf "$(PASS)  Terraform Naming\n" || \
		{ printf "$(FAIL)  Terraform Naming\n"; exit 1; }

# ═══════════════════════════════════════════════════════════════════════════
# Quality — aggregated checks
# ═══════════════════════════════════════════════════════════════════════════

lint-all: ## Run ALL linters (continues on failure, shows summary)
	@FAILED=0; \
	printf "\n$(BOLD)$(CYAN)══════════════════════════════════════════$(RESET)\n"; \
	printf "$(BOLD)$(CYAN)  Running All Linters$(RESET)\n"; \
	printf "$(BOLD)$(CYAN)══════════════════════════════════════════$(RESET)\n"; \
	\
	printf "\n$(DIM)  [1/7] Ansible Lint$(RESET)\n"; \
	$(ACTIVATE) ansible-lint --config-file=.ansible-lint 2>&1 && R_ANS="PASS" || R_ANS="FAIL"; \
	[ "$$R_ANS" = "FAIL" ] && FAILED=$$((FAILED+1)); \
	\
	printf "\n$(DIM)  [2/7] Terraform Lint$(RESET)\n"; \
	pre-commit run terraform_fmt --all-files 2>&1 && \
	pre-commit run terraform_tflint --all-files 2>&1 && R_TF="PASS" || R_TF="FAIL"; \
	[ "$$R_TF" = "FAIL" ] && FAILED=$$((FAILED+1)); \
	\
	printf "\n$(DIM)  [3/7] YAML Lint$(RESET)\n"; \
	pre-commit run yamllint --all-files 2>&1 && R_YML="PASS" || R_YML="FAIL"; \
	[ "$$R_YML" = "FAIL" ] && FAILED=$$((FAILED+1)); \
	\
	printf "\n$(DIM)  [4/7] ShellCheck$(RESET)\n"; \
	pre-commit run shellcheck --all-files 2>&1 && R_SH="PASS" || R_SH="FAIL"; \
	[ "$$R_SH" = "FAIL" ] && FAILED=$$((FAILED+1)); \
	\
	printf "\n$(DIM)  [5/7] Markdown Lint$(RESET)\n"; \
	pre-commit run markdownlint --all-files 2>&1 && R_MD="PASS" || R_MD="FAIL"; \
	[ "$$R_MD" = "FAIL" ] && FAILED=$$((FAILED+1)); \
	\
	printf "\n$(DIM)  [6/7] Liquid Templates$(RESET)\n"; \
	bash $(SCRIPTS)/validate-liquid-templates.sh 2>&1 && R_LQ="PASS" || R_LQ="FAIL"; \
	[ "$$R_LQ" = "FAIL" ] && FAILED=$$((FAILED+1)); \
	\
	printf "\n$(DIM)  [7/7] Terraform Naming$(RESET)\n"; \
	bash $(SCRIPTS)/check-terraform-naming.sh 2>&1 && R_NM="PASS" || R_NM="FAIL"; \
	[ "$$R_NM" = "FAIL" ] && FAILED=$$((FAILED+1)); \
	\
	printf "\n$(BOLD)$(CYAN)══════════════════════════════════════════$(RESET)\n"; \
	printf "$(BOLD)  Summary$(RESET)\n"; \
	printf "$(CYAN)══════════════════════════════════════════$(RESET)\n"; \
	for ITEM in "Ansible Lint:$$R_ANS" "Terraform Lint:$$R_TF" "YAML Lint:$$R_YML" \
	            "ShellCheck:$$R_SH" "Markdown Lint:$$R_MD" "Liquid Templates:$$R_LQ" \
	            "Terraform Naming:$$R_NM"; do \
		NAME=$${ITEM%%:*}; STATUS=$${ITEM##*:}; \
		if [ "$$STATUS" = "PASS" ]; then \
			printf "  $(GREEN)✅ %-22s PASS$(RESET)\n" "$$NAME"; \
		else \
			printf "  $(RED)❌ %-22s FAIL$(RESET)\n" "$$NAME"; \
		fi; \
	done; \
	printf "$(CYAN)══════════════════════════════════════════$(RESET)\n"; \
	if [ $$FAILED -gt 0 ]; then \
		printf "  $(RED)$(BOLD)$$FAILED linter(s) failed$(RESET)\n\n"; exit 1; \
	else \
		printf "  $(GREEN)$(BOLD)All linters passed$(RESET)\n\n"; \
	fi

security-scan: ## Run security checks (private keys, large files)
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Security Scan$(RESET)\n$(SEP)\n"
	@pre-commit run detect-private-key --all-files && \
	 pre-commit run check-added-large-files --all-files && \
		printf "$(PASS)  Security Scan\n" || \
		{ printf "$(FAIL)  Security Scan\n"; exit 1; }

pre-commit: ## Run all pre-commit hooks
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Pre-commit (all hooks)$(RESET)\n$(SEP)\n"
	@pre-commit run --all-files

# ═══════════════════════════════════════════════════════════════════════════
# Combined — full pipelines
# ═══════════════════════════════════════════════════════════════════════════

check: ## Run all quality checks + security scan
	@$(MAKE) --no-print-directory lint-all
	@$(MAKE) --no-print-directory security-scan

ci: ## Mimic CI pipeline (strict — stops on first failure)
	@printf "\n$(BOLD)$(CYAN)══════════════════════════════════════════$(RESET)\n"
	@printf "$(BOLD)$(CYAN)  CI Pipeline$(RESET)\n"
	@printf "$(BOLD)$(CYAN)══════════════════════════════════════════$(RESET)\n"
	@$(MAKE) --no-print-directory lint-ansible
	@$(MAKE) --no-print-directory lint-terraform
	@$(MAKE) --no-print-directory lint-yaml
	@$(MAKE) --no-print-directory lint-shell
	@$(MAKE) --no-print-directory lint-markdown
	@$(MAKE) --no-print-directory validate-liquid
	@$(MAKE) --no-print-directory check-naming
	@$(MAKE) --no-print-directory security-scan
	@printf "\n$(GREEN)$(BOLD)  CI Pipeline — all checks passed$(RESET)\n\n"

# ═══════════════════════════════════════════════════════════════════════════
# Build / Setup
# ═══════════════════════════════════════════════════════════════════════════

setup: ## Install dependencies, pre-commit hooks, and collections
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Setup$(RESET)\n$(SEP)\n"
	@test -d $(VENV) || python3 -m venv $(VENV)
	@$(ACTIVATE) pip install --quiet --upgrade pip
	@$(ACTIVATE) pip install --quiet ansible-lint ansible-core yamllint
	@$(ACTIVATE) ansible-galaxy collection install ansible.posix community.general --force || true
	@pre-commit install
	@printf "$(PASS)  Setup complete\n"

clean: ## Remove caches and temp files
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Clean$(RESET)\n$(SEP)\n"
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name .terraform -exec rm -rf {} + 2>/dev/null || true
	@rm -rf .pre-commit-cache
	@printf "$(PASS)  Cleaned caches\n"

update-deps: ## Upgrade linters and pre-commit hooks
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Update Dependencies$(RESET)\n$(SEP)\n"
	@$(ACTIVATE) pip install --upgrade ansible-lint ansible-core yamllint
	@pre-commit autoupdate
	@printf "$(PASS)  Dependencies updated\n"

# ═══════════════════════════════════════════════════════════════════════════
# Utility
# ═══════════════════════════════════════════════════════════════════════════

lint-fix: ## Auto-fix what can be fixed (formatting, whitespace, markdown)
	@printf "\n$(SEP)\n$(BOLD)$(CYAN)  Auto-fix$(RESET)\n$(SEP)\n"
	@pre-commit run trailing-whitespace --all-files || true
	@pre-commit run end-of-file-fixer --all-files || true
	@pre-commit run markdownlint --all-files || true
	@printf "$(PASS)  Auto-fix complete (review changes with git diff)\n"

lint-summary: ## Dashboard — violation counts per linter
	@printf "\n$(BOLD)$(CYAN)══════════════════════════════════════════════════════$(RESET)\n"
	@printf "$(BOLD)$(CYAN)  Lint Summary Dashboard$(RESET)\n"
	@printf "$(BOLD)$(CYAN)══════════════════════════════════════════════════════$(RESET)\n"
	@printf "  $(BOLD)%-24s %-10s %s$(RESET)\n" "Linter" "Status" "Issues"
	@printf "  $(DIM)%-24s %-10s %s$(RESET)\n" "────────────────────────" "──────────" "──────"
	@\
	ANS_OUT=$$($(ACTIVATE) ansible-lint --config-file=.ansible-lint 2>&1); ANS_RC=$$?; \
	ANS_COUNT=$$(echo "$$ANS_OUT" | grep -oE '[0-9]+ failure' | grep -oE '[0-9]+' || true); \
	[ -z "$$ANS_COUNT" ] && ANS_COUNT=0; \
	if [ $$ANS_RC -eq 0 ]; then \
		printf "  %-24s $(GREEN)%-10s$(RESET) %s\n" "ansible-lint" "PASS" "0"; \
	else \
		printf "  %-24s $(RED)%-10s$(RESET) %s\n" "ansible-lint" "FAIL" "$$ANS_COUNT"; \
	fi; \
	\
	YML_OUT=$$(pre-commit run yamllint --all-files 2>&1); YML_RC=$$?; \
	if [ $$YML_RC -eq 0 ]; then \
		printf "  %-24s $(GREEN)%-10s$(RESET) %s\n" "yamllint" "PASS" "0"; \
	else \
		YML_COUNT=$$(echo "$$YML_OUT" | grep -cE '^\s+\d+:\d+' || echo "?"); \
		printf "  %-24s $(RED)%-10s$(RESET) %s\n" "yamllint" "FAIL" "$$YML_COUNT"; \
	fi; \
	\
	TF_OUT=$$(pre-commit run terraform_fmt --all-files 2>&1); TF_RC=$$?; \
	if [ $$TF_RC -eq 0 ]; then \
		printf "  %-24s $(GREEN)%-10s$(RESET) %s\n" "terraform fmt" "PASS" "0"; \
	else \
		printf "  %-24s $(YELLOW)%-10s$(RESET) %s\n" "terraform fmt" "WARN" "see output"; \
	fi; \
	\
	SH_OUT=$$(pre-commit run shellcheck --all-files 2>&1); SH_RC=$$?; \
	if [ $$SH_RC -eq 0 ]; then \
		printf "  %-24s $(GREEN)%-10s$(RESET) %s\n" "shellcheck" "PASS" "0"; \
	else \
		SH_COUNT=$$(echo "$$SH_OUT" | grep -cE 'SC[0-9]+' || echo "?"); \
		printf "  %-24s $(RED)%-10s$(RESET) %s\n" "shellcheck" "FAIL" "$$SH_COUNT"; \
	fi; \
	\
	MD_OUT=$$(pre-commit run markdownlint --all-files 2>&1); MD_RC=$$?; \
	if [ $$MD_RC -eq 0 ]; then \
		printf "  %-24s $(GREEN)%-10s$(RESET) %s\n" "markdownlint" "PASS" "0"; \
	else \
		MD_COUNT=$$(echo "$$MD_OUT" | grep -cE 'MD[0-9]+' || echo "?"); \
		printf "  %-24s $(RED)%-10s$(RESET) %s\n" "markdownlint" "FAIL" "$$MD_COUNT"; \
	fi; \
	\
	LQ_OUT=$$(bash $(SCRIPTS)/validate-liquid-templates.sh 2>&1); LQ_RC=$$?; \
	if [ $$LQ_RC -eq 0 ]; then \
		printf "  %-24s $(GREEN)%-10s$(RESET) %s\n" "liquid templates" "PASS" "0"; \
	else \
		printf "  %-24s $(RED)%-10s$(RESET) %s\n" "liquid templates" "FAIL" "see output"; \
	fi; \
	\
	NM_OUT=$$(bash $(SCRIPTS)/check-terraform-naming.sh 2>&1); NM_RC=$$?; \
	if [ $$NM_RC -eq 0 ]; then \
		printf "  %-24s $(GREEN)%-10s$(RESET) %s\n" "terraform naming" "PASS" "0"; \
	else \
		printf "  %-24s $(RED)%-10s$(RESET) %s\n" "terraform naming" "FAIL" "see output"; \
	fi; \
	\
	SK_OUT=$$(pre-commit run detect-private-key --all-files 2>&1); SK_RC=$$?; \
	if [ $$SK_RC -eq 0 ]; then \
		printf "  %-24s $(GREEN)%-10s$(RESET) %s\n" "private key check" "PASS" "0"; \
	else \
		printf "  %-24s $(RED)%-10s$(RESET) %s\n" "private key check" "FAIL" "!"; \
	fi; \
	\
	printf "$(CYAN)══════════════════════════════════════════════════════$(RESET)\n\n"
