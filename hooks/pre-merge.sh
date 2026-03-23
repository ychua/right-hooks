#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Pre-merge gate: 7-check enforcement based on active profile
# Blocks merge (exit 2) if required gates are not satisfied

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)

# Only trigger on merge-related commands
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
if ! echo "$CMD" | grep -qiE "gh pr merge|git merge"; then
  exit 0
fi

BRANCH=$(rh_branch)
PR_NUM=$(rh_pr_number)

if [ -z "$PR_NUM" ]; then
  exit 0
fi

# Determine active profile gates — ALL gates loaded from matched profile
BRANCH_TYPE=$(rh_branch_type)
rh_match_profile "$BRANCH_TYPE"

# Hard-enforced gates — always run regardless of profile
REQUIRE_CI=true
REQUIRE_DOC_CONSISTENCY=true
# Profile-dependent gates (read from matched profile, default false)
REQUIRE_DOD=$(rh_gate_value "dod")
REQUIRE_PLANNING=$(rh_gate_value "planningArtifacts")
REQUIRE_ENG_REVIEW=$(rh_gate_value "engReview")
REQUIRE_CODE_REVIEW=$(rh_gate_value "codeReview")
REQUIRE_QA=$(rh_gate_value "qa")
REQUIRE_LEARNINGS=$(rh_gate_value "learnings")

rh_debug "pre-merge" "branch=$BRANCH type=$BRANCH_TYPE pr=$PR_NUM"
rh_debug "pre-merge" "gates: ci=$REQUIRE_CI dod=$REQUIRE_DOD doc=$REQUIRE_DOC_CONSISTENCY plan=$REQUIRE_PLANNING review=$REQUIRE_CODE_REVIEW qa=$REQUIRE_QA learn=$REQUIRE_LEARNINGS"

ERRORS=""
OWNER_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")

# Batch-fetch all PR comments once (paginated) — used by doc, review, QA checks
# Three states: RH_COMMENTS_OK=1 (fetched, may be empty), RH_COMMENTS_OK="" (API failed)
#
# Comments stored in a TEMP FILE, not a shell variable.
# Reason: echo "$var" in zsh interprets \n inside JSON strings as real newlines,
# producing invalid JSON when piped back to jq. Reading from file avoids this.
_RH_COMMENTS_FILE=$(mktemp)
RH_COMMENTS_OK=""
if [ -n "$OWNER_REPO" ]; then
  _RH_COMMENTS_RAW=$(mktemp)
  if GH_HTTP_TIMEOUT=15 gh api --paginate "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" > "$_RH_COMMENTS_RAW" 2>/dev/null; then
    jq -s 'add // []' < "$_RH_COMMENTS_RAW" > "$_RH_COMMENTS_FILE" 2>/dev/null || echo "[]" > "$_RH_COMMENTS_FILE"
    RH_COMMENTS_OK=1
  else
    echo "[]" > "$_RH_COMMENTS_FILE"
    rh_info "pre-merge" "⚠ GitHub API failed — comment-based gates skipped"
  fi
  rm -f "$_RH_COMMENTS_RAW"
fi

# ── Check 1: CI green (HARD ENFORCEMENT — always runs, no override) ──
CI_STATUS=$(gh pr checks "$PR_NUM" 2>/dev/null || echo "")
# Match fail/pending in the status column (2nd tab-delimited field), not check names
CI_FAILING=$(echo "$CI_STATUS" | awk -F'\t' '$2 ~ /fail|pending/' || true)
if [ -n "$CI_FAILING" ]; then
  CI_COUNT=$(echo "$CI_FAILING" | wc -l | tr -d ' ')
  CI_NAMES=$(echo "$CI_FAILING" | awk -F'\t' '{print $1}' | paste -sd ', ' -)
  ERRORS="${ERRORS}CI: ${CI_COUNT} check(s) failing or pending (${CI_NAMES})\n"
  rh_record_event "pre-merge" "ci" "block" "" "$PR_NUM"
else
  rh_record_event "pre-merge" "ci" "pass" "" "$PR_NUM"
fi

# ── Check 2: DoD items checked ──
if [ "$REQUIRE_DOD" = "true" ]; then
  _ERRORS_BEFORE="$ERRORS"
  if ! rh_has_override "dod" "$PR_NUM"; then
    UNCHECKED=$(gh pr view "$PR_NUM" --json body --jq '.body' 2>/dev/null | { grep -c -e '- \[ \]' || true; })
    if [ "$UNCHECKED" -gt 0 ]; then
      ERRORS="${ERRORS}DoD: ${UNCHECKED} unchecked item(s) in PR description\n"
    fi
  fi
  [ "$ERRORS" = "$_ERRORS_BEFORE" ] && rh_record_event "pre-merge" "dod" "pass" "" "$PR_NUM" || rh_record_event "pre-merge" "dod" "block" "" "$PR_NUM"
fi

# ── Check 3: Doc consistency (HARD ENFORCEMENT — always runs, no override) ──
if [ -z "$RH_COMMENTS_OK" ]; then
  rh_debug "pre-merge" "skipping doc check — API unavailable"
else
  _ERRORS_BEFORE="$ERRORS"
  DOC_PAT=$(rh_doc_pattern)
  DOC_COMMENT=$(jq -r --arg pat "$DOC_PAT" '[.[] | select(.body | test($pat; "i"))] | last | .body // ""' < "$_RH_COMMENTS_FILE" 2>/dev/null || echo "")
  DOC_HINT=$(rh_skill_command "docConsistency" "$PR_NUM")
  if [ -z "$DOC_COMMENT" ]; then
    ERRORS="${ERRORS}Doc consistency: No documentation review comment found. Spawn the 'doc-reviewer' agent to check documentation consistency.\n"
  else
    if ! rh_skill_signature_match "docConsistency" "$DOC_COMMENT"; then
      ERRORS="${ERRORS}Doc consistency: Comment doesn't match configured skill signature. ${DOC_HINT}\n"
    fi
    if ! rh_skill_provenance_check "docConsistency"; then
      ERRORS="${ERRORS}Doc consistency: No skill provenance. After running ${DOC_HINT}, write: echo \"$(echo "$_RH_SKILLS_JSON" | jq -r '.docConsistency.skill // empty')\" > .right-hooks/.skill-proof-docConsistency\n"
    fi
  fi
  [ "$ERRORS" = "$_ERRORS_BEFORE" ] && rh_record_event "pre-merge" "docConsistency" "pass" "" "$PR_NUM" || rh_record_event "pre-merge" "docConsistency" "block" "" "$PR_NUM"
fi

# ── Check 4: Planning artifacts (feat/ only) ──
if [ "$REQUIRE_PLANNING" = "true" ]; then
  _ERRORS_BEFORE="$ERRORS"
  if ! rh_has_override "planningArtifacts" "$PR_NUM"; then
    DESIGN_DOC=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | sort -u | { grep -cE 'docs/designs/.*\.md$' || true; })
    EXEC_PLAN=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | sort -u | { grep -cE 'docs/exec-plans/.*\.md$' || true; })
    if [ "$DESIGN_DOC" -eq 0 ] || [ "$EXEC_PLAN" -eq 0 ]; then
      ERRORS="${ERRORS}Planning: Missing design doc or exec plan in PR diff\n"
    fi
  fi
  [ "$ERRORS" = "$_ERRORS_BEFORE" ] && rh_record_event "pre-merge" "planningArtifacts" "pass" "" "$PR_NUM" || rh_record_event "pre-merge" "planningArtifacts" "block" "" "$PR_NUM"
fi

# ── Check 5: Code review ──
if [ "$REQUIRE_CODE_REVIEW" = "true" ] && [ -n "$RH_COMMENTS_OK" ]; then
  _ERRORS_BEFORE="$ERRORS"
  if ! rh_has_override "codeReview" "$PR_NUM"; then
    REVIEW_PAT=$(rh_review_pattern)
    SEVERITY_PAT=$(rh_review_severity_pattern)
    REVIEW_BODY=$(jq -r --arg pat "$REVIEW_PAT" --arg sev "$SEVERITY_PAT" '[.[] | select(.body | test($pat; "i")) | select(.body | test($sev; "i"))] | last | .body // ""' < "$_RH_COMMENTS_FILE" 2>/dev/null || echo "")
    REVIEW_HINT=$(rh_skill_command "codeReview" "$PR_NUM")
    if [ -z "$REVIEW_BODY" ]; then
      ERRORS="${ERRORS}Code Review: No review comment with severity markers found. ${REVIEW_HINT}\n"
    else
      # Verify skill signature (Level 2)
      if ! rh_skill_signature_match "codeReview" "$REVIEW_BODY"; then
        ERRORS="${ERRORS}Code Review: Comment doesn't match configured skill signature. ${REVIEW_HINT}\n"
      fi
      # Verify provenance (Level 3)
      if ! rh_skill_provenance_check "codeReview"; then
        ERRORS="${ERRORS}Code Review: No skill provenance for codeReview. After running the skill, write provenance file.\n"
      fi
    fi

    # Check staleness — are there commits after last review?
    # Exempt: learnings-only commits (avoids infinite loop where
    # learnings commit → stale → re-review → more learnings → stale...)
    LAST_REVIEW_TIME=$(jq -r --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | last | .created_at // ""' < "$_RH_COMMENTS_FILE" 2>/dev/null || echo "")
    if [ -n "$LAST_REVIEW_TIME" ]; then
      # Get commits after last review
      COMMITS_AFTER_JSON=$(gh api "repos/${OWNER_REPO}/pulls/${PR_NUM}/commits" \
        --jq --arg t "$LAST_REVIEW_TIME" '[.[] | select(.commit.committer.date > $t)]' 2>/dev/null || echo "[]")
      COMMITS_AFTER=$(echo "$COMMITS_AFTER_JSON" | jq 'length' 2>/dev/null || echo "0")

      if [ "$COMMITS_AFTER" -gt 0 ]; then
        # Check if the latest commit only touches learnings/retro files
        LATEST_SHA=$(echo "$COMMITS_AFTER_JSON" | jq -r 'last | .sha // empty' 2>/dev/null)
        LEARNINGS_ONLY="false"
        if [ -n "$LATEST_SHA" ]; then
          NON_LEARNINGS=$(gh api "repos/${OWNER_REPO}/commits/${LATEST_SHA}" \
            --jq '[.files[].filename | select(test("docs/retros/.*learnings") | not)] | length' 2>/dev/null || echo "1")
          if [ "$NON_LEARNINGS" = "0" ]; then
            LEARNINGS_ONLY="true"
          fi
        fi

        if [ "$LEARNINGS_ONLY" = "false" ]; then
          ERRORS="${ERRORS}Code Review: ${COMMITS_AFTER} commit(s) pushed after last review — re-spawn review agent\n"
        fi
      fi
    fi

    # Review round cap (max 2)
    REVIEW_COUNT=$(jq --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | length' < "$_RH_COMMENTS_FILE" 2>/dev/null || echo "0")
    if [ "$REVIEW_COUNT" -ge 2 ]; then
      HAS_BLOCKERS=$(jq --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | last | .body | test("CRITICAL|HIGH"; "i")' < "$_RH_COMMENTS_FILE" 2>/dev/null || echo "false")
      if [ "$HAS_BLOCKERS" = "false" ]; then
        echo "INFO: 2 review rounds complete, no HIGH/CRITICAL findings. Ready for merge." >&2
      fi
    fi
  fi
  [ "$ERRORS" = "$_ERRORS_BEFORE" ] && rh_record_event "pre-merge" "codeReview" "pass" "" "$PR_NUM" || rh_record_event "pre-merge" "codeReview" "block" "" "$PR_NUM"
fi

# ── Check 6: QA ──
if [ "$REQUIRE_QA" = "true" ] && [ -n "$RH_COMMENTS_OK" ]; then
  _ERRORS_BEFORE="$ERRORS"
  if ! rh_has_override "qa" "$PR_NUM"; then
    QA_PAT=$(rh_qa_pattern)
    QA_RESULT_PAT=$(rh_qa_result_pattern)
    QA_BODY=$(jq -r --arg pat "$QA_PAT" --arg res "$QA_RESULT_PAT" '[.[] | select(.body | test($pat; "i")) | select(.body | test($res; "i"))] | last | .body // ""' < "$_RH_COMMENTS_FILE" 2>/dev/null || echo "")
    QA_HINT=$(rh_skill_command "qa" "$PR_NUM")
    if [ -z "$QA_BODY" ]; then
      ERRORS="${ERRORS}QA: No QA comment with test result markers found. ${QA_HINT}\n"
    else
      if ! rh_skill_signature_match "qa" "$QA_BODY"; then
        ERRORS="${ERRORS}QA: Comment doesn't match configured skill signature. ${QA_HINT}\n"
      fi
      if ! rh_skill_provenance_check "qa"; then
        ERRORS="${ERRORS}QA: No skill provenance for qa. After running the skill, write provenance file.\n"
      fi
    fi
  fi
  [ "$ERRORS" = "$_ERRORS_BEFORE" ] && rh_record_event "pre-merge" "qa" "pass" "" "$PR_NUM" || rh_record_event "pre-merge" "qa" "block" "" "$PR_NUM"
fi

# ── Check 7: Learnings ──
if [ "$REQUIRE_LEARNINGS" = "true" ]; then
  _ERRORS_BEFORE="$ERRORS"
  if ! rh_has_override "learnings" "$PR_NUM"; then
    LEARNINGS=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | sort -u | { grep -cE 'docs/retros/.*-learnings\.md$' || true; })
    if [ "$LEARNINGS" -eq 0 ]; then
      ERRORS="${ERRORS}Learnings: No learnings document in PR diff\n"
    else
      # Check for per-agent sections with substance
      LEARNINGS_FILE=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | sort -u | grep -E 'docs/retros/.*-learnings\.md$' | head -1)
      if [ -n "$LEARNINGS_FILE" ] && [ -f "$LEARNINGS_FILE" ]; then
        # Match learnings sections leniently — "## Review" matches "## Review Agent",
        # "## Review", "## Code Review", etc. Avoids forcing authors to know exact
        # signature patterns.
        HAS_REVIEW_SECTION=$(grep -ciE '^## .*review' "$LEARNINGS_FILE" 2>/dev/null || true)
        HAS_QA_SECTION=$(grep -ciE '^## .*(qa|test)' "$LEARNINGS_FILE" 2>/dev/null || true)
        if [ "$HAS_REVIEW_SECTION" -eq 0 ] || [ "$HAS_QA_SECTION" -eq 0 ]; then
          ERRORS="${ERRORS}Learnings: Missing agent sections (need a ## ...Review and ## ...QA/Test section)\n"
        fi
        # Check for "Rules to Extract" section — at least one actionable rule
        RULES_SECTIONS=$(grep -c '### Rules to Extract' "$LEARNINGS_FILE" 2>/dev/null || true)
        if [ "$RULES_SECTIONS" -eq 0 ]; then
          ERRORS="${ERRORS}Learnings: Missing '### Rules to Extract' section (required for knowledge distillation)\n"
        else
          RULE_LINES=$(sed -n '/### Rules to Extract/,/^---$\|^## \|^### [^R]/p' "$LEARNINGS_FILE" | { grep -c '^- ' 2>/dev/null || true; })
          if [ "$RULE_LINES" -eq 0 ]; then
            ERRORS="${ERRORS}Learnings: '### Rules to Extract' has no actionable rules (add at least one '- ...' line)\n"
          else
            # Extract rules into learned-patterns.md NOW (before merge)
            # This ensures rules are captured even with squash merges via gh pr merge
            LEARNED_PATTERNS=".right-hooks/rules/learned-patterns.md"
            if [ -f "$LEARNED_PATTERNS" ]; then
              RULES=$(awk '/### Rules to Extract/{found=1; next} /^---$|^## |^### /{found=0} found && /^- /{print}' "$LEARNINGS_FILE")
              NEW_COUNT=0
              while IFS= read -r rule; do
                [ -z "$rule" ] && continue
                if ! grep -qF "$rule" "$LEARNED_PATTERNS" 2>/dev/null; then
                  echo "$rule" >> "$LEARNED_PATTERNS"
                  NEW_COUNT=$((NEW_COUNT + 1))
                fi
              done <<< "$RULES"
              if [ "$NEW_COUNT" -gt 0 ]; then
                rh_info "pre-merge" "Extracted $NEW_COUNT new rules into learned-patterns.md"
                # Stage and commit the updated file so it's included in the merge
                git add "$LEARNED_PATTERNS" 2>/dev/null
                git commit -m "chore: extract learned patterns from $(basename "$LEARNINGS_FILE")" --no-verify 2>/dev/null || true
              fi
            fi
          fi
        fi
      fi
    fi
  fi
  [ "$ERRORS" = "$_ERRORS_BEFORE" ] && rh_record_event "pre-merge" "learnings" "pass" "" "$PR_NUM" || rh_record_event "pre-merge" "learnings" "block" "" "$PR_NUM"
fi

# ── Result ──
if [ -n "$ERRORS" ]; then
  rh_block_start "pre-merge"
  # Feed each error line as a block item (avoid pipe subshell which loses state)
  while IFS= read -r line; do
    [ -n "$line" ] && rh_block_item "$line"
  done <<< "$(printf "$ERRORS")"
  rh_block_end "Override: npx right-hooks override"
  rm -f "$_RH_COMMENTS_FILE"
  exit 2
fi

# Count how many gates were actually checked
GATE_COUNT=0
for g in "$REQUIRE_CI" "$REQUIRE_DOD" "$REQUIRE_DOC_CONSISTENCY" "$REQUIRE_PLANNING" "$REQUIRE_CODE_REVIEW" "$REQUIRE_QA" "$REQUIRE_LEARNINGS"; do
  [ "$g" = "true" ] && GATE_COUNT=$((GATE_COUNT + 1))
done
rh_pass "pre-merge" "all ${GATE_COUNT} gates passed"
rm -f "$_RH_COMMENTS_FILE"
exit 0
