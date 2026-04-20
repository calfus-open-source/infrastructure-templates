#!/usr/bin/env bash
# verifier.sh — run tests and re-measure coverage after a patch is applied
# Runs tests up to 3 times to detect flakiness before accepting a patch.
#
# Usage:
#   source tools/lib/verifier.sh
#   verifier_run            # returns 0 if tests pass, 1 if they fail
#   verifier_run_flaky_check  # returns 0 if stable across 3 runs, 1 if flaky

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COVERAGE_REPORT="${COVERAGE_REPORT:-${REPO_ROOT}/coverage/coverage-final.json}"

# ─────────────────────────────────────────────────────────────────────────────
# Run tests once and regenerate coverage
# ─────────────────────────────────────────────────────────────────────────────

verifier_run() {
    echo "[verifier] Running test suite..." >&2

    # Run tests with coverage instrumentation (regenerates coverage-final.json)
    if ! make -C "${REPO_ROOT}" test-coverage --no-print-directory -s 2>/tmp/verifier-err; then
        local err
        err=$(cat /tmp/verifier-err 2>/dev/null | tail -20 || true)
        echo "[verifier] Test suite failed:" >&2
        echo "${err}" >&2
        return 1
    fi

    # Verify coverage report was produced
    if [[ ! -f "${COVERAGE_REPORT}" ]]; then
        echo "[verifier] Coverage report not generated: ${COVERAGE_REPORT}" >&2
        return 1
    fi

    echo "[verifier] Tests passed ✓" >&2
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Flakiness check — run tests 3 times, all must pass
# Called after a new patch is applied to catch non-deterministic tests.
# ─────────────────────────────────────────────────────────────────────────────

verifier_run_flaky_check() {
    echo "[verifier] Flakiness check (3 runs)..." >&2
    local run failures=0

    for run in 1 2 3; do
        if ! make -C "${REPO_ROOT}" test-unit --no-print-directory -s 2>/dev/null; then
            ((failures++))
            echo "[verifier] Run ${run}/3 failed" >&2
        else
            echo "[verifier] Run ${run}/3 passed" >&2
        fi
    done

    if [[ ${failures} -gt 0 ]]; then
        echo "[verifier] Flaky test detected (${failures}/3 runs failed) — patch will be reverted" >&2
        return 1
    fi

    echo "[verifier] Stability confirmed across 3 runs ✓" >&2
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Read current coverage metrics
# ─────────────────────────────────────────────────────────────────────────────

verifier_get_metrics() {
    if ! command -v jq &>/dev/null || [[ ! -f "${COVERAGE_REPORT}" ]]; then
        echo "lines=0 statements=0 functions=0 branches=0"
        return
    fi

    local lines statements functions branches
    lines=$(jq -r '.total.lines.pct // 0' "${COVERAGE_REPORT}")
    statements=$(jq -r '.total.statements.pct // 0' "${COVERAGE_REPORT}")
    functions=$(jq -r '.total.functions.pct // 0' "${COVERAGE_REPORT}")
    branches=$(jq -r '.total.branches.pct // 0' "${COVERAGE_REPORT}")

    echo "lines=${lines} statements=${statements} functions=${functions} branches=${branches}"
}

# Print a formatted coverage summary line
verifier_print_metrics() {
    local metrics
    metrics=$(verifier_get_metrics)
    # shellcheck disable=SC2086
    eval "${metrics}"
    printf "[verifier] Coverage: Lines %.1f%% | Stmts %.1f%% | Funcs %.1f%% | Branches %.1f%%\n" \
        "${lines:-0}" "${statements:-0}" "${functions:-0}" "${branches:-0}" >&2
}
