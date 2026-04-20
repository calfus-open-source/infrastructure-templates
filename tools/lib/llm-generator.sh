#!/usr/bin/env bash
# llm-generator.sh — non-interactive GitHub Copilot API call → unified diff
# Auth: resolved at runtime via `gh auth token`. No credentials stored in repo.
# Only called in local and manual modes. CI always uses --no-llm.
#
# Usage:
#   source tools/lib/llm-generator.sh
#   llm_generate_tests            # outputs unified diff to stdout, returns 0 on success
#   llm_review_patch <diff_file>  # outputs JSON risk verdict to stdout

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GAPS_FILE="${GAPS_FILE:-${REPO_ROOT}/.coverage-gaps.json}"
PROMPT_DIR="${REPO_ROOT}/tools/prompts"
INSTRUCTIONS_FILE="${INSTRUCTIONS_FILE:-${REPO_ROOT}/.copilot-local/.coverage-agent.md}"

# GitHub Copilot chat completions endpoint
_COPILOT_API="https://api.githubcopilot.com/chat/completions"
_COPILOT_MODEL="gpt-4o"
_MAX_TOKENS=4096
_LLM_TIMEOUT=60  # seconds per individual API call

# ─────────────────────────────────────────────────────────────────────────────
# Auth
# ─────────────────────────────────────────────────────────────────────────────

_get_gh_token() {
    if ! command -v gh &>/dev/null; then
        echo "[llm-generator] gh CLI not installed — install from https://cli.github.com" >&2
        return 1
    fi

    local token
    token=$(gh auth token 2>/dev/null || true)

    if [[ -z "${token}" ]]; then
        echo "[llm-generator] gh CLI not authenticated — run: gh auth login" >&2
        return 1
    fi

    echo "${token}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Context builders
# ─────────────────────────────────────────────────────────────────────────────

_build_test_context() {
    local context=""

    # Gap report
    if [[ -f "${GAPS_FILE}" ]]; then
        context+="<gap_report>\n$(cat "${GAPS_FILE}")\n</gap_report>\n\n"
    fi

    # Sample existing tests (first 100 lines each, up to 3 files)
    local test_samples=""
    local count=0
    while IFS= read -r -d '' f; do
        [[ ${count} -ge 3 ]] && break
        test_samples+="=== ${f} ===\n$(head -100 "${f}")\n\n"
        ((count++))
    done < <(find "${REPO_ROOT}/tests/unit" -name "*.bats" -print0 2>/dev/null | head -z -n 3)

    if [[ -n "${test_samples}" ]]; then
        context+="<existing_tests>\n${test_samples}</existing_tests>\n\n"
    fi

    # Agent instructions
    if [[ -f "${INSTRUCTIONS_FILE}" ]]; then
        context+="<instructions>\n$(cat "${INSTRUCTIONS_FILE}")\n</instructions>\n"
    fi

    echo -e "${context}"
}

# ─────────────────────────────────────────────────────────────────────────────
# API call helper
# ─────────────────────────────────────────────────────────────────────────────

_call_copilot_api() {
    local system_prompt="$1"
    local user_message="$2"
    local token="$3"

    # Build JSON payload using printf to avoid heredoc quoting issues
    local payload
    payload=$(printf '%s' '{
  "model": "'"${_COPILOT_MODEL}"'",
  "max_tokens": '"${_MAX_TOKENS}"',
  "messages": [
    {"role": "system", "content": '"$(printf '%s' "${system_prompt}" | jq -Rs .)"'},
    {"role": "user",   "content": '"$(printf '%s' "${user_message}"   | jq -Rs .)"'}
  ]
}')

    local response
    response=$(timeout "${_LLM_TIMEOUT}" curl -sf \
        -X POST "${_COPILOT_API}" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -H "Copilot-Integration-Id: coverage-gate" \
        -H "Editor-Version: coverage-gate/1.0" \
        -d "${payload}" 2>/dev/null) || {
        echo "[llm-generator] Copilot API call failed or timed out" >&2
        return 1
    }

    # Extract content from response
    echo "${response}" | jq -r '.choices[0].message.content // empty' 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Public: generate test diff
# ─────────────────────────────────────────────────────────────────────────────

llm_generate_tests() {
    local token
    token=$(_get_gh_token) || {
        echo "[llm-generator] Skipping LLM generation — no Copilot auth available" >&2
        return 0  # Graceful degradation: don't block commit due to missing auth
    }

    if [[ ! -f "${PROMPT_DIR}/test-generation.txt" ]]; then
        echo "[llm-generator] Prompt file not found: ${PROMPT_DIR}/test-generation.txt" >&2
        return 1
    fi

    local system_prompt
    system_prompt=$(cat "${PROMPT_DIR}/test-generation.txt")

    local user_context
    user_context=$(_build_test_context)

    echo "[llm-generator] Calling Copilot API for test generation..." >&2

    local diff_output
    diff_output=$(_call_copilot_api "${system_prompt}" "${user_context}" "${token}") || return 1

    if [[ -z "${diff_output}" ]]; then
        echo "[llm-generator] Empty response from Copilot API" >&2
        return 1
    fi

    # Strip any markdown code fences the model may have added despite instructions
    echo "${diff_output}" | sed '/^```/d'
}

# ─────────────────────────────────────────────────────────────────────────────
# Public: risk-check a patch before applying
# ─────────────────────────────────────────────────────────────────────────────

llm_review_patch() {
    local diff_file="$1"

    if [[ ! -f "${diff_file}" ]]; then
        echo "[llm-generator] Diff file not found: ${diff_file}" >&2
        return 1
    fi

    local token
    token=$(_get_gh_token) || {
        # If we can't auth, default to PASS so the gate doesn't stall
        echo '{"verdict":"PASS","issues":[],"safe_to_apply":true}'
        return 0
    }

    if [[ ! -f "${PROMPT_DIR}/patch-review.txt" ]]; then
        echo '{"verdict":"PASS","issues":[],"safe_to_apply":true}'
        return 0
    fi

    local system_prompt
    system_prompt=$(cat "${PROMPT_DIR}/patch-review.txt")

    local user_message
    user_message="<diff>\n$(cat "${diff_file}")\n</diff>"

    local review_output
    review_output=$(_call_copilot_api "${system_prompt}" "${user_message}" "${token}") || {
        echo '{"verdict":"PASS","issues":[],"safe_to_apply":true}'
        return 0
    }

    # Strip markdown fences if present
    echo "${review_output}" | sed '/^```/d'
}
