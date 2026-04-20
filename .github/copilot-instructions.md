---
name: infrastructure-templates-workspace
description: "AI assistant customizations for infrastructure-templates repo. Use when working on Terraform modules, Ansible configurations, templates, or infrastructure code testing."
---

# Infrastructure Templates — Agent Instructions

This workspace contains Infrastructure-as-Code (IaC) templates for AWS and Azure cloud
deployments, implemented with Terraform, Ansible, and Liquid templates. This guide helps
AI agents collaborate effectively on the project.

## Quick Navigation

- **Setup & Environment**: [Setup](#setup--environment)
- **Project Structure**: [Directory Map](#directory-map)
- **Coding Standards**: [Conventions](#conventions)
- **Common Workflows**: [Typical Tasks](#typical-tasks)
- **Testing & Validation**: [Test Commands](#test-commands)
- **Full Reference**: [CONTRIBUTING.md](CONTRIBUTING.md), [docs/TESTING.md](docs/TESTING.md)

---

## Setup & Environment

### Initial Setup (First Time)

```bash
make setup          # Install dependencies, venv, pre-commit hooks, Ansible collections
```

### Verify Environment

```bash
make status         # Show test environment status
make check-deps     # Verify all test dependencies are installed
```

### Activate Virtual Environment (Manual)

```bash
source .venv/bin/activate
```

The virtual environment is required for Ansible tools. Most Make targets handle this automatically.

---

## Directory Map

| Path | Purpose | Key Files |
|------|---------|-----------|
| `aws/modules/` | Reusable Terraform modules | `*.tf.liquid`, `variables.tf.liquid`, `outputs.tf.liquid` |
| `aws/eks-*` | EKS cluster configurations | `main.tf.liquid`, `terraform.tfvars.liquid` |
| `aws/k8s/` | Self-managed Kubernetes on EC2 | Modules: `master/`, `worker/`, `bastion/` |
| `aws/ansible/` | Ansible playbooks & roles | `playbooks/*.yml`, `roles/*/` |
| `azure/modules/` | Azure Terraform modules | `*.tf.liquid` |
| `azure/environments/` | Environment configs | `dev/`, future: prod/, staging/ |
| `common-modules/` | Multi-cloud shared modules | ArgoCD, GitOps, Code repos |
| `aws/policies/` | IAM policy templates | `*.json.liquid` (roles: admin, developer, devops, gitops, reviewer) |
| `scripts/` | Validation & build helpers | `validate-liquid-templates.sh`, `check-terraform-naming.sh`, etc. |
| `tests/` | Unit tests (shell scripts, Terraform) | `unit/scripts/`, `unit/terraform/`, `fixtures/` |
| `docs/` | Project documentation | [TESTING.md](docs/TESTING.md), etc. |

---

## Conventions

### Terraform Files

**MUST**:

- Use `.tf.liquid` extension (not `.tf`)
  - Reason: All Terraform files use Liquid templating for environment-specific values
  - Rendering flow: `.liquid` → rendered → `.tf` → validation
- Prefix filenames with `backend-config`, `main`, `variables`, `outputs` or module name
- Add all top-level resources these tags:

  ```hcl
  tags = {
    Name        = var.name
    environment = var.environment
    terraform   = "true"
    product     = var.product  # e.g., "magickube"
  }
  ```

- Use `snake_case` for all identifiers (variables, resources, locals, outputs)
- Document all variables in `variables.tf.liquid` with `description` and `type`
- Use `var.aws_region` instead of hardcoding regions

**MUST NOT**:

- Hardcode AWS credentials, API keys, or secrets
- Use `for_each` or `count` without clear documentation (include `description` in meta-arguments)
- Create resources with overly permissive security groups without documented justification
- Use variable defaults for credentials or sensitive configuration

**Example variable**:

```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}
```

### Ansible Playbooks & Roles

**MUST**:

- All tasks have a `name` attribute (non-empty string)
- Roles are idempotent: safe to run multiple times, no `state: latest`
- Use specific versions for packages: `version: "1.24.0"`, not `state: latest`
- Document variables in `defaults/main.yml` with comments
- Include `when` conditions before destructive operations (resets, deletions)
- Follow naming pattern: `configure-`, `create-`, `destroy-` for playbooks

**MUST NOT**:

- Use unconditional destructive commands: `kubeadm reset`, `rm -rf /`, etc.
- Hardcode passwords, API keys, or sensitive values
- Create tasks without `name`

**Example task**:

```yaml
- name: Initialize Kubernetes cluster
  shell: kubeadm init --config=/etc/kubernetes/kubeadm-config.yml
  register: kubeadm_result
  when: not kubernetes_initialized
```

### Liquid Templates

**MUST**:

- Use `.liquid` extension for template files
- Validate syntax before committing: `make validate-liquid`
- Render deterministically (no random values in templates)
- Document intended variables in file comments

**File validation**:

```bash
./scripts/validate-liquid-templates.sh  # Validates all .liquid files in aws/, azure/
make validate-liquid                     # Same via Make target
```

### Shell Scripts

**MUST**:

- Start with `#!/usr/bin/env bash`
- Include `set -e` for error handling (fail on errors)
- Add comments for non-obvious logic
- Make executable: `chmod +x script.sh`

---

## Typical Tasks

### 1. Create a New Terraform Module

**When**: Adding a new cloud resource (VPC, RDS, Lambda, etc.)

**Workflow**:

```bash
# 1. Create module directory
mkdir -p aws/modules/my_module

# 2. Create required files (templates below)
touch aws/modules/my_module/{main.tf.liquid,variables.tf.liquid,outputs.tf.liquid}

# 3. Implement Terraform code with tags, snake_case naming, variable documentation
# 4. Validate module syntax
cd aws/modules/my_module
terraform init -backend=false
terraform validate

# 5. Check naming conventions
make check-naming

# 6. Run linters
make lint-terraform

# 7. Add tests in tests/unit/terraform/
# 8. Commit
```

**Template structure**:

```hcl
# main.tf.liquid
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block

  tags = {
    Name        = var.name
    environment = var.environment
    terraform   = "true"
    product     = var.product
  }
}

# variables.tf.liquid
variable "name" {
  description = "Name of the VPC"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

# outputs.tf.liquid
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}
```

### 2. Add an Ansible Role

**When**: Adding infrastructure configuration or provisioning logic

**Workflow**:

```bash
# 1. Create role directory
mkdir -p aws/ansible/roles/my_role/{tasks,defaults,handlers,templates}

# 2. Implement role files
touch aws/ansible/roles/my_role/{tasks,defaults}/main.yml

# 3. Must include task names and idempotency logic
# 4. Validate syntax
ansible-playbook aws/ansible/playbooks/my_playbook.yml --syntax-check

# 5. Run linters
make lint-ansible

# 6. Add tests
# 7. Commit
```

**Minimal role structure**:

```yaml
# aws/ansible/roles/my_role/tasks/main.yml
---
- name: Install packages
  package:
    name: "{{ item }}"
    state: present
    version: "1.0.0"  # Always specify version
  loop: "{{ packages }}"

# aws/ansible/roles/my_role/defaults/main.yml
---
# Default variables with documentation
packages:
  - name: vim
    version: "8.2"
```

### 3. Update Terraform Modules for Multi-Environment Deployment

**When**: Supporting different environments (dev, staging, prod) via Liquid variables

**Workflow**:

```bash
# 1. Identify environment-specific values (region, instance count, etc.)
# 2. Use Liquid variables in .tf.liquid files:
#    - {{ environment }} for environment name
#    - {{ aws_region }} for AWS region
#    - {{ cluster_size }} for resource sizing

# Example: aws/eks-nodegroup/main.tf.liquid
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  desired_size    = {{ desired_node_count }}
  min_size        = {{ min_node_count }}
  max_size        = {{ max_node_count }}
}

# 3. Validate liquid syntax
make validate-liquid

# 4. Test rendering (verify rendered output)
# 5. Test Terraform validation on rendered module
# 6. Run linters and tests
# 7. Commit
```

### 4. Run Full Quality Checks

**When**: Before committing or creating a PR

**Workflow**:

```bash
# Quick check (individual linters)
make test               # Unit tests only
make lint-all           # All linters (continues on error, shows summary)
make check              # Linters + security scan

# Full pipeline
make ci                 # Stops on first error (strict mode)

# Pre-commit check
pre-commit run --all-files

# Auto-fix what can be fixed (formatting, whitespace)
make lint-fix
```

---

## Test Commands

### Unit Tests

```bash
# Run all tests
make test                       # Shell, Terraform, Ansible tests

# Run specific test type
make test-unit                  # All unit tests
make test-scripts               # Shell script validators only
make test-terraform             # Terraform module validation only
make test-ansible               # Ansible role validation only

# Run single test file
make test-one FILE=tests/unit/scripts/test_validate_liquid_templates.bats

# Run with verbose output
make test-verbose

# Run with TAP output (CI-friendly)
make test-tap
```

### Linters

```bash
# Individual linters
make lint-ansible               # Ansible playbooks & roles
make lint-terraform             # Terraform fmt + tflint
make lint-yaml                  # YAML files
make lint-shell                 # Shell scripts (shellcheck)
make lint-markdown              # Markdown files

# Validation scripts
make validate-liquid            # Liquid template syntax
make check-naming               # Terraform naming conventions

# Aggregate (all linters at once)
make lint-all                   # All linters (continues on error)
make lint-summary               # Shows violation counts per linter
make security-scan              # Private key and large file detection
make pre-commit                 # All pre-commit hooks
```

### Coverage & Enforcement

```bash
make coverage                   # Generate coverage report
make coverage-report            # Display coverage results
make coverage-gaps              # Identify untested files
make coverage-enforce           # Fail if coverage below threshold
```

---

## Common Patterns & FAQ

### Q: How do I test a Terraform module before applying?

**A**:

```bash
cd aws/modules/my_module

# Render templates if using .liquid files
# (Usually handled by tests/Makefile)

# Validate syntax
terraform init -backend=false
terraform validate

# Check formatting
terraform fmt -check -recursive .

# Run linter
tflint --init
tflint

# Add unit tests in tests/unit/terraform/
make test-terraform
```

### Q: How do I test an Ansible role?

**A**:

```bash
# Syntax check (no execution)
ansible-playbook aws/ansible/playbooks/my_playbook.yml --syntax-check

# Lint the role
ansible-lint aws/ansible/roles/my_role/

# Lint all playbooks
ansible-lint aws/ansible/playbooks/

# Run via Make
make lint-ansible
```

### Q: What do I do if pre-commit hooks fail?

**A**:

1. Try auto-fix: `make lint-fix` (fixes formatting and whitespace)
2. If still failing, run individual linter to see errors: `make lint-terraform`, `make lint-ansible`, etc.
3. Fix errors manually based on linter output
4. Re-run: `pre-commit run --all-files` or commit again

### Q: How do I add a new environment?

**A**: Create new directory and populate with environment-specific `.tfvars.liquid`:

```bash
mkdir -p aws/eks-nodegroup/environments/staging
touch aws/eks-nodegroup/environments/staging/terraform.tfvars.liquid

# Populate with environment values:
aws_region = "us-west-2"
environment = "staging"
desired_node_count = 3
```

### Q: How do I navigate the codebase?

**A**: Use [Repository Structure](#directory-map) table above. Key entry points:

- AWS infrastructure: `aws/modules/` + `aws/eks-*`
- Ansible playbooks: `aws/ansible/playbooks/`
- Tests: `tests/unit/`

---

## Important Security Notes

**NEVER commit**:

- AWS/Azure credentials, access keys, or API tokens
- Private SSH keys or certificates
- Passwords or secrets (use AWS Secrets Manager, Azure Key Vault)
- `.terraform/` directories or state files with sensitive data

**Always**:

- Use environment variables or `.tfvars` (with `.gitignore`) for secrets
- Review security scan output in CI
- Follow principle of least privilege for IAM policies
- Document security-related decisions in code comments

---

## Reference & External Links

- **[CONTRIBUTING.md](CONTRIBUTING.md)** — Full contribution guidelines
- **[docs/TESTING.md](docs/TESTING.md)** — Detailed testing strategy and setup
- **[tests/README.md](tests/README.md)** — Unit test framework and structure
- **[Terraform Docs](https://www.terraform.io/language)** — Official Terraform language reference
- **[Ansible Docs](https://docs.ansible.com/)** — Official Ansible documentation

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Pre-commit hooks fail | Run `make lint-fix` then retry, or run individual linters |
| Tests fail with "command not found" | Run `make check-deps` to verify dependencies installed |
| Terraform validate fails on `.liquid` files | Ensure files use `.liquid` extension; tests render before validating |
| Ansible playbook has no effect | Check idempotency: add `when` conditions, use specific versions, check role names |
| "terraform fmt" changes files | Pre-commit hook runs formatter; review changes with `git diff` |
| Liquid template syntax errors | Run `./scripts/validate-liquid-templates.sh` to check all `.liquid` files |

---

**Last Updated**: March 2026
**Project**: infrastructure-templates (AWS + Azure Infrastructure-as-Code)
