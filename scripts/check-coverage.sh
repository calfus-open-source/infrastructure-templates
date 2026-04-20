#!/usr/bin/env bash
# Coverage check and enforcement script
# Validates coverage against thresholds and identifies gaps
#
# Usage:
#   check-coverage.sh [OPTIONS]
#   check-coverage.sh -r coverage/coverage-final.json -f
#   check-coverage.sh -r coverage/coverage-final.json -g -w gaps.json

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

# Coverage thresholds (from testing-standards.md)
LINES_THRESHOLD=60
STATEMENTS_THRESHOLD=60
FUNCTIONS_THRESHOLD=55
BRANCHES_THRESHOLD=50

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Variables
REPORT_FILE=""
FAIL_ON_BELOW=0
IDENTIFY_GAPS=0
VERBOSE=0
GAPS_FILE=""

# ═══════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════

debug() { [[ ${VERBOSE:-0} -eq 1 ]] && echo -e "${CYAN}[DEBUG]${RESET} $*" >&2 || true; }
info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
pass() { echo -e "${GREEN}✅${RESET} $*"; }
fail() { echo -e "${RED}❌${RESET} $*"; }

usage() {
    cat << EOF
${BOLD}${CYAN}Coverage Check & Analysis${RESET}

Usage: $(basename "$0") [OPTIONS]

Options:
  -r, --report FILE       Path to coverage report (JSON or HTML index)
  -f, --fail-on-below     Exit 1 if coverage below thresholds
  -g, --identify-gaps     Identify and list files with low coverage
  -w, --write-gaps FILE   Write gap analysis to FILE
  -v, --verbose          Verbose output
  -h, --help             Show this help

Examples:
  $(basename "$0") -r coverage/coverage-final.json
  $(basename "$0") -r coverage/coverage-final.json -g
  $(basename "$0") -r coverage/coverage-final.json -f
  $(basename "$0") -r coverage/coverage-final.json -g -w gaps.json

EOF
    exit "$1"
}

# ═══════════════════════════════════════════════════════════════════════════
# Parse Arguments
# ═══════════════════════════════════════════════════════════════════════════

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--report)
            REPORT_FILE="$2"
            shift 2
            ;;
        -f|--fail-on-below)
            FAIL_ON_BELOW=1
            shift
            ;;
        -g|--identify-gaps)
            IDENTIFY_GAPS=1
            shift
            ;;
        -w|--write-gaps)
            GAPS_FILE="$2"
            IDENTIFY_GAPS=1
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            error "Unknown option: $1"
            usage 1
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════
# Main Logic
# ═══════════════════════════════════════════════════════════════════════════

main() {
    if [[ -z "$REPORT_FILE" ]]; then
        echo "${BOLD}${CYAN}Coverage Analysis Tool${RESET}"
        echo
        echo "Setup coverage tools:"
        echo "  • macOS (shell): brew install kcov"
        echo "  • JS/Node:       npm install --save-dev nyc"
        echo "  • Python:        pip install coverage"
        echo
        echo "Run tests with coverage, then:"
        echo "  $(basename "$0") -r coverage/coverage-final.json -g"
        echo
        usage 0
    fi

    if [[ ! -f "$REPORT_FILE" ]]; then
        error "Report file not found: $REPORT_FILE"
        exit 1
    fi

    debug "Reading coverage report: $REPORT_FILE"
    parse_coverage_report "$REPORT_FILE"
}

parse_coverage_report() {
    local report="$1"

    # Check if jq is available for JSON parsing
    if ! command -v jq &>/dev/null; then
        warn "jq not found. Install with: brew install jq"
        evaluate_coverage_fallback "$report"
        return
    fi

    local lines_pct statements_pct functions_pct branches_pct
    lines_pct=$(jq -r '.total.lines.pct // empty' "$report" 2>/dev/null || echo "")
    statements_pct=$(jq -r '.total.statements.pct // empty' "$report" 2>/dev/null || echo "")
    functions_pct=$(jq -r '.total.functions.pct // empty' "$report" 2>/dev/null || echo "")
    branches_pct=$(jq -r '.total.branches.pct // empty' "$report" 2>/dev/null || echo "")

    evaluate_coverage "$lines_pct" "$statements_pct" "$functions_pct" "$branches_pct"

    if [[ $IDENTIFY_GAPS -eq 1 ]]; then
        identify_gaps "$report"
    fi

    if [[ -n "$GAPS_FILE" ]]; then
        write_gaps_file "$report" "$GAPS_FILE"
    fi
}

evaluate_coverage() {
    local lines=$1 statements=$2 functions=$3 branches=$4
    local failed=0

    echo
    echo "$(printf '%s\n' "${BOLD}${CYAN}Coverage Report${RESET}")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Lines
    if [[ -n "$lines" && "$lines" != "null" ]]; then
        lines_int=$(printf "%.0f" "${lines%.*}")
        if [[ $lines_int -lt $LINES_THRESHOLD ]]; then
            fail "Lines:        ${lines}% (threshold: ${LINES_THRESHOLD}%)"
            ((failed++))
        else
            pass "Lines:        ${lines}% (threshold: ${LINES_THRESHOLD}%)"
        fi
    else
        echo "  Lines:        ${YELLOW}Not available${RESET}"
    fi

    # Statements
    if [[ -n "$statements" && "$statements" != "null" ]]; then
        statements_int=$(printf "%.0f" "${statements%.*}")
        if [[ $statements_int -lt $STATEMENTS_THRESHOLD ]]; then
            fail "Statements:   ${statements}% (threshold: ${STATEMENTS_THRESHOLD}%)"
            ((failed++))
        else
            pass "Statements:   ${statements}% (threshold: ${STATEMENTS_THRESHOLD}%)"
        fi
    else
        echo "  Statements:   ${YELLOW}Not available${RESET}"
    fi

    # Functions
    if [[ -n "$functions" && "$functions" != "null" ]]; then
        functions_int=$(printf "%.0f" "${functions%.*}")
        if [[ $functions_int -lt $FUNCTIONS_THRESHOLD ]]; then
            fail "Functions:    ${functions}% (threshold: ${FUNCTIONS_THRESHOLD}%)"
            ((failed++))
        else
            pass "Functions:    ${functions}% (threshold: ${FUNCTIONS_THRESHOLD}%)"
        fi
    else
        echo "  Functions:    ${YELLOW}Not available${RESET}"
    fi

    # Branches
    if [[ -n "$branches" && "$branches" != "null" ]]; then
        branches_int=$(printf "%.0f" "${branches%.*}")
        if [[ $branches_int -lt $BRANCHES_THRESHOLD ]]; then
            fail "Branches:     ${branches}% (threshold: ${BRANCHES_THRESHOLD}%)"
            ((failed++))
        else
            pass "Branches:     ${branches}% (threshold: ${BRANCHES_THRESHOLD}%)"
        fi
    else
        echo "  Branches:     ${YELLOW}Not available${RESET}"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    if [[ $failed -gt 0 ]]; then
        if [[ $FAIL_ON_BELOW -eq 1 ]]; then
            error "$failed coverage metric(s) below threshold"
            exit 1
        else
            warn "$failed coverage metric(s) below threshold"
            info "Run: make generate-coverage-tests"
        fi
    else
        pass "All coverage metrics above thresholds ✓"
    fi
}

identify_gaps() {
    local report="$1"

    info "Identifying low-coverage files..."
    echo
    echo "${BOLD}Files below 50% coverage:${RESET}"
    echo

    if command -v jq &>/dev/null; then
        local gap_output=""
        gap_output=$(jq -r '.files[] | select(.statements.pct < 50) | "\(.filename): \(.statements.pct)% (lines: \(.lines.pct)%)"' "$report" 2>/dev/null || echo "")

        if [[ -n "$gap_output" ]]; then
            echo "$gap_output" | while read -r line; do
                [[ -n "$line" ]] && echo "  $line"
            done
        else
            echo "  (none)"
        fi
    fi
}

write_gaps_file() {
    local report="$1"
    local outfile="$2"

    if ! command -v jq &>/dev/null; then
        warn "jq required for gap file generation"
        return
    fi

    debug "Writing gap analysis to: $outfile"

    jq '{
        timestamp: now | todate,
        thresholds: {
            lines: 60,
            statements: 60,
            functions: 55,
            branches: 50
        },
        current_coverage: .total,
        files_below_50pct: [.files[] | select(.statements.pct < 50)]
    }' "$report" > "$outfile"

    pass "Gap analysis written: $outfile"
}

evaluate_coverage_fallback() {
    local report="$1"
    warn "Fallback parsing (limited accuracy)"
    grep -o '"pct":[0-9.]*' "$report" | head -4 | cut -d: -f2 | while read pct; do
        echo "  Coverage: ${pct}%"
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# Execute
# ═══════════════════════════════════════════════════════════════════════════

main "$@"
