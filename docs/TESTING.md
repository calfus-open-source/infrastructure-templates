# Testing Guide

This guide explains how to test infrastructure code in this repository.

## Overview

Testing infrastructure-as-code differs from traditional application testing. We focus on:

1. **Syntax validation** - Ensure templates and configs are syntactically correct
2. **Security scanning** - Detect vulnerabilities and misconfigurations
3. **Best practices** - Enforce coding standards and conventions
4. **Idempotency** - Ensure Ansible roles can run safely multiple times

## Zero-Cost Testing Strategy

This repository uses **100% free tools** with no cloud infrastructure costs:

- ✅ Pre-commit hooks (local validation)
- ✅ GitHub Actions CI (unlimited for public repos)
- ✅ Security scanning (tfsec, checkov, trivy)
- ✅ Linting (terraform, ansible-lint, yamllint)
- ❌ Cloud integration tests (too expensive for open source)

## Setup

### 1. Install Required Tools

#### macOS

```bash
# Package managers
brew install terraform ansible pre-commit tflint yamllint shellcheck

# Python tools
pip install ansible-lint pre-commit checkov
```

#### Linux (Ubuntu/Debian)

```bash
# System packages
sudo apt-get update
sudo apt-get install -y python3-pip shellcheck

# Terraform
wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
unzip terraform_1.5.7_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Python tools
pip3 install ansible ansible-lint pre-commit yamllint checkov
```

### 2. Install Pre-Commit Hooks

```bash
cd infrastructure-templates
pre-commit install
```

This installs Git hooks that automatically validate code before commits.

### 3. Verify Setup

```bash
pre-commit run --all-files
```

Expected output: All hooks should pass (or show warnings for existing files).

## Running Tests Locally

### Pre-Commit Hooks (Recommended)

Pre-commit hooks run automatically on `git commit`:

```bash
git add .
git commit -m "your message"
# Hooks run automatically and block commit if validation fails
```

Run manually without committing:

```bash
# Run all hooks
pre-commit run --all-files

# Run specific hook
pre-commit run terraform_fmt
pre-commit run ansible-lint
pre-commit run yamllint
```

### Terraform Testing

#### Format Check

```bash
# Check formatting (fails if changes needed)
terraform fmt -check -recursive

# Auto-format all files
terraform fmt -recursive
```

#### Validation

```bash
# Note: Only works on rendered .tf files, not .liquid templates
cd rendered/aws/eks-nodegroup
terraform init -backend=false
terraform validate
```

#### TFLint

```bash
# Install tflint plugins
tflint --init

# Run linter
tflint --recursive --config=.tflint.hcl
```

#### Security Scanning

```bash
# tfsec
tfsec .

# checkov
checkov --directory . --framework terraform

# trivy
trivy config .
```

### Ansible Testing

#### Syntax Check

```bash
ansible-playbook aws/ansible/playbooks/create-k8s-cluster.yml --syntax-check
```

#### Linting

```bash
# Lint all playbooks and roles
ansible-lint aws/ansible/playbooks/ aws/ansible/roles/

# Lint specific playbook
ansible-lint aws/ansible/playbooks/create-k8s-cluster.yml
```

#### YAML Validation

```bash
# Validate all YAML files
yamllint .

# Validate specific directory
yamllint aws/ansible/
```

### Liquid Template Validation

```bash
# Run custom validation script
./scripts/validate-liquid-templates.sh
```

This checks:

- Matching `{% if %}` / `{% endif %}` tags
- Matching `{% for %}` / `{% endfor %}` tags
- Common syntax errors
- Unknown Liquid filters

### Naming Convention Checks

```bash
# Run custom naming validation
./scripts/check-terraform-naming.sh
```

This checks:

- snake_case naming
- Required tags on AWS resources
- Hardcoded values that should be variables
- Security group rules with 0.0.0.0/0

## CI/CD Pipeline

### Automated Testing

All pull requests automatically run:

1. **Validation Workflow** (`.github/workflows/validate.yml`):
   - Terraform format check
   - Terraform validation
   - Ansible linting
   - YAML linting
   - Liquid template validation
   - Terraform naming checks
   - ShellCheck
   - Markdown linting

2. **Security Scan Workflow** (`.github/workflows/security-scan.yml`):
   - tfsec (Terraform security)
   - Checkov (IaC security)
   - Trivy (container & IaC security)

### Viewing CI Results

1. Open your pull request on GitHub
2. Scroll to "Checks" section
3. Click on workflow name to see details
4. Click "Details" to see full logs

### CI Status Badges

Check the README for CI status badges showing current build status.

## Common Issues & Solutions

### Issue: Pre-commit hook fails with "command not found"

**Solution**: Install the missing tool

```bash
# Example for tflint
brew install tflint
```

### Issue: Terraform validation fails on .liquid files

**Solution**: Terraform validation only works on rendered `.tf` files, not `.liquid` templates. Either:

- Skip validation for .liquid files (already configured)
- Render templates first with MagicKube CLI

### Issue: Ansible-lint reports many warnings

**Solution**: Warnings are acceptable, but errors must be fixed. Common fixes:

```yaml
# Add 'when' condition for destructive tasks
- name: Reset cluster
  shell: kubeadm reset --force
  when: not cluster_initialized

# Add 'name' to all tasks
- name: Install packages  # Always add descriptive name
  apt:
    name: nginx
```

### Issue: YAML linting fails on line length

**Solution**: Our config allows 120 characters. For longer lines:

```yaml
# Break long lines
- name: Initialize cluster
  shell: |
    kubeadm init \
      --service-cidr {{ service_cidr }} \
      --pod-network-cidr {{ pod_network_cidr }}
```

### Issue: Security scan reports false positives

**Solution**: Add exemptions to `.tfsec/config.yml`:

```yaml
exclude:
  - aws-ec2-no-public-ingress-sgr:
      resource: aws_security_group.alb  # ALB needs public access
```

## Test Coverage

Current test coverage:

| Layer | Coverage | Method |
|-------|----------|--------|
| Syntax validation | 100% | Pre-commit + CI |
| Security scanning | 100% | tfsec, checkov, trivy |
| Linting | 100% | terraform fmt, ansible-lint, yamllint |
| Ansible idempotency | Manual | Documented best practices |
| Integration tests | 0% | Too expensive (manual testing) |

## Unit Testing

Infrastructure-templates includes comprehensive unit tests for shell scripts and Terraform modules.

### Running Unit Tests

```bash
# Run all unit tests
make test

# Or from tests directory
cd tests && make test

# Run specific test suite
make test-scripts    # Shell script validation tests
make test-terraform  # Terraform module tests

# Run with verbose output
make test-verbose

# Run a single test file
make test-one FILE=tests/unit/scripts/test_validate_liquid_templates.bats
```

### Unit Test Coverage

Current unit test coverage:

| Component | Tests | Status |
|-----------|-------|--------|
| `scripts/validate-liquid-templates.sh` | 24 | ✅ P0 |
| `scripts/check-terraform-naming.sh` | 6 | ✅ P0 |
| Terraform module schemas | — | ⏳ P1 |
| Ansible role idempotency | — | ⏳ P1 |
| Liquid template rendering | — | ⏳ P1 |

### Writing Tests

Tests use **bats-core** (Bash Automated Testing System):

```bash
# Install bats-core
brew install bats-core  # macOS
# or
sudo apt-get install bats  # Linux

# Run tests locally
make test

# View test documentation
cat tests/README.md
```

Example test:

```bash
@test "validates terraform naming conventions" {
  cat > "$TEST_DIR/test.tf.liquid" <<'EOF'
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}
EOF

  cd "$TEST_DIR"
  run bash "$CHECKER"
  [ "$status" -eq 0 ]  # Should succeed
}
```

For complete test writing guide, see [tests/README.md](../tests/README.md).

### CI Unit Tests

Unit tests automatically run on:

- ✅ Pull requests (GitHub Actions)
- ✅ Main branch pushes
- ✅ Local development (`make test`)

## Best Practices

### 1. Test Locally First

Always run pre-commit hooks before pushing:

```bash
pre-commit run --all-files
```

### 2. Fix Errors, Review Warnings

- **Errors**: Must be fixed (CI will fail)
- **Warnings**: Review and fix if reasonable

### 3. Commit Small Changes

Smaller PRs are easier to test and review.

### 4. Write Idempotent Ansible

Always check if resource exists before creating:

```yaml
- name: Check if cluster initialized
  stat:
    path: /etc/kubernetes/admin.conf
  register: cluster_conf

- name: Initialize cluster
  shell: kubeadm init ...
  when: not cluster_conf.stat.exists
```

### 5. Tag All AWS Resources

```hcl
tags = {
  Name        = "${var.project_name}-${var.environment}-vpc"
  environment = var.environment
  terraform   = "true"
  product     = var.project_name
}
```

## Updating Tests

### Update Pre-Commit Hooks

```bash
pre-commit autoupdate
git add .pre-commit-config.yaml
git commit -m "chore: update pre-commit hooks"
```

### Add New Validation Script

1. Create script in `scripts/`
2. Make executable: `chmod +x scripts/your-script.sh`
3. Add to `.pre-commit-config.yaml`:

   ```yaml
   - repo: local
     hooks:
       - id: your-check
         name: Your Check
         entry: scripts/your-script.sh
         language: script
   ```

## Resources

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [tfsec Documentation](https://aquasecurity.github.io/tfsec/)
- [Checkov Documentation](https://www.checkov.io/)
- [Pre-commit Documentation](https://pre-commit.com/)

## Getting Help

- Check existing GitHub issues
- Review CONTRIBUTING.md
- Open a new issue with details about your problem

---

Happy testing! 🧪
