#!/usr/bin/env bash
# patch-applier.sh — safely apply a unified diff to the test directory
# Enforces path restrictions and runs a risk check before applying.
# Reverts automatically if tests fail after application.
#
# Usage:
#   source tools/lib/patch-applier.sh
#   patch_apply <diff_file>        # returns 0 on success, 1 on rejection/failure

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Allowed write root (relative to repo root)
_ALLOWED_WRITE_PREFIX="tests/unit/"

# Paths that must never appear in a diff (checked against +++ lines)
_DENYLIST=(
    ".github/"
    "scripts/"
    "aws/"
    "azure/"
    ".coverage-gate.yaml"
    ".pre-commit-config.yaml"
    "Makefile"
)

_DENYLIST_EXTENSIONS=("*.tf" "*.liquid")

# ─────────────────────────────────────────────────────────────────────────────
# Path validation
# ─────────────────────────────────────────────────────────────────────────────

_validate_diff_paths() {
    local diff_file="$1"
    local violations=0

    while IFS= read -r line; do
        # Only check +++ lines (destination paths)
        [[ "${line}" != "+++ "* ]] && continue

        # Strip "+++ b/" or "+++ " prefix
        local path="${line#+++ }"
        path="${path#b/}"
        path="${path#a/}"

        # /dev/null is fine (deletion)
        [[ "${path}" == "/dev/null" ]] && continue

        # Must be under allowed_write prefix
        if [[ "${path}" != "${_ALLOWED_WRITE_PREFIX}"* ]]; then
            echo "[patch-applier] BLOCKED: path outside allowed_write: ${path}" >&2
            ((violations++))
            continue
        fi

        # Must not match any denylist prefix
        local denied
        for denied in "${_DENYLIST[@]}"; do
            if [[ "${path}" == *"${denied}"* ]]; then
                echo "[patch-applier] BLOCKED: path matches denylist (${denied}): ${path}" >&2
                ((violations++))
            fi
        done

        # Must not match denied extensions
        for ext_pattern in "${_DENYLIST_EXTENSIONS[@]}"; do
            # shellcheck disable=SC2053
            if [[ "${path}" == ${ext_pattern} ]]; then
                echo "[patch-applier] BLOCKED: path matches denied extension (${ext_pattern}): ${path}" >&2
                ((violations++))
            fi
        done
    done < "${diff_file}"

    [[ ${violations} -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Risk check via LLM (optional — skips gracefully if unavailable)
# ─────────────────────────────────────────────────────────────────────────────

_risk_check() {
    local diff_file="$1"

    # Source generator only if not already loaded
    if ! declare -f llm_review_patch &>/dev/null; then
        # shellcheck source=tools/lib/llm-generator.sh
        source "${REPO_ROOT}/tools/lib/llm-generator.sh" 2>/dev/null || return 0
    fi

    local review
    review=$(llm_review_patch "${diff_file}" 2>/dev/null) || return 0

    if [[ -z "${review}" ]]; then
        return 0
    fi

    local verdict
    verdict=$(echo "${review}" | jq -r '.verdict // "PASS"' 2>/dev/null || echo "PASS")

    case "${verdict}" in
        BLOCK)
            echo "[patch-applier] Risk check BLOCKED the patch:" >&2
            echo "${review}" | jq -r '.issues[] | "  [\(.severity)] line \(.line): \(.description)"' 2>/dev/null >&2 || true
            return 1
            ;;
        WARN)
            echo "[patch-applier] Risk check WARNING:" >&2
            echo "${review}" | jq -r '.issues[] | "  [\(.severity)] line \(.line): \(.description)"' 2>/dev/null >&2 || true
            # Warnings don't block — log and continue
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Apply patch
# ─────────────────────────────────────────────────────────────────────────────

patch_apply() {
    local diff_file="$1"

    if [[ ! -f "${diff_file}" ]]; then
        echo "[patch-applier] Diff file not found: ${diff_file}" >&2
        return 1
    fi

    # Check there's actually content
    local diff_lines
    diff_lines=$(grep -c "^@@" "${diff_file}" 2>/dev/null || echo 0)
    if [[ "${diff_lines}" -eq 0 ]]; then
        echo "[patch-applier] Diff is empty — nothing to apply" >&2
        return 0
    fi

    # 1. Validate paths
    if ! _validate_diff_paths "${diff_file}"; then
        echo "[patch-applier] Patch rejected: path validation failed" >&2
        return 1
    fi

    # 2. Risk check
    if ! _risk_check "${diff_file}"; then
        echo "[patch-applier] Patch rejected: risk check failed" >&2
        return 1
    fi

    # 3. Apply with patch (--forward ignores already-applied hunks)
    echo "[patch-applier] Applying patch..." >&2
    if ! patch --forward -p1 -d "${REPO_ROOT}" < "${diff_file}" 2>/tmp/patch-applier-err; then
        local err
        err=$(cat /tmp/patch-applier-err 2>/dev/null || true)
        # "already applied" is not a real error
        if echo "${err}" | grep -q "Reversed (or previously applied)"; then
            echo "[patch-applier] Patch already applied — skipping" >&2
            return 0
        fi
        echo "[patch-applier] patch failed: ${err}" >&2
        return 1
    fi

    echo "[patch-applier] Patch applied successfully" >&2

    # 4. Stage new/modified test files
    local staged_count=0
    while IFS= read -r line; do
        [[ "${line}" != "+++ "* ]] && continue
        local path="${line#+++ }"
        path="${path#b/}"
        [[ "${path}" == "/dev/null" ]] && continue
        if [[ -f "${REPO_ROOT}/${path}" ]]; then
            git -C "${REPO_ROOT}" add "${path}" 2>/dev/null && ((staged_count++)) || true
        fi
    done < "${diff_file}"

    if [[ ${staged_count} -gt 0 ]]; then
        echo "[patch-applier] Staged ${staged_count} test file(s)" >&2
    fi

    return 0
}

# Revert a previously-applied patch (used when tests fail after application)
patch_revert() {
    local diff_file="$1"

    if [[ ! -f "${diff_file}" ]]; then
        return 0
    fi

    echo "[patch-applier] Reverting patch..." >&2
    patch --reverse -p1 -d "${REPO_ROOT}" < "${diff_file}" 2>/dev/null || true

    # Unstage any files that were staged
    while IFS= read -r line; do
        [[ "${line}" != "+++ "* ]] && continue
        local path="${line#+++ }"
        path="${path#b/}"
        [[ "${path}" == "/dev/null" ]] && continue
        git -C "${REPO_ROOT}" restore --staged "${path}" 2>/dev/null || true
        [[ -f "${REPO_ROOT}/${path}" ]] && rm -f "${REPO_ROOT}/${path}" || true
    done < "${diff_file}"
}
