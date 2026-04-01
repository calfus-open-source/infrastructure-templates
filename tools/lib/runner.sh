#!/usr/bin/env bash
# runner.sh — deterministic coverage gate loop controller
# Replaces scripts/iterate-coverage.sh (which had an interactive `read -p`).
# The runner owns the loop; the LLM is called only as a controlled skill.
# Never interactive. Never calls read. Safe in pre-commit hooks and CI.
#
# Usage (sourced by tools/coverage-gate):
#   GATE_MODE=local GATE_STAGED_ONLY=1 runner_run
#   GATE_MODE=ci    GATE_NO_LLM=1      runner_run
#   GATE_MODE=manual                   runner_run

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source sibling libs
# shellcheck source=tools/lib/coverage-parser.sh
source "${REPO_ROOT}/tools/lib/coverage-parser.sh"
# shellcheck source=tools/lib/target-selector.sh
source "${REPO_ROOT}/tools/lib/target-selector.sh"
# shellcheck source=tools/lib/verifier.sh
source "${REPO_ROOT}/tools/lib/verifier.sh"

# Loaded lazily in LLM modes
_LIB_LLM="${REPO_ROOT}/tools/lib/llm-generator.sh"
_LIB_PATCHER="${REPO_ROOT}/tools/lib/patch-applier.sh"

# ─────────────────────────────────────────────────────────────────────────────
# Config (populated by _runner_load_config)
# ─────────────────────────────────────────────────────────────────────────────

MAX_ITERATIONS=3
MAX_ITERATIONS_MANUAL=10
TIMEOUT_SECONDS=240
MIN_IMPROVEMENT_PCT=2.0
MAX_PLATEAUS=2
REPORT_DIR=""

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

_pass() { echo -e "${GREEN}[coverage-gate] ✅${RESET} $*"; }
_fail() { echo -e "${RED}[coverage-gate] ❌${RESET} $*"; }
_info() { echo -e "${CYAN}[coverage-gate]${RESET} $*"; }
_warn() { echo -e "${YELLOW}[coverage-gate] ⚠${RESET} $*"; }

_runner_load_config() {
    local cfg="${REPO_ROOT}/.coverage-gate.yaml"
    if command -v yq &>/dev/null && [[ -f "${cfg}" ]]; then
        MAX_ITERATIONS=$(yq '.gate.max_iterations // 3' "${cfg}" 2>/dev/null || echo 3)
        MAX_ITERATIONS_MANUAL=$(yq '.gate.max_iterations_manual // 10' "${cfg}" 2>/dev/null || echo 10)
        # shellcheck disable=SC2034  # consumed by tools/coverage-gate (caller)
        TIMEOUT_SECONDS=$(yq '.gate.timeout_seconds // 240' "${cfg}" 2>/dev/null || echo 240)
        MIN_IMPROVEMENT_PCT=$(yq '.gate.min_improvement_pct // 2.0' "${cfg}" 2>/dev/null || echo 2.0)
        MAX_PLATEAUS=$(yq '.gate.max_plateaus // 2' "${cfg}" 2>/dev/null || echo 2)
    fi

    # Manual mode gets more iterations
    if [[ "${GATE_MODE:-local}" == "manual" ]]; then
        MAX_ITERATIONS="${MAX_ITERATIONS_MANUAL}"
    fi
}

_write_report() {
    local status="$1"   # PASS | FAIL | ERROR
    local iteration="$2"
    local reason="${3:-}"

    local out_dir="${REPORT_DIR:-${REPO_ROOT}}"
    mkdir -p "${out_dir}"

    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Human-readable summary
    {
        echo "# Coverage Gate Report"
        echo ""
        echo "**Status**: ${status}"
        echo "**Mode**: ${GATE_MODE:-local}"
        echo "**Timestamp**: ${ts}"
        echo "**Iterations**: ${iteration}"
        [[ -n "${reason}" ]] && echo "**Reason**: ${reason}"
        echo ""
        echo "## Coverage Metrics"
        echo ""
        if [[ -f "${COVERAGE_REPORT}" ]] && command -v jq &>/dev/null; then
            echo "| Metric | Value | Threshold |"
            echo "|--------|-------|-----------|"
            local l s f b
            l=$(jq -r '.total.lines.pct // 0' "${COVERAGE_REPORT}")
            s=$(jq -r '.total.statements.pct // 0' "${COVERAGE_REPORT}")
            f=$(jq -r '.total.functions.pct // 0' "${COVERAGE_REPORT}")
            b=$(jq -r '.total.branches.pct // 0' "${COVERAGE_REPORT}")
            printf "| Lines      | %.1f%% | 60%% |\n" "${l}"
            printf "| Statements | %.1f%% | 60%% |\n" "${s}"
            printf "| Functions  | %.1f%% | 55%% |\n" "${f}"
            printf "| Branches   | %.1f%% | 50%% |\n" "${b}"
        fi
        echo ""
        if [[ "${status}" == "FAIL" ]]; then
            echo "## Remediation"
            echo ""
            echo "1. Run a manual LLM session:  \`make generate-coverage-tests\`"
            echo "2. Or bypass (logged):        \`SKIP_COVERAGE_GATE=1 git commit\`"
            echo ""
            echo "Gap details: \`.coverage-gaps.json\`"
        fi
    } > "${out_dir}/coverage-gate-report.md"

    # Machine-readable result
    jq -n \
        --arg status "${status}" \
        --arg mode "${GATE_MODE:-local}" \
        --arg ts "${ts}" \
        --argjson iter "${iteration}" \
        --arg reason "${reason}" \
        '{status: $status, mode: $mode, timestamp: $ts, iterations: $iter, reason: $reason}' \
        > "${out_dir}/coverage-gate-result.json" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
# Main loop
# ─────────────────────────────────────────────────────────────────────────────

runner_run() {
    _runner_load_config

    local mode="${GATE_MODE:-local}"
    local no_llm="${GATE_NO_LLM:-0}"
    local staged_only="${GATE_STAGED_ONLY:-0}"

    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  Coverage Gate  [mode: ${mode}]${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    # ── Staged-file skip check (local mode only) ─────────────────────────────
    if [[ "${staged_only}" == "1" ]] && targets_should_skip; then
        _write_report "PASS" 0 "no testable files staged"
        exit 0
    fi

    # ── CI enforce-only mode (no LLM, single pass) ───────────────────────────
    if [[ "${mode}" == "ci" || "${no_llm}" == "1" ]]; then
        _info "Enforce-only mode (no LLM generation)"

        # Regenerate coverage report
        if ! make -C "${REPO_ROOT}" test-coverage --no-print-directory -s 2>/tmp/runner-ci-err; then
            _fail "Test suite failed"
            cat /tmp/runner-ci-err >&2 || true
            _write_report "ERROR" 0 "test suite failed"
            exit 3
        fi

        # Write gap report for artifact upload
        coverage_parse_report --write-gaps 2>/dev/null || true

        if coverage_thresholds_met; then
            _pass "Coverage thresholds met"
            verifier_print_metrics
            _write_report "PASS" 0
            exit 0
        else
            _fail "Coverage below thresholds"
            verifier_print_metrics
            coverage_parse_report --gaps 2>/dev/null || true
            echo ""
            echo "  Remediation: run 'make generate-coverage-tests' locally,"
            echo "  then push a new commit."
            _write_report "FAIL" 0 "thresholds not met"
            exit 1
        fi
    fi

    # ── LLM-assisted mode (local / manual) ───────────────────────────────────

    # Load LLM libs lazily
    # shellcheck source=tools/lib/llm-generator.sh
    source "${_LIB_LLM}"
    # shellcheck source=tools/lib/patch-applier.sh
    source "${_LIB_PATCHER}"

    # Initial measurement
    if ! make -C "${REPO_ROOT}" test-coverage --no-print-directory -s 2>/tmp/runner-cov-err; then
        _fail "Test suite failed before gate could run"
        cat /tmp/runner-cov-err >&2 || true
        _write_report "ERROR" 0 "test suite failed"
        exit 3
    fi

    if coverage_thresholds_met; then
        _pass "Coverage thresholds already met — no generation needed"
        verifier_print_metrics
        _write_report "PASS" 0
        exit 0
    fi

    _warn "Coverage below thresholds — starting LLM-assisted generation"
    verifier_print_metrics
    echo ""

    # Write initial gap report for the LLM
    coverage_parse_report --write-gaps 2>/dev/null || true

    local iteration=0
    local plateau_count=0
    local last_stmts
    last_stmts=$(verifier_get_metrics | grep -o 'statements=[0-9.]*' | cut -d= -f2 || echo 0)
    local tmp_diff
    tmp_diff=$(mktemp /tmp/coverage-gate-diff.XXXXXX)
    trap 'rm -f "${tmp_diff}"' EXIT

    while [[ ${iteration} -lt ${MAX_ITERATIONS} ]]; do
        ((iteration++))
        _info "━━━ Iteration ${iteration}/${MAX_ITERATIONS} ━━━"

        # Generate diff
        if ! llm_generate_tests > "${tmp_diff}" 2>/tmp/runner-llm-err; then
            _warn "LLM generation failed or unavailable"
            cat /tmp/runner-llm-err >&2 || true
            break
        fi

        if [[ ! -s "${tmp_diff}" ]]; then
            _warn "LLM returned empty diff"
            break
        fi

        # Apply patch
        if ! patch_apply "${tmp_diff}"; then
            _warn "Patch rejected (path validation or risk check failed)"
            continue
        fi

        # Verify tests pass and check flakiness
        if ! verifier_run; then
            _warn "Tests failed after patch — reverting"
            patch_revert "${tmp_diff}"
            continue
        fi

        if ! verifier_run_flaky_check; then
            _warn "Flaky tests detected — reverting patch"
            patch_revert "${tmp_diff}"
            continue
        fi

        # Measure improvement
        local current_stmts
        current_stmts=$(verifier_get_metrics | grep -o 'statements=[0-9.]*' | cut -d= -f2 || echo 0)
        local delta
        delta=$(awk "BEGIN {printf \"%.1f\", ${current_stmts} - ${last_stmts}}")
        _info "Coverage Δ: +${delta}% (statements)"
        verifier_print_metrics

        # Update gap report for next iteration
        coverage_parse_report --write-gaps 2>/dev/null || true

        # Threshold check
        if coverage_thresholds_met; then
            _pass "Coverage thresholds met after ${iteration} iteration(s) ✓"
            _write_report "PASS" "${iteration}"
            exit 0
        fi

        # Plateau detection
        local delta_int
        delta_int=$(printf "%.0f" "${delta}")
        if [[ ${delta_int} -lt $(printf "%.0f" "${MIN_IMPROVEMENT_PCT}") ]]; then
            ((plateau_count++))
            _warn "Plateau detected (Δ ${delta}% < ${MIN_IMPROVEMENT_PCT}%) [${plateau_count}/${MAX_PLATEAUS}]"
            if [[ ${plateau_count} -ge ${MAX_PLATEAUS} ]]; then
                _warn "Stopping — coverage plateau reached (remaining gaps may be untestable)"
                break
            fi
        else
            plateau_count=0
        fi

        last_stmts="${current_stmts}"
    done

    # Final check
    if coverage_thresholds_met; then
        _pass "Coverage thresholds met ✓"
        _write_report "PASS" "${iteration}"
        exit 0
    fi

    # Failure path
    _fail "Coverage thresholds not met after ${iteration} iteration(s)"
    verifier_print_metrics
    echo ""
    echo "  Remediation:"
    echo "    1. make generate-coverage-tests   # deeper manual LLM session (10 iterations)"
    echo "    2. SKIP_COVERAGE_GATE=1 git commit # bypass with audit log"
    echo ""
    echo "  Gap details: .coverage-gaps.json"
    echo "  Report:      .coverage-gate-report.md"
    _write_report "FAIL" "${iteration}" "thresholds not met after ${iteration} iterations"
    exit 1
}
