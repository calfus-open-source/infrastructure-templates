#!/usr/bin/env bash
# Iterative coverage improvement controller
# Manages recursive test generation until thresholds are met

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

THRESHOLDS_MET=0
MAX_TIME_MINUTES=10
MIN_IMPROVEMENT_PCT=2
MAX_PLATEAUS=2

REPORT_FILE="${1:-coverage/coverage-final.json}"
GAP_REPORT="${2:-.coverage-gaps.json}"
# shellcheck disable=SC2034
ITERATION_LOG="${3:-.coverage-iterations.log}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { echo -e "${GREEN}✅${RESET} $*"; }
fail() { echo -e "${RED}❌${RESET} $*"; }
info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }

# ═══════════════════════════════════════════════════════════════════════════
# Main Iteration Loop
# ═══════════════════════════════════════════════════════════════════════════

main() {
    echo
    echo "${BOLD}${CYAN}Coverage Iteration Controller${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    [[ ! -f "$REPORT_FILE" ]] && { echo "Coverage report not found: $REPORT_FILE"; exit 1; }

    info "Starting coverage improvement iterations"
    info "Gap report: $GAP_REPORT"

    local iteration=0
    local plateau_count=0
    local last_coverage=0
    local start_time
    start_time=$(date +%s)

    while true; do
        ((iteration++))

        # Time budget check
        local elapsed=$(( $(date +%s) - start_time ))
        local elapsed_min=$(( elapsed / 60 ))
        if [[ $elapsed_min -ge $MAX_TIME_MINUTES ]]; then
            warn "Time budget exceeded (${MAX_TIME_MINUTES} min)"
            break
        fi

        info "━━━━━━━━━━━━━━ Iteration $iteration ━━━━━━━━━━━━"

        # Check thresholds
        if check_thresholds_met; then
            info "✓ All coverage thresholds met!"
            THRESHOLDS_MET=1
            break
        fi

        # Generate tests (requires LLM interaction)
        generate_iteration_tests "$iteration"

        # Run tests
        if ! make -s test-unit >/dev/null 2>&1; then
            fail "Tests failed; manual review required"
            break
        fi

        # Measure coverage improvement
        local current_coverage
        current_coverage=$(extract_coverage_pct)
        local delta
        delta=$(awk "BEGIN {printf \"%.1f\", $current_coverage - $last_coverage}")

        info "Coverage: ${last_coverage}% → ${current_coverage}% (Δ +${delta}%)"

        # Check for plateau
        if (( $(echo "$delta < $MIN_IMPROVEMENT_PCT" | bc -l 2>/dev/null || echo 0) )); then
            ((plateau_count++))
            warn "Plateau detected (improvement: ${delta}%) [${plateau_count}/${MAX_PLATEAUS}]"

            if [[ $plateau_count -ge $MAX_PLATEAUS ]]; then
                warn "Coverage plateau - stopping iteration"
                break
            fi
        else
            plateau_count=0
        fi

        last_coverage=$current_coverage

        # Safety: max 20 iterations
        if [[ $iteration -ge 20 ]]; then
            warn "Max iterations (20) reached"
            break
        fi
    done

    # Summary
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ $THRESHOLDS_MET -eq 1 ]]; then
        pass "Coverage thresholds achieved in $iteration iteration(s)"
        exit 0
    else
        warn "Coverage thresholds not met after $iteration iteration(s)"
        warn "Manual test generation may be required"
        exit 1
    fi
}

check_thresholds_met() {
    [[ ! -f "$REPORT_FILE" ]] && return 1

    if ! command -v jq &>/dev/null; then
        warn "jq not available; cannot verify thresholds"
        return 1
    fi

    local all_ok=1

    # Check lines (60%)
    local lines
    lines=$(jq -r '.total.lines.pct // 0' "$REPORT_FILE")
    [[ $(printf "%.0f" "$lines") -lt 60 ]] && all_ok=0

    # Check statements (60%)
    local statements
    statements=$(jq -r '.total.statements.pct // 0' "$REPORT_FILE")
    [[ $(printf "%.0f" "$statements") -lt 60 ]] && all_ok=0

    # Check functions (55%)
    local functions
    functions=$(jq -r '.total.functions.pct // 0' "$REPORT_FILE")
    [[ $(printf "%.0f" "$functions") -lt 55 ]] && all_ok=0

    # Check branches (50%)
    local branches
    branches=$(jq -r '.total.branches.pct // 0' "$REPORT_FILE")
    [[ $(printf "%.0f" "$branches") -lt 50 ]] && all_ok=0

    [[ $all_ok -eq 1 ]]
}

extract_coverage_pct() {
    [[ ! -f "$REPORT_FILE" ]] && { echo 0; return; }
    command -v jq &>/dev/null || { echo 0; return; }

    jq -r '.total.statements.pct // 0' "$REPORT_FILE"
}

generate_iteration_tests() {
    local iter="$1"

    info "→ Use Copilot: /generate-coverage-tests (iteration $iter)"
    info "  Follow prompts to generate 3-5 new tests"
    info "  When complete, press Enter to continue..."

    # In automated mode, this would call Copilot API
    # For now, just pause for user interaction
    read -p "  [Press Enter when tests are ready] " || true
}

# ═══════════════════════════════════════════════════════════════════════════
# Execute
# ═══════════════════════════════════════════════════════════════════════════

main "$@"
