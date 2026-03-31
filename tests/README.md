# Unit Tests for Infrastructure Templates

This directory contains the unit test suite for infrastructure-templates.
Tests are organized by component and use lightweight, cost-free tools.

## Test Structure

```text
tests/
├── unit/
│   ├── scripts/           # Shell script validation tests
│   ├── terraform/         # Terraform module validation tests
│   └── helpers.sh         # Common test utilities
├── fixtures/              # Test data and mock files
│   ├── terraform/         # Sample .tf and .liquid files
│   └── liquid/            # Sample liquid templates
├── Makefile               # Test runners
└── README.md              # This file
```

## Prerequisites

### macOS

```bash
# Install bats-core (Bash Automated Testing System)
brew install bats-core

# Verify installation
bats --version
```

### Linux (Ubuntu/Debian)

```bash
# Install bats-core
sudo apt-get update
sudo apt-get install -y bats

# Verify installation
bats --version
```

## Environment Setup

The test infrastructure supports multiple invocation contexts:

- **`env.sh`** — Environment initialization script that exports `ROOT_DIR` and
  `SCRIPTS` variables for non-Make contexts (useful for CI pipelines that
  invoke tests directly via shell)
- **Root Makefile** — Automatically exports environment variables when
  delegating to tests via `make test`
- **tests/Makefile** — Handles test execution with automatic `bats-core` dependency checking

This design allows tests to run consistently whether invoked from:

- Root directory: `make test`
- tests directory: `cd tests && make test`
- CI shell scripts: `source tests/env.sh && bats tests/unit/**/*.bats`

## Running Tests

### Run All Tests

```bash
# From the root infrastructure-templates directory
make test

# Or from tests directory
cd tests
make test
```

### Run Specific Test Suite

```bash
# Test shell script validators
make test-scripts

# Test Terraform modules
make test-terraform

# Test all scripts
bats tests/unit/scripts/*.bats
```

### Run a Single Test File

```bash
bats tests/unit/scripts/test_validate_liquid_templates.bats
```

### Run with Verbose Output

```bash
bats --verbose tests/unit/scripts/*.bats
```

### Run with Tap Output (CI-friendly)

```bash
bats --tap tests/unit/scripts/*.bats
```

## Test Naming Convention

Tests follow bash-style naming:

- File: `test_<component>.bats`
- Test case: `@test "description of what is tested"`

Example:

```bash
@test "validate_liquid_templates.sh rejects unmatched {% if %} tags" {
  # test code
}
```

## Writing New Tests

### Basic Test Structure

```bash
@test "script passes when given valid input" {
  run ./scripts/validate-liquid-templates.sh tests/fixtures/liquid/valid_template.liquid
  [ "$status" -eq 0 ]
}

@test "script fails when given invalid input" {
  run ./scripts/validate-liquid-templates.sh tests/fixtures/liquid/invalid_template.liquid
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unmatched"* ]]
}
```

### Assertions

```bash
# Check exit code
[ "$status" -eq 0 ]        # Success
[ "$status" -ne 0 ]        # Failure

# Check output
[ "$output" = "expected" ]             # Exact match
[[ "$output" == *"substring"* ]]       # Substring match
[[ "$output" =~ regex ]]               # Regex match

# Check file exists
[ -f "$file" ]

# Check file contains text
grep "text" "$file"
```

### Useful Variables in Tests

- `$status` - Exit code of last `run` command
- `$output` - Stdout+Stderr of last `run` command
- `$lines` - Array of output lines (access as `${lines[0]}`, `${lines[1]}`, etc.)

### Setup and Teardown

```bash
setup() {
  # Runs before each test
  TEMPDIR=$(mktemp -d)
}

teardown() {
  # Runs after each test
  rm -rf "$TEMPDIR"
}
```

## Test Coverage Status

### P0 Tests (Critical - must pass)

- ✅ `validate-liquid-templates.sh` validation
- ✅ `check-terraform-naming.sh` validation

### P1 Tests (High priority - in progress)

- ⏳ Terraform module schemas (VPC, security-groups)
- ⏳ Ansible role syntax + idempotency markers
- ⏳ Liquid template rendering

### P2 Tests (Lower priority - future)

- ⏳ Module-specific tests (RDS, ALB, etc.)
- ⏳ Azure module tests
- ⏳ Integration tests

## CI Integration

Tests automatically run on:

- ✅ Local `pre-commit` hooks (future enhancement)
- ✅ GitHub Actions PR checks (`.github/workflows/test.yml`)

View CI results in PR "Checks" tab under "Unit Tests" job.

## Debugging Failed Tests

### See Detailed Output

```bash
# Run with verbose + show all lines
bats --verbose --print-output-on-failure tests/unit/scripts/*.bats
```

### Run Single Test

```bash
# Isolate one test for debugging
bats tests/unit/scripts/test_validate_liquid_templates.bats -f "unmatched if tags"
```

### Inspect Test Fixtures

```bash
# View sample files used in tests
ls -la tests/fixtures/liquid/
cat tests/fixtures/liquid/invalid_template.liquid
```

### Manual Script Testing

```bash
# Test script directly with sample file
./scripts/validate-liquid-templates.sh tests/fixtures/liquid/valid_template.liquid
echo $?  # Show exit code
```

## Troubleshooting

### Issue: `bats: command not found`

**Solution**: Install bats-core

```bash
# macOS
brew install bats-core

# Linux
sudo apt-get install bats
```

### Issue: Tests fail with "file not found"

**Solution**: Tests must be run from repo root or tests directory

```bash
# ✅ Correct
cd infrastructure-templates
make test

# ✅ Also correct
cd infrastructure-templates/tests
make test

# ❌ Won't work
cd tests/unit
bats scripts/*.bats  # Paths to fixtures won't resolve
```

### Issue: Some tests skipped

**Solution**: Check `skip` directives in test file (used for platform-specific tests)

```bash
@test "this test is skipped" {
  skip "Feature not implemented"
  [ 1 -eq 1 ]
}
```

## Contributing Tests

When adding new tests:

1. **Follow naming convention**: `test_<component>.bats`
2. **Test one thing**: Each test should verify a single behavior
3. **Use descriptive names**: Test name should explain the scenario
4. **Create fixtures**: Add sample files to `tests/fixtures/`
5. **Add comments**: Explain complex test logic
6. **Run locally first**: Ensure tests pass before committing

```bash
# Test locally
make test

## Coverage-Driven Test Automation

See: [.copilot-local/docs/COVERAGE-AUTOMATION.md](../.copilot-local/docs/COVERAGE-AUTOMATION.md)

### Quick Reference

```bash
# Check current coverage
make coverage

# Generate gap report
make coverage-report

# Use Copilot to generate tests
/generate-coverage-tests  # (VS Code slash command)

# Validate and commit
make test-unit
git add tests/
git commit
```

### Coverage Thresholds

| Metric | Threshold |
|--------|-----------|
| Lines | 60% |
| Statements | 60% |
| Functions | 55% |
| Branches | 50% |

### Workflow

1. **Develop**: Make code changes
2. **Test**: Run `make test` to generate coverage report
3. **Check**: Run `make coverage` to see current coverage
4. **Gap Analysis**: Run `make coverage-report` if below thresholds
5. **Generate**: Use `/generate-coverage-tests` in Copilot to generate tests
6. **Validate**: Run `make test-unit` to validate new tests
7. **Commit**: Stage and commit when coverage meets thresholds

### Pre-Commit Gate

Git pre-commit hook automatically runs coverage enforcement:

- Blocks commits if coverage drops below thresholds
- Suggests: `make generate-coverage-tests`

### LLM-Assisted Test Generation

Copilot slash command `/generate-coverage-tests`:

- Analyzes gap report
- Generates 3-5 test skeletons per iteration
- Guides recursive test creation
- Stops when thresholds met or plateau detected

## Pre-commit check (future)

```bash
pre-commit run tests --all-files
```

## CI Coverage Targets

| Phase | Deadline | Coverage | Tests |
|-------|----------|----------|-------|
| Phase 1 | Week 2 | 20% | Shell scripts (P0) |
| Phase 2 | Week 4 | 50% | P0 modules |
| Phase 3 | Week 6 | 80% | P0 + P1 modules |
| Phase 4 | Week 8 | 90%+ | P0 + P1 + P2 |

## Related Documentation

- [TESTING.md](../docs/TESTING.md) - User guide to running linters and security scans
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution workflow including running tests
- [testing-standards.md](../.copilot-local/docs/testing-standards.md) - AI agent validation procedures
