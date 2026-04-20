#!/usr/bin/env bash
# Coverage utility functions
# Helper functions for coverage tracking, reporting, and comparison

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Files
# shellcheck disable=SC2034
COVERAGE_BASELINE=".coverage-baseline.json"
# shellcheck disable=SC2034
COVERAGE_CURRENT="coverage/coverage-final.json"

# ═══════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════

extract_coverage() {
    local report="$1"
    local metric="$2"  # lines, statements, functions, branches

    [[ ! -f "$report" ]] && { echo ""; return; }
    command -v jq >/dev/null || { echo ""; return; }

    jq -r ".total.${metric}.pct // empty" "$report" 2>/dev/null || echo ""
}

compare_coverage() {
    local old_pct="$1"
    local new_pct="$2"
    # shellcheck disable=SC2034
    local metric_name="$3"

    [[ -z "$old_pct" || -z "$new_pct" ]] && { echo "N/A"; return; }

    local delta
    delta=$(awk "BEGIN {printf \"%.1f\", $new_pct - $old_pct}")
    echo "${delta}"
}

format_coverage_delta() {
    local old="$1"
    local new="$2"

    [[ -z "$old" || -z "$new" ]] && { echo "N/A → N/A"; return; }

    printf "%.1f%% → %.1f%%" "$old" "$new"
}

# ═══════════════════════════════════════════════════════════════════════════
# Coverage Comparison
# ═══════════════════════════════════════════════════════════════════════════

report_coverage_change() {
    local baseline="$1"
    local current="$2"

    [[ ! -f "$baseline" || ! -f "$current" ]] && { echo "Baseline or current coverage unavailable"; return 1; }

    echo "${BOLD}${CYAN}Coverage Change Summary${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for metric in lines statements functions branches; do
        local old
        old=$(extract_coverage "$baseline" "$metric")
        local new
        new=$(extract_coverage "$current" "$metric")
        local delta
        delta=$(compare_coverage "$old" "$new" "$metric")

        if [[ -n "$old" && -n "$new" ]]; then
            local result
            result=$(format_coverage_delta "$old" "$new")
            if (( $(echo "$new < $old" | bc -l 2>/dev/null || echo 0) )); then
                echo "  ${metric^}: ${result} ${YELLOW}(↓${delta}%)${RESET}"
            else
                echo "  ${metric^}: ${result} ${GREEN}(↑${delta}%)${RESET}"
            fi
        fi
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ═══════════════════════════════════════════════════════════════════════════
# Iteration Tracking
# ═══════════════════════════════════════════════════════════════════════════

init_coverage_iteration_log() {
    local logfile="$1"

    cat > "$logfile" << 'EOF'
{
  "iterations": [],
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "in_progress"
}
EOF
}

log_iteration() {
    local logfile="$1"
    local iteration="$2"
    local coverage_pct="$3"
    local tests_added="$4"
    local improvement="$5"

    # Simple JSON append (requires jq for production use)
    echo "Iteration $iteration: ${coverage_pct}% (tests: +$tests_added, delta: $improvement%)" >> "$logfile"
}

# ═══════════════════════════════════════════════════════════════════════════
# Gap Reporting
# ═══════════════════════════════════════════════════════════════════════════

list_coverage_gaps() {
    local report="$1"
    local threshold="$2"  # default 50

    threshold="${threshold:-50}"

    [[ ! -f "$report" ]] && { echo "Report not found"; return 1; }
    command -v jq >/dev/null || { echo "jq required"; return 1; }

    jq -r ".files[] | select(.statements.pct < $threshold) |
        \"  \(.filename): lines=\(.lines.pct)%, stmt=\(.statements.pct)%, func=\(.functions.pct)%, branch=\(.branches.pct)%\"" "$report"
}

# ═══════════════════════════════════════════════════════════════════════════
# Validation
# ═══════════════════════════════════════════════════════════════════════════

is_coverage_improving() {
    local old_pct="$1"
    local new_pct="$2"
    local min_improvement="${3:-2}"  # default 2%

    [[ -z "$old_pct" || -z "$new_pct" ]] && return 1

    local improvement
    improvement=$(awk "BEGIN {printf \"%.1f\", $new_pct - $old_pct}")
    (( $(echo "$improvement >= $min_improvement" | bc -l 2>/dev/null || echo 0) ))
}

meets_threshold() {
    local coverage="$1"
    local threshold="$2"

    [[ -z "$coverage" ]] && return 1
    local int_coverage
    int_coverage=$(printf "%.0f" "${coverage%.*}")
    [[ $int_coverage -ge $threshold ]]
}

# ═══════════════════════════════════════════════════════════════════════════
# Export for sourcing
# ═══════════════════════════════════════════════════════════════════════════

export -f extract_coverage
export -f compare_coverage
export -f format_coverage_delta
export -f report_coverage_change
export -f list_coverage_gaps
export -f is_coverage_improving
export -f meets_threshold
