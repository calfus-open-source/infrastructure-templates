#!/usr/bin/env bash
# Coverage test validation script
# Validates new test files and checks coverage improvement

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

# shellcheck disable=SC2034
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
# shellcheck disable=SC2034
BOLD='\033[1m'
RESET='\033[0m'

pass() { echo -e "${GREEN}✅${RESET} $*"; }
fail() { echo -e "${RED}❌${RESET} $*"; }
info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

TEST_DIR="${1:-tests/unit}"
REPORT_BEFORE="${2:-.coverage-before.json}"
REPORT_AFTER="${3:-.coverage-after.json}"

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    info "Validating new tests in: $TEST_DIR"

    # Check test syntax
    validate_test_syntax

    # Verify tests are runnable
    validate_tests_run

    # Compare coverage reports
    if [[ -f "$REPORT_BEFORE" && -f "$REPORT_AFTER" ]]; then
        compare_coverage_reports
    fi
}

validate_test_syntax() {
    echo
    info "Checking test syntax..."

    local bash_tests
    bash_tests=$(find "$TEST_DIR" -name "test_*.bats" -o -name "*_test.bats" 2>/dev/null | wc -l)

    if [[ $bash_tests -eq 0 ]]; then
        warn "No BATS test files found"
        return
    fi

    local failed=0
    while IFS= read -r file; do
        if bats --syntax-check "$file" >/dev/null 2>&1; then
            pass "$(basename "$file") - syntax valid"
        else
            fail "$(basename "$file") - syntax error"
            ((failed++))
        fi
    done < <(find "$TEST_DIR" -name "test_*.bats" -o -name "*_test.bats")

    [[ $failed -gt 0 ]] && return 1 || pass "All tests have valid syntax"
}

validate_tests_run() {
    echo
    info "Running tests..."

    if ! command -v bats &>/dev/null; then
        warn "bats not found; skipping test execution"
        return
    fi

    if bats "$TEST_DIR"/test_*.bats 2>/dev/null; then
        pass "All tests passed"
    else
        fail "Some tests failed"
        return 1
    fi
}

compare_coverage_reports() {
    echo
    info "Comparing coverage reports..."

    if ! command -v jq &>/dev/null; then
        warn "jq not available; skipping detailed comparison"
        return
    fi

    local metrics=("lines" "statements" "functions" "branches")
    local improved=0
    local declined=0

    for metric in "${metrics[@]}"; do
        local before
        before=$(jq -r ".total.${metric}.pct // empty" "$REPORT_BEFORE" 2>/dev/null || echo "")
        local after
        after=$(jq -r ".total.${metric}.pct // empty" "$REPORT_AFTER" 2>/dev/null || echo "")

        if [[ -z "$before" || -z "$after" ]]; then
            continue
        fi

        local delta
        delta=$(awk "BEGIN {printf \"%.1f\", $after - $before}")

        if (( $(echo "$delta > 0" | bc -l 2>/dev/null || echo 0) )); then
            pass "${metric^}: ${before}% → ${after}% (Δ +${delta}%)"
            ((improved++))
        elif (( $(echo "$delta < 0" | bc -l 2>/dev/null || echo 0) )); then
            fail "${metric^}: ${before}% → ${after}% (Δ ${delta}%)"
            ((declined++))
        else
            info "${metric^}: ${before}% (no change)"
        fi
    done

    if [[ $declined -eq 0 && $improved -gt 0 ]]; then
        pass "Coverage improved across all metrics"
        return 0
    elif [[ $declined -gt 0 ]]; then
        fail "$declined metric(s) declined"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Execute
# ═══════════════════════════════════════════════════════════════════════════

main "$@"
