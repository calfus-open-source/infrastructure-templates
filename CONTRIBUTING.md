# Contributing to Infrastructure Templates

Thank you for your interest in contributing! This document provides guidelines
for contributing to the infrastructure-templates repository.

## 🚀 Quick Start

### Prerequisites

1. **Install required tools**:

   ```bash
   # macOS
   brew install terraform ansible pre-commit tflint yamllint

   # Python tools
   pip install ansible-lint pre-commit
   ```

2. **Set up pre-commit hooks**:

   ```bash
   pre-commit install
   ```

3. **Verify installation**:

   ```bash
   pre-commit run --all-files
   ```

## 📋 Contribution Workflow

### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/infrastructure-templates.git
cd infrastructure-templates
```

### 2. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### 3. Make Your Changes

Follow our coding standards:

- **Terraform**: All resources must have tags, use snake_case naming
- **Ansible**: Roles must be idempotent, tasks must have descriptive names
- **Templates**: Use `.liquid` extension, validate syntax

### 4. Test Your Changes

#### Run Pre-Commit Hooks

```bash
pre-commit run --all-files
```

#### Test Terraform Modules

```bash
# Format
terraform fmt -recursive

# Validate (after rendering templates)
cd rendered/your-module
terraform init -backend=false
terraform validate
```

#### Test Ansible Roles

```bash
# Syntax check
ansible-playbook aws/ansible/playbooks/your-playbook.yml --syntax-check

# Lint
ansible-lint aws/ansible/playbooks/ aws/ansible/roles/

# YAML lint
yamllint aws/ansible/
```

#### Run Custom Validation Scripts

```bash
./scripts/validate-liquid-templates.sh
./scripts/check-terraform-naming.sh
```

#### Run Unit Tests

```bash
# Run all unit tests
make test

# Or navigate to tests directory
cd tests
make test

# Run specific test suite
make test-scripts
make test-terraform

# Run with verbose output
make test-verbose

# Run a single test file
make test-one FILE=tests/unit/scripts/test_validate_liquid_templates.bats
```

For more details on unit testing, see [tests/README.md](tests/README.md).

### 5. Commit Your Changes

Write clear, descriptive commit messages:

```bash
git add .
git commit -m "feat: add new vpc module for multi-region support"
# or
git commit -m "fix: resolve idempotency issue in setup-master-node role"
```

**Commit message format**:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

### 6. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then open a Pull Request on GitHub and fill out the PR template.

## 🎯 Code Quality Standards

### Terraform

✅ **Required**:

- All `.tf` files must have `.liquid` extension
- Resources must have tags: `Name`, `environment`, `terraform`, `product`
- Variables must have `description` and `type`
- Use snake_case for all identifiers
- No hardcoded credentials or secrets

❌ **Prohibited**:

- Hardcoded AWS regions (use `var.aws_region`)
- Overly permissive security groups without justification
- Resources without tags

### Ansible

✅ **Required**:

- Roles must be idempotent (safe to run multiple times)
- Tasks must have descriptive `name` attributes
- Use `when` conditions for destructive operations
- Variables documented in `defaults/main.yml`
- YAML files must pass yamllint

❌ **Prohibited**:

- Unconditional `kubeadm reset` or similar destructive commands
- Tasks without names
- Hardcoded passwords or secrets
- `state: latest` (use specific versions)

### Shell Scripts

✅ **Required**:

- Use `#!/usr/bin/env bash` shebang
- Include `set -e` for error handling
- Add comments explaining complex logic
- Make scripts executable: `chmod +x script.sh`

## 🔒 Security Guidelines

1. **Never commit**:
   - AWS credentials, access keys, or secrets
   - Private keys or certificates
   - Passwords or API tokens
   - Sensitive environment-specific data

2. **Security scans**:
   - All PRs are scanned with tfsec, checkov, and trivy
   - Critical/high severity issues will block merge
   - Review security findings in the GitHub Security tab

3. **Best practices**:
   - Use AWS Secrets Manager or SSM Parameter Store for secrets
   - Enable encryption at rest for all data stores
   - Follow principle of least privilege for IAM policies
   - Review security group rules carefully

## ✅ Pre-Commit Checklist

Before submitting a PR, ensure:

- [ ] Pre-commit hooks pass (`pre-commit run --all-files`)
- [ ] Terraform formatting is correct (`terraform fmt -recursive`)
- [ ] Ansible linting passes (`ansible-lint`)
- [ ] YAML linting passes (`yamllint .`)
- [ ] Liquid templates are valid (`./scripts/validate-liquid-templates.sh`)
- [ ] No security vulnerabilities (check CI security scan)
- [ ] Documentation updated (if needed)
- [ ] PR template filled out completely

## 🧪 Testing

### Local Testing

```bash
# Run all pre-commit hooks
pre-commit run --all-files

# Test specific hook
pre-commit run terraform_fmt

# Validate Liquid templates
./scripts/validate-liquid-templates.sh

# Check naming conventions
./scripts/check-terraform-naming.sh
```

### CI/CD Pipeline

All PRs automatically run:

1. **Validation workflow**: Linting, formatting, syntax checks
2. **Security scan workflow**: tfsec, checkov, trivy scans

Check the **Actions** tab to see results.

## 📖 Documentation

When adding new features:

1. Update `README.md` if user-facing changes
2. Add inline comments for complex logic
3. Document variables in Terraform `variables.tf` files
4. Document Ansible variables in `defaults/main.yml`
5. Update examples if behavior changes

## 🐛 Reporting Issues

When reporting bugs:

1. **Search existing issues** first
2. **Provide details**:
   - What you were trying to do
   - What happened
   - What you expected
   - Steps to reproduce
   - Your environment (OS, tool versions)

3. **Use issue templates** (if available)

## 💬 Getting Help

- **Documentation**: Check `docs/` directory
- **Issues**: Browse existing GitHub issues
- **Discussions**: Use GitHub Discussions for questions

## 📜 License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

## Quick Reference

### Common Commands

```bash
# Setup
pre-commit install
pre-commit autoupdate

# Testing
pre-commit run --all-files
terraform fmt -recursive
ansible-lint aws/ansible/
yamllint .

# Validation scripts
./scripts/validate-liquid-templates.sh
./scripts/check-terraform-naming.sh

# Git workflow
git checkout -b feature/my-feature
git add .
git commit -m "feat: description"
git push origin feature/my-feature
```

### File Structure

```text
infrastructure-templates/
├── aws/                    # AWS infrastructure
│   ├── modules/           # Reusable Terraform modules
│   ├── ansible/           # Ansible playbooks and roles
│   ├── eks-*/             # EKS deployment configurations
│   └── k8s/               # Self-managed K8s
├── azure/                 # Azure infrastructure
├── common-modules/        # Multi-cloud modules
├── scripts/               # Validation scripts
├── .github/               # CI/CD workflows
└── docs/                  # Documentation
```

---

Thank you for contributing! 🎉
