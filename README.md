# Infrastructure Templates

Repository for Terraform and Ansible configurations for AWS and Azure deployments.

## Setup

```bash
# Install tools
brew install terraform ansible pre-commit tflint yamllint
pip install ansible-lint pre-commit

# Setup repo
git clone <repo-url>
cd infrastructure-templates
pre-commit install
```

## Quick Commands

```bash
make test          # Run all tests
make lint-all      # Run linters
make check         # Full validation
```

## Project Structure

- **aws/** — AWS modules (EKS, VPC, RDS, etc.) and Ansible playbooks
- **azure/** — Azure modules (AKS, VNet, etc.)
- **common-modules/** — Shared modules (ArgoCD, GitOps)
- **tests/** — Unit tests
- **scripts/** — Validation scripts

## Contributing

1. Create feature branch: `git checkout -b feature/name`
2. Make changes and commit
3. Run `make test` locally
4. Push and create PR

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.
