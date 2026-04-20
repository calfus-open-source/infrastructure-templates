#!/usr/bin/env bash
# Common test utilities for infrastructure-templates unit tests
# Source this file in your test files: load "helpers"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Setup test environment (creates temp directory)
setup_test_env() {
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
  export FIXTURES_DIR="${BATS_TEST_DIRNAME}/../fixtures"
  export REPO_ROOT="${BATS_TEST_DIRNAME}/../../.."
}

# Cleanup test environment (removes temp directory)
teardown_test_env() {
  [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

# Assert that a command succeeds
assert_command_succeeds() {
  local cmd=("$@")
  run bash -c "${cmd[*]}"
  # shellcheck disable=SC2154
  if [ "$status" -ne 0 ]; then
    echo "Expected command to succeed but it failed: ${cmd[*]}"
    # shellcheck disable=SC2154
    echo "Output: $output"
    return 1
  fi
}

# Assert that a command fails
assert_command_fails() {
  local cmd=("$@")
  run bash -c "${cmd[*]}"
  # shellcheck disable=SC2154
  if [ "$status" -eq 0 ]; then
    echo "Expected command to fail but it succeeded: ${cmd[*]}"
    # shellcheck disable=SC2154
    echo "Output: $output"
    return 1
  fi
}

# Assert output contains substring
assert_output_contains() {
  local substring="$1"
  if [[ ! "$output" == *"$substring"* ]]; then
    echo "Expected output to contain '$substring' but got:"
    echo "$output"
    return 1
  fi
}

# Assert output does not contain substring
assert_output_not_contains() {
  local substring="$1"
  if [[ "$output" == *"$substring"* ]]; then
    echo "Expected output NOT to contain '$substring' but it was found in:"
    echo "$output"
    return 1
  fi
}

# Assert file exists
assert_file_exists() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "Expected file to exist: $file"
    return 1
  fi
}

# Assert file does not exist
assert_file_not_exists() {
  local file="$1"
  if [ -f "$file" ]; then
    echo "Expected file NOT to exist: $file"
    return 1
  fi
}

# Assert file contains text
assert_file_contains() {
  local file="$1"
  local text="$2"
  if ! grep -q "$text" "$file"; then
    echo "Expected file to contain '$text': $file"
    echo "File contents:"
    cat "$file"
    return 1
  fi
}

# Create a temporary file with content
create_temp_file() {
  local content="$1"
  local tmpfile
  tmpfile=$(mktemp)
  echo "$content" > "$tmpfile"
  echo "$tmpfile"
}

# Create a temporary directory
create_temp_dir() {
  mktemp -d
}

# Print test message (for debugging)
test_message() {
  echo "[TEST] $*" >&2
}

# Print success message
success_message() {
  echo -e "${GREEN}✓${NC} $*" >&2
}

# Print error message
error_message() {
  echo -e "${RED}✗${NC} $*" >&2
}

# Print warning message
warning_message() {
  echo -e "${YELLOW}⚠${NC} $*" >&2
}
