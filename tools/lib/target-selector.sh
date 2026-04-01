#!/usr/bin/env bash
# target-selector.sh — identify which source files are relevant for this gate run
# In --staged-only mode, filters to files changed in the current git index.
# Used by runner.sh to decide whether to skip the gate entirely (no testable changes).
#
# Usage:
#   source tools/lib/target-selector.sh
#   targets_get_staged_sources    # prints source file paths, one per line
#   targets_should_skip           # returns 0 if gate should be skipped

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# File extensions/patterns that are considered testable source files.
# Changes to these files may affect coverage and warrant running the gate.
_TESTABLE_PATTERNS=(
    "scripts/"
    "aws/"
    "azure/"
    "ansible/"
    "tests/"
    "*.sh"
    "*.tf"
    "*.liquid"
    "*.py"
    "*.js"
    "*.ts"
)

# Print staged source files that match testable patterns.
# Returns nothing if not in a git repo or no staged files match.
targets_get_staged_sources() {
    if ! git -C "${REPO_ROOT}" rev-parse --git-dir &>/dev/null 2>&1; then
        return 0
    fi

    local staged
    staged=$(git -C "${REPO_ROOT}" diff --cached --name-only 2>/dev/null || true)

    if [[ -z "${staged}" ]]; then
        return 0
    fi

    local file
    while IFS= read -r file; do
        [[ -z "${file}" ]] && continue
        if _is_testable_file "${file}"; then
            echo "${file}"
        fi
    done <<< "${staged}"
}

# Returns 0 (skip) if no staged testable files exist and mode is --staged-only.
# Returns 1 (do not skip) if there are staged testable files or mode is not staged-only.
targets_should_skip() {
    local mode="${GATE_MODE:-local}"
    local staged_only="${GATE_STAGED_ONLY:-0}"

    # CI and manual modes never skip based on staged files
    if [[ "${mode}" != "local" || "${staged_only}" != "1" ]]; then
        return 1
    fi

    local count
    count=$(targets_get_staged_sources | wc -l | tr -d ' ')

    if [[ "${count}" -eq 0 ]]; then
        echo "[coverage-gate] No testable source files staged — skipping coverage gate" >&2
        return 0
    fi

    return 1
}

_is_testable_file() {
    local file="$1"

    # Always include test file changes
    [[ "${file}" == tests/* ]] && return 0
    [[ "${file}" == scripts/* ]] && return 0
    [[ "${file}" == aws/* ]] && return 0
    [[ "${file}" == azure/* ]] && return 0
    [[ "${file}" == ansible/* ]] && return 0

    # Include by extension
    case "${file}" in
        *.sh|*.tf|*.liquid|*.py|*.js|*.ts) return 0 ;;
    esac

    # Exclude pure config/doc/meta changes
    case "${file}" in
        .github/*|*.md|*.yaml|*.yml|*.json|*.lock|Makefile|*.txt) return 1 ;;
    esac

    return 1
}

# Print a human-readable summary of what's staged
targets_print_summary() {
    local files
    files=$(targets_get_staged_sources)
    local count
    count=$(echo "${files}" | grep -c . 2>/dev/null || echo 0)

    if [[ "${count}" -eq 0 ]]; then
        echo "[coverage-gate] Staged testable files: none"
    else
        echo "[coverage-gate] Staged testable files (${count}):"
        echo "${files}" | while IFS= read -r f; do
            [[ -n "${f}" ]] && echo "  • ${f}"
        done
    fi
}
