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
        # Debug-level only — user customizations are legitimate and expected.
        # The upgrade command uses checksums to detect modifications; no need to warn on every run.
        [ "${RH_DEBUG:-}" = "1" ] && echo "RIGHT-HOOKS: Hook $(basename "$RH_HOOK_SELF") checksum differs (customized or updated)" >&2
      fi
    fi
  fi
fi

# ANSI color support — follows NO_COLOR standard (https://no-color.org)
# Colors apply to stderr display text ONLY. Never color JSON stdout.
if [ "${_RH_COLOR_FORCE:-}" = "1" ] || { [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; }; then
  _RH_GREEN='\033[32m'
  _RH_RED='\033[31m'
  _RH_BLUE='\033[34m'
  _RH_DIM='\033[2m'
  _RH_BOLD='\033[1m'
  _RH_RESET='\033[0m'
else
  _RH_GREEN='' _RH_RED='' _RH_BLUE='' _RH_DIM='' _RH_BOLD='' _RH_RESET=''
fi

# Logging helpers — all output to stderr (with color when supported)
# Compact single-line format: 🥊 hook — ✅/🚫 message

# Explain hint — shown after block messages to guide the user
_rh_explain_hint() {
  local gate="${1:-}"
  if [ -n "$gate" ]; then
    printf "  ${_RH_DIM}💡 Run 'npx right-hooks explain %s' for help${_RH_RESET}\n" "$gate"
  else
    printf "  ${_RH_DIM}💡 Run 'npx right-hooks explain' to see all gates${_RH_RESET}\n"
  fi
}

rh_pass() {
  local gate="${3:-}"
  [ -n "$gate" ] && rh_record_event "$1" "$gate" "pass"
  [ "${RH_QUIET:-}" = "1" ] && return
  printf "${_RH_GREEN}🥊 %s — ✅ %s${_RH_RESET}\n" "$1" "$2" >&2
}

# Incremental block API: rh_block_start → rh_block_item → rh_block_end
# Collects items, renders as compact lines (no boxes — Claude Code collapses them)
_RH_BLOCK_HOOK=""
_RH_BLOCK_LINES=""

rh_block_start() {
  _RH_BLOCK_HOOK="$1"
  _RH_BLOCK_LINES=""
}

rh_block_item() {
  _RH_BLOCK_LINES="${_RH_BLOCK_LINES}${1}\n"
}

rh_block_end() {
  local hint="${1:-}"
  printf "${_RH_RED}🥊 %s — 🚫 BLOCKED${_RH_RESET}\n" "$_RH_BLOCK_HOOK" >&2
  printf '%b' "$_RH_BLOCK_LINES" | while IFS= read -r line; do
    [ -n "$line" ] && printf '  %s\n' "$line" >&2
  done
  [ -n "$hint" ] && printf '  %s\n' "$hint" >&2
  _rh_explain_hint >&2
  _RH_BLOCK_HOOK=""
  _RH_BLOCK_LINES=""
}

# Legacy rh_block — one-liner
rh_block() {
  local gate="${3:-}"
  [ -n "$gate" ] && rh_record_event "$1" "$gate" "block"
  printf "${_RH_RED}🥊 %s — 🚫 %s${_RH_RESET}\n" "$1" "$2" >&2
  if [ -n "$gate" ]; then _rh_explain_hint "$gate" >&2; else _rh_explain_hint >&2; fi
}

rh_info() {
  [ "${RH_QUIET:-}" = "1" ] && return
  printf "${_RH_BLUE}🥊 %s — %s${_RH_RESET}\n" "$1" "$2" >&2
}

# Debug helper — only outputs when RH_DEBUG=1
# Usage: rh_debug "hook-name" "message"
rh_debug() {
  [ "${RH_DEBUG:-}" = "1" ] && printf "${_RH_DIM}🥊 DEBUG %-14s → %s${_RH_RESET}\n" "$1" "$2" >&2
  return 0
}

# Event recording for stats — appends JSONL to .right-hooks/.stats/events.jsonl
# Args: hook gate result [stop_reason] [pr] [branch]
# All fields passed by caller — no network calls or subprocess spawns inside.
rh_record_event() {
  local hook="$1" gate="$2" result="$3"
  local stop_reason="${4:-}" pr="${5:-}" branch="${6:-}"
  local ts stats_file event
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  [ -z "$branch" ] && branch="${_RH_BRANCH:-unknown}"
  stats_file=".right-hooks/.stats/events.jsonl"
  mkdir -p "$(dirname "$stats_file")"
  event="{\"ts\":\"$ts\",\"hook\":\"$hook\",\"gate\":\"$gate\",\"result\":\"$result\",\"branch\":\"$branch\""
  [ -n "$pr" ] && event="$event,\"pr\":$pr"
  [ -n "$stop_reason" ] && event="$event,\"stop_reason\":\"$stop_reason\""
  event="$event}"
  echo "$event" >> "$stats_file"
}

# Cache branch name once for recording (avoids subprocess per event)
_RH_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

# Helper: detect gstack/superpowers availability (cached)
_RH_HAS_GSTACK=""
_RH_HAS_SUPERPOWERS=""
rh_has_gstack() {
  if [ -z "$_RH_HAS_GSTACK" ]; then
    if [ -d ".claude/skills/gstack/" ] || [ -d "$HOME/.claude/skills/gstack/" ]; then
      _RH_HAS_GSTACK=true
    else
      _RH_HAS_GSTACK=false
    fi
  fi
  [ "$_RH_HAS_GSTACK" = "true" ]
}

rh_has_superpowers() {
  if [ -z "$_RH_HAS_SUPERPOWERS" ]; then
    if [ -d ".claude/skills/superpowers/" ] || [ -d "$HOME/.claude/skills/superpowers/" ]; then
      _RH_HAS_SUPERPOWERS=true
    else
      _RH_HAS_SUPERPOWERS=false
    fi
  fi
  [ "$_RH_HAS_SUPERPOWERS" = "true" ]
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

# Skill dispatch helper — reads from .right-hooks/skills.json
# Returns a human-readable suggestion for what skill/action to take for a gate.
# 4-tier fallback: configured skill → fallback text → runtime detection → generic
# Usage: rh_skill_command "codeReview" "$PR_NUM"
_RH_SKILLS_JSON=""
_RH_SKILLS_LOADED=""

rh_skill_command() {
  local gate="$1"
  local pr_num="${2:-}"

  # Load and cache skills.json on first call
  if [ -z "$_RH_SKILLS_LOADED" ]; then
    _RH_SKILLS_JSON=$(cat .right-hooks/skills.json 2>/dev/null || echo "{}")
    _RH_SKILLS_LOADED=1
  fi

  # Use jq --arg to prevent injection
  local skill provider
  skill=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].skill // empty' 2>/dev/null)
  provider=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].provider // empty' 2>/dev/null)

  # Tier 1: Configured skill with available provider
  if [ -n "$skill" ]; then
    local available=true
    case "$provider" in
      gstack)      rh_has_gstack      || available=false ;;
      superpowers) rh_has_superpowers  || available=false ;;
    esac
    if [ "$available" = "true" ]; then
      rh_debug "skill" "gate=$gate → skill=$skill (provider=$provider available)"
      echo "Run ${skill}"
      return
    fi
    rh_debug "skill" "gate=$gate → provider=$provider unavailable, falling back"
  fi

  # Tier 2: Fallback text from skills.json (with ${PR_NUM} interpolation)
  local fallback
  fallback=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].fallback // empty' 2>/dev/null)
  if [ -n "$fallback" ]; then
    echo "${fallback//\$\{PR_NUM\}/$pr_num}"
    return
  fi

  # Tier 3: Runtime tool detection (backward compat — no skills.json)
  case "$gate" in
    codeReview)
      if rh_has_gstack; then echo "Run /review"; return; fi
      if rh_has_superpowers; then echo "Run superpowers:requesting-code-review"; return; fi
      ;;
    qa)
      if rh_has_gstack; then echo "Run /qa"; return; fi
      ;;
    docConsistency)
      if rh_has_gstack; then echo "Run /document-release"; return; fi
      ;;
  esac

  # Tier 4: Generic fallback
  echo "Post a comment on the PR"
}

# Skill signature checker — verifies a PR comment matches the configured skill's signature
# Returns 0 if comment matches the skill-specific signature, 1 otherwise
# Usage: rh_skill_signature_match "codeReview" "$COMMENT_BODY"
rh_skill_signature_match() {
  local gate="$1"
  local body="$2"

  # Load skills.json (uses cached value from rh_skill_command if already called)
  if [ -z "$_RH_SKILLS_LOADED" ]; then
    _RH_SKILLS_JSON=$(cat .right-hooks/skills.json 2>/dev/null || echo "{}")
    _RH_SKILLS_LOADED=1
  fi

  local sig
  sig=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].skillSignature // empty' 2>/dev/null)

  if [ -z "$sig" ]; then
    # No skill signature configured — pass (generic/prompt-based mode)
    rh_debug "skill-sig" "gate=$gate — no signature configured, passing"
    return 0
  fi

  if echo "$body" | grep -qiE "$sig"; then
    rh_debug "skill-sig" "gate=$gate — signature matched"
    return 0
  else
    rh_debug "skill-sig" "gate=$gate — signature NOT matched (expected: $sig)"
    return 1
  fi
}

# Skill provenance protocol — verifies the configured skill was actually invoked
# Checks .right-hooks/.skill-proof-{gate} for the skill name
# Returns 0 if provenance matches, 1 otherwise
# Usage: rh_skill_provenance_check "codeReview"
rh_skill_provenance_check() {
  local gate="$1"
  local proof_file=".right-hooks/.skill-proof-${gate}"

  if [ ! -f "$proof_file" ]; then
    rh_debug "skill-proof" "gate=$gate — no provenance file"
    return 1
  fi

  # Load configured skill
  if [ -z "$_RH_SKILLS_LOADED" ]; then
    _RH_SKILLS_JSON=$(cat .right-hooks/skills.json 2>/dev/null || echo "{}")
    _RH_SKILLS_LOADED=1
  fi

  local configured_skill
  configured_skill=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].skill // empty' 2>/dev/null)

  if [ -z "$configured_skill" ]; then
    # No skill configured (prompt-based) — provenance not required
    rh_debug "skill-proof" "gate=$gate — no skill configured, provenance not required"
    return 0
  fi

  local recorded_skill
  recorded_skill=$(cat "$proof_file" 2>/dev/null)

  if [ "$recorded_skill" = "$configured_skill" ]; then
    rh_debug "skill-proof" "gate=$gate — provenance verified: $recorded_skill"
    return 0
  else
    rh_debug "skill-proof" "gate=$gate — provenance MISMATCH: recorded=$recorded_skill configured=$configured_skill"
    return 1
  fi
}

# Skill content loader — reads the full SKILL.md content for a gate
# Used by inject-skill.sh and workflow-orchestrator.sh
# 4-tier fallback: project-local SKILL.md → home SKILL.md → fallback text → generic
# Usage: rh_load_skill_content "codeReview"
rh_load_skill_content() {
  local gate="$1"

  # Load and cache skills.json (reuses same cache as rh_skill_command)
  if [ -z "$_RH_SKILLS_LOADED" ]; then
    _RH_SKILLS_JSON=$(cat .right-hooks/skills.json 2>/dev/null || echo "{}")
    _RH_SKILLS_LOADED=1
  fi

  local skill provider
  skill=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].skill // empty' 2>/dev/null)
  provider=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].provider // empty' 2>/dev/null)

  # Tier 1: Read the actual SKILL.md file
  if [ -n "$skill" ] && [ -n "$provider" ]; then
    local skill_file=""
    local skill_name
    skill_name=$(echo "$skill" | sed 's|^/||')

    for base_dir in ".claude/skills/${provider}" "$HOME/.claude/skills/${provider}"; do
      if [ -f "${base_dir}/SKILL.md" ]; then
        skill_file="${base_dir}/SKILL.md"
        break
      fi
      if [ -f "${base_dir}/${skill_name}/SKILL.md" ]; then
        skill_file="${base_dir}/${skill_name}/SKILL.md"
        break
      fi
    done

    if [ -n "$skill_file" ] && [ -f "$skill_file" ]; then
      rh_debug "skill-content" "gate=$gate → loaded from $skill_file"
      cat "$skill_file"
      return
    fi
  fi

  # Tier 2: Fallback text from skills.json (with ${PR_NUM} interpolation)
  local fallback pr_num
  pr_num=$(rh_pr_number)
  fallback=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].fallback // empty' 2>/dev/null)
  if [ -n "$fallback" ]; then
    rh_debug "skill-content" "gate=$gate → using fallback text"
    echo "${fallback//\$\{PR_NUM\}/$pr_num}"
    return
  fi

  # Tier 3: Generic instruction
  rh_debug "skill-content" "gate=$gate → generic fallback"
  echo "Complete the $gate step for this PR."
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
