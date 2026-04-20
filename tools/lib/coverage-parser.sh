#!/usr/bin/env bash
# coverage-parser.sh — thin wrapper over scripts/check-coverage.sh
# Outputs structured pass/fail result and writes gap report.
#
# Usage:
#   source tools/lib/coverage-parser.sh
#   coverage_parse_report          # returns 0 if thresholds met, 1 if not
#   coverage_parse_report --gaps   # also write .coverage-gaps.json

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COVERAGE_REPORT="${COVERAGE_REPORT:-${REPO_ROOT}/coverage/coverage-final.json}"
GAPS_FILE="${GAPS_FILE:-${REPO_ROOT}/.coverage-gaps.json}"

# Load thresholds from config if yq is available; fall back to defaults
_load_thresholds() {
    if command -v yq &>/dev/null && [[ -f "${REPO_ROOT}/.coverage-gate.yaml" ]]; then
        LINES_THRESHOLD=$(yq '.coverage.thresholds.lines' "${REPO_ROOT}/.coverage-gate.yaml" 2>/dev/null || echo 60)
        STATEMENTS_THRESHOLD=$(yq '.coverage.thresholds.statements' "${REPO_ROOT}/.coverage-gate.yaml" 2>/dev/null || echo 60)
        FUNCTIONS_THRESHOLD=$(yq '.coverage.thresholds.functions' "${REPO_ROOT}/.coverage-gate.yaml" 2>/dev/null || echo 55)
        BRANCHES_THRESHOLD=$(yq '.coverage.thresholds.branches' "${REPO_ROOT}/.coverage-gate.yaml" 2>/dev/null || echo 50)
    else
        LINES_THRESHOLD=60
        STATEMENTS_THRESHOLD=60
        FUNCTIONS_THRESHOLD=55
        BRANCHES_THRESHOLD=50
    fi
}

# Run the coverage check script; returns its exit code
# Args: [--gaps] [--write-gaps]
coverage_parse_report() {
    _load_thresholds

    local args=(-r "${COVERAGE_REPORT}")

    for arg in "$@"; do
        case "$arg" in
            --gaps)       args+=(-g) ;;
            --write-gaps) args+=(-g -w "${GAPS_FILE}") ;;
            --fail)       args+=(-f) ;;
        esac
    done

    if [[ ! -f "${COVERAGE_REPORT}" ]]; then
        echo "[coverage-parser] Report not found: ${COVERAGE_REPORT}" >&2
        return 1
    fi

    bash "${REPO_ROOT}/scripts/check-coverage.sh" "${args[@]}"
}

# Returns the current coverage percentage for a given metric (lines|statements|functions|branches)
coverage_get_pct() {
    local metric="${1:-statements}"
    if ! command -v jq &>/dev/null || [[ ! -f "${COVERAGE_REPORT}" ]]; then
        echo "0"
        return
    fi
    jq -r ".total.${metric}.pct // 0" "${COVERAGE_REPORT}"
}

# Returns 0 if all thresholds are met, 1 otherwise
coverage_thresholds_met() {
    _load_thresholds
    [[ ! -f "${COVERAGE_REPORT}" ]] && return 1
    command -v jq &>/dev/null || return 1

    local lines statements functions branches
    lines=$(jq -r '.total.lines.pct // 0' "${COVERAGE_REPORT}")
    statements=$(jq -r '.total.statements.pct // 0' "${COVERAGE_REPORT}")
    functions=$(jq -r '.total.functions.pct // 0' "${COVERAGE_REPORT}")
    branches=$(jq -r '.total.branches.pct // 0' "${COVERAGE_REPORT}")

    [[ $(printf "%.0f" "${lines}") -ge ${LINES_THRESHOLD} ]] &&
    [[ $(printf "%.0f" "${statements}") -ge ${STATEMENTS_THRESHOLD} ]] &&
    [[ $(printf "%.0f" "${functions}") -ge ${FUNCTIONS_THRESHOLD} ]] &&
    [[ $(printf "%.0f" "${branches}") -ge ${BRANCHES_THRESHOLD} ]]
}
