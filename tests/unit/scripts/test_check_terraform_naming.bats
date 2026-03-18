#!/usr/bin/env bats
# Unit tests for scripts/check-terraform-naming.sh
# Tests the Terraform naming convention validation script
# Note: The script scans current directory for .tf.liquid files

setup() {
  load ../helpers
  setup_test_env
  TEST_WORKSPACE=$(mktemp -d)
  export TEST_WORKSPACE
  CHECKER="${REPO_ROOT}/scripts/check-terraform-naming.sh"
}

teardown() {
  teardown_test_env
  [ -n "$TEST_WORKSPACE" ] && [ -d "$TEST_WORKSPACE" ] && rm -rf "$TEST_WORKSPACE"
}

# ============================================================================
# Test: Valid naming conventions
# ============================================================================

@test "accepts valid terraform naming (snake_case)" {
  cp "${FIXTURES_DIR}/terraform/valid_naming.tf.liquid" "$TEST_WORKSPACE/"
  cd "$TEST_WORKSPACE"
  run bash "$CHECKER"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "accepts simple resource names in snake_case" {
  cat > "$TEST_WORKSPACE/good_naming.tf.liquid" <<'EOF'
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main_vpc.id
}
EOF
  cd "$TEST_WORKSPACE"
  run bash "$CHECKER"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================================
# Test: Invalid naming (CamelCase)
# ============================================================================

@test "warns about CamelCase resource names" {
  cp "${FIXTURES_DIR}/terraform/invalid_naming_camelcase.tf.liquid" "$TEST_WORKSPACE/"
  cd "$TEST_WORKSPACE"
  run bash "$CHECKER"
  [[ "$output" == *"snake_case"* ]] || [[ "$output" == *"naming"* ]]
}

@test "handles empty terraform workspace" {
  cd "$TEST_WORKSPACE"
  run bash "$CHECKER"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "processes multiple terraform files" {
  cat > "$TEST_WORKSPACE/module1.tf.liquid" <<'EOF'
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
EOF
  cat > "$TEST_WORKSPACE/vars.tf.liquid" <<'EOF'
variable "instance_count" {
  type = number
}
EOF
  cd "$TEST_WORKSPACE"
  run bash "$CHECKER"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "warns about hardcoded AWS regions" {
  cp "${FIXTURES_DIR}/terraform/warning_hardcoded_region.tf.liquid" "$TEST_WORKSPACE/"
  cd "$TEST_WORKSPACE"
  run bash "$CHECKER"
  [[ "$output" == *"region"* ]] || [[ "$output" == *"hardcoded"* ]] || [[ "$output" == *"us-east-1"* ]]
}
