# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Shared preamble — sourced by all RIGHT-HOOKS hooks
# Provides dependency checking, graceful degradation, and integrity verification

if [ "${RH_TEST:-}" = "1" ]; then
  # Skip dependency and integrity checks in test mode
  :
else
  # Dependency check — fail open if tools are missing
  for cmd in gh jq git; do
    command -v "$cmd" >/dev/null || { echo "RIGHT-HOOKS: $cmd not found — hook degrading gracefully" >&2; exit 0; }
  done

  # GitHub auth check — fail open if not authenticated
  gh auth status >/dev/null 2>&1 || { echo "RIGHT-HOOKS: gh not authenticated — hook degrading gracefully" >&2; exit 0; }

  # Cross-platform SHA256 helper
  rh_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
      shasum -a 256 "$1" | cut -d' ' -f1
    else
      echo ""
    fi
  }

  # Integrity check (generated hooks only — custom hooks skip this)
  RH_HOOK_SELF="${RH_HOOK_SELF:-}"
  if [ -n "$RH_HOOK_SELF" ]; then
    EXPECTED=$(jq -r --arg f "$(basename "$RH_HOOK_SELF")" '.[$f] // ""' .right-hooks/.checksums 2>/dev/null)
    if [ -n "$EXPECTED" ]; then
      ACTUAL=$(rh_sha256 "$RH_HOOK_SELF" 2>/dev/null)
      if [ -n "$ACTUAL" ] && [ "$ACTUAL" != "$EXPECTED" ]; then
        echo "RIGHT-HOOKS: Hook $(basename "$RH_HOOK_SELF") was modified. Run 'npx right-hooks doctor' to fix." >&2
        # Degrade, don't block — might be a legitimate customization
      fi
    fi
  fi
fi

# Logging helpers — all output to stderr
# Usage: rh_pass "hook-name" "message"
#        rh_block "hook-name" "message"
#        rh_info "hook-name" "message"
rh_pass() {
  [ "${RH_QUIET:-}" = "1" ] && return
  printf '🥊 %-18s → ✓ %s\n' "$1" "$2" >&2
}

rh_block() {
  printf '🥊 %-18s → ✗ %s\n' "$1" "$2" >&2
}

rh_info() {
  [ "${RH_QUIET:-}" = "1" ] && return
  printf '🥊 %-18s → %s\n' "$1" "$2" >&2
}

# Debug helper — only outputs when RH_DEBUG=1
# Usage: rh_debug "hook-name" "message"
rh_debug() {
  [ "${RH_DEBUG:-}" = "1" ] && printf '🥊 DEBUG %-14s → %s\n' "$1" "$2" >&2
  return 0
}

# Helper: get current branch
rh_branch() {
  git branch --show-current 2>/dev/null || echo ""
}

# Helper: get PR number for current branch
rh_pr_number() {
  local branch
  branch=$(rh_branch)
  [ -z "$branch" ] && return
  gh pr list --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null || echo ""
}

# Helper: check if an override exists for a gate
rh_has_override() {
  local gate="$1"
  local pr_num="$2"
  [ -f ".right-hooks/.overrides/${gate}-PR${pr_num}.json" ] && return 0
  return 1
}

# Content signature helpers — read from .right-hooks/signatures.json
rh_review_pattern() {
  jq -r '.codeReview.commentPattern // "Review Agent|Code Review"' \
    .right-hooks/signatures.json 2>/dev/null || echo "Review Agent|Code Review"
}

rh_qa_pattern() {
  jq -r '.qa.commentPattern // "QA Agent|QA Review"' \
    .right-hooks/signatures.json 2>/dev/null || echo "QA Agent|QA Review"
}

rh_review_severity_pattern() {
  jq -r '.codeReview.severityPattern // "CRITICAL|HIGH|MEDIUM|LOW"' \
    .right-hooks/signatures.json 2>/dev/null || echo "CRITICAL|HIGH|MEDIUM|LOW"
}

rh_qa_result_pattern() {
  jq -r '.qa.resultPattern // "tests passing|coverage|Test gaps"' \
    .right-hooks/signatures.json 2>/dev/null || echo "tests passing|coverage|Test gaps"
}

rh_doc_pattern() {
  jq -r '.docConsistency.commentPattern // "Documentation health:"' \
    .right-hooks/signatures.json 2>/dev/null || echo "Documentation health:"
}

rh_review_learnings_header() {
  jq -r '.codeReview.learningsHeader // "## Review"' \
    .right-hooks/signatures.json 2>/dev/null || echo "## Review"
}

rh_qa_learnings_header() {
  jq -r '.qa.learningsHeader // "## QA"' \
    .right-hooks/signatures.json 2>/dev/null || echo "## QA"
}

# Helper: get branch type prefix
rh_branch_type() {
  local branch
  branch=$(rh_branch)
  echo "$branch" | cut -d'/' -f1
}

# Helper: find the most specific profile matching a branch type
# Sets RH_MATCHED_PROFILE to the file path (empty if no match)
# Uses most-specific-match: fewest branch prefixes wins
rh_match_profile() {
  local branch_type="$1"
  RH_MATCHED_PROFILE=""
  local best_count=999

  for profile_file in .right-hooks/profiles/*.json; do
    [ -f "$profile_file" ] || continue
    local matches
    matches=$(jq -r --arg bt "$branch_type" \
      '.triggers.branchPrefix // [] | map(gsub("/"; "")) | index($bt)' \
      "$profile_file" 2>/dev/null)
    if [ "$matches" != "null" ] && [ -n "$matches" ]; then
      local count
      count=$(jq -r '.triggers.branchPrefix | length' "$profile_file" 2>/dev/null || echo "999")
      if [ "$count" -lt "$best_count" ]; then
        best_count="$count"
        RH_MATCHED_PROFILE="$profile_file"
      fi
    fi
  done

  if [ -n "$RH_MATCHED_PROFILE" ]; then
    rh_debug "profile" "matched $RH_MATCHED_PROFILE ($best_count prefixes) for $branch_type"
  fi
}

# Helper: get a gate value from the previously matched profile
# Usage: rh_gate_value "gateName" → "true" or "false"
# Call rh_match_profile first to set RH_MATCHED_PROFILE
rh_gate_value() {
  local gate="$1"
  if [ -n "$RH_MATCHED_PROFILE" ]; then
    jq -r ".gates.${gate} // false" "$RH_MATCHED_PROFILE" 2>/dev/null || echo "false"
  else
    echo "false"
  fi
}
