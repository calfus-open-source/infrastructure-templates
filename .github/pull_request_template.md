## 📋 Pull Request Checklist

### Description
<!-- Provide a clear description of the changes in this PR -->

### Type of Change

- [ ] 🆕 New Terraform module
- [ ] 🆕 New Ansible role/playbook
- [ ] 🐛 Bug fix (Terraform)
- [ ] 🐛 Bug fix (Ansible)
- [ ] 📚 Documentation update
- [ ] ♻️ Code refactoring
- [ ] 🔧 Configuration change

---

### Pre-Commit Validation ✅

- [ ] Pre-commit hooks passed locally (`pre-commit run --all-files`)
- [ ] Liquid templates validated (`./scripts/validate-liquid-templates.sh`)
- [ ] Terraform formatted (`terraform fmt -recursive`)
- [ ] Terraform validated (in rendered directory)
- [ ] Ansible linting passed (`ansible-lint`)
- [ ] YAML linting passed (`yamllint .`)

### Code Quality 🎯

- [ ] All variables have `description` and `type` attributes
- [ ] Resources follow naming convention: `${var.project_name}-${var.environment}-${component}`
- [ ] No hardcoded secrets, credentials, or sensitive data
- [ ] Shell scripts use proper error handling (`set -e`, error checks)

### Security Review 🔒

- [ ] Security scans passed (tfsec, checkov, trivy)
- [ ] No overly permissive security groups (reviewed any `0.0.0.0/0` rules)
- [ ] Sensitive data uses appropriate mechanisms (Secrets Manager, SSM Parameter Store)
- [ ] IAM policies follow least privilege principle

### Terraform-Specific (if applicable)

- [ ] All resources have required tags: `Name`, `environment`, `terraform`, `product`
- [ ] Module dependencies clearly documented
- [ ] Outputs defined for important resource attributes
- [ ] Plan output reviewed (no unexpected deletions/recreations)

### Ansible-Specific (if applicable)

- [ ] Role is idempotent (can run multiple times safely)
- [ ] Tasks have descriptive `name` attributes
- [ ] No destructive commands without proper conditionals
- [ ] Handlers defined for service restarts
- [ ] Variables documented in `defaults/main.yml` or `vars/main.yml`

### Testing Evidence 📊
<!-- Attach or link to evidence that testing was performed -->

#### Local Testing

- [ ] Ran pre-commit hooks
- [ ] Tested Terraform module locally (if applicable)
- [ ] Tested Ansible role with Molecule (if applicable)

#### CI Results

- [ ] All CI checks passed (validation workflow)
- [ ] Security scans completed with no critical issues

---

### Documentation 📖

- [ ] Code changes are self-documenting or have inline comments
- [ ] README.md updated (if user-facing changes)
- [ ] CHANGELOG.md updated (if applicable)
- [ ] Examples updated (if applicable)

---

### Additional Context
<!-- Add any additional context, screenshots, or notes for reviewers -->

### Related Issues
<!-- Link related issues using: Closes #123, Fixes #456, Related to #789 -->

---

### Reviewer Checklist (for maintainers)

- [ ] Code follows project conventions
- [ ] Security review completed
- [ ] Tests are adequate
- [ ] Documentation is clear
- [ ] Changes are backward compatible (or breaking changes documented)
