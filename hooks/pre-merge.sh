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
RH_ALL_COMMENTS=""
if [ -n "$OWNER_REPO" ]; then
  RH_ALL_COMMENTS=$(GH_HTTP_TIMEOUT=15 gh api --paginate "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" 2>/dev/null | jq -s 'add // []' 2>/dev/null || echo "[]")
  if [ "$RH_ALL_COMMENTS" = "[]" ]; then
    rh_info "pre-merge" "⚠ Could not fetch PR comments — comment-based gates skipped"
  fi
fi

# ── Check 1: CI green (HARD ENFORCEMENT — always runs, no override) ──
CI_FAILURES=$(gh pr checks "$PR_NUM" 2>/dev/null | { grep -cE "fail|pending" || true; })
if [ "$CI_FAILURES" -gt 0 ]; then
  ERRORS="${ERRORS}CI: ${CI_FAILURES} check(s) failing or pending — CI must pass before merge\n"
fi

# ── Check 2: DoD items checked ──
if [ "$REQUIRE_DOD" = "true" ]; then
  if ! rh_has_override "dod" "$PR_NUM"; then
    UNCHECKED=$(gh pr view "$PR_NUM" --json body --jq '.body' 2>/dev/null | { grep -c -e '- \[ \]' || true; })
    if [ "$UNCHECKED" -gt 0 ]; then
      ERRORS="${ERRORS}DoD: ${UNCHECKED} unchecked item(s) in PR description\n"
    fi
  fi
fi

# ── Check 3: Doc consistency (HARD ENFORCEMENT — always runs, no override) ──
DOC_PAT=$(rh_doc_pattern)
DOC_CHECK=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$DOC_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
if [ "$DOC_CHECK" -eq 0 ]; then
  if rh_has_gstack; then
    ERRORS="${ERRORS}Doc consistency: No documentation review comment found. Run /document-release\n"
  else
    ERRORS="${ERRORS}Doc consistency: No documentation review comment found — required for all branches\n"
  fi
fi

# ── Check 4: Planning artifacts (feat/ only) ──
if [ "$REQUIRE_PLANNING" = "true" ]; then
  if ! rh_has_override "planningArtifacts" "$PR_NUM"; then
    DESIGN_DOC=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | sort -u | { grep -cE 'docs/designs/.*\.md$' || true; })
    EXEC_PLAN=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | sort -u | { grep -cE 'docs/exec-plans/.*\.md$' || true; })
    if [ "$DESIGN_DOC" -eq 0 ] || [ "$EXEC_PLAN" -eq 0 ]; then
      ERRORS="${ERRORS}Planning: Missing design doc or exec plan in PR diff\n"
    fi
  fi
fi

# ── Check 5: Code review ──
if [ "$REQUIRE_CODE_REVIEW" = "true" ]; then
  if ! rh_has_override "codeReview" "$PR_NUM"; then
    REVIEW_PAT=$(rh_review_pattern)
    SEVERITY_PAT=$(rh_review_severity_pattern)
    REVIEW=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$REVIEW_PAT" --arg sev "$SEVERITY_PAT" '[.[] | select(.body | test($pat; "i")) | select(.body | test($sev; "i"))] | length' 2>/dev/null || echo "0")
    if [ "$REVIEW" -eq 0 ]; then
      ERRORS="${ERRORS}Code Review: No review comment with severity markers found\n"
    fi

    # Check staleness — are there commits after last review?
    # Exempt: learnings-only commits (avoids infinite loop where
    # learnings commit → stale → re-review → more learnings → stale...)
    LAST_REVIEW_TIME=$(echo "$RH_ALL_COMMENTS" | jq -r --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | last | .created_at // ""' 2>/dev/null || echo "")
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
    REVIEW_COUNT=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
    if [ "$REVIEW_COUNT" -ge 2 ]; then
      HAS_BLOCKERS=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | last | .body | test("CRITICAL|HIGH"; "i")' 2>/dev/null || echo "false")
      if [ "$HAS_BLOCKERS" = "false" ]; then
        echo "INFO: 2 review rounds complete, no HIGH/CRITICAL findings. Ready for merge." >&2
      fi
    fi
  fi
fi

# ── Check 6: QA ──
if [ "$REQUIRE_QA" = "true" ]; then
  if ! rh_has_override "qa" "$PR_NUM"; then
    QA_PAT=$(rh_qa_pattern)
    QA_RESULT_PAT=$(rh_qa_result_pattern)
    QA=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$QA_PAT" --arg res "$QA_RESULT_PAT" '[.[] | select(.body | test($pat; "i")) | select(.body | test($res; "i"))] | length' 2>/dev/null || echo "0")
    if [ "$QA" -eq 0 ]; then
      ERRORS="${ERRORS}QA: No QA comment with test result markers found\n"
    fi
  fi
fi

# ── Check 7: Learnings ──
if [ "$REQUIRE_LEARNINGS" = "true" ]; then
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
              RULES=$(awk '/### Rules to Extract/{found=1; next} found && /^- /{print}' "$LEARNINGS_FILE")
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
fi

# ── Result ──
if [ -n "$ERRORS" ]; then
  rh_block_start "pre-merge"
  # Feed each error line as a block item (avoid pipe subshell which loses state)
  while IFS= read -r line; do
    [ -n "$line" ] && rh_block_item "$line"
  done <<< "$(printf "$ERRORS")"
  rh_block_end "Override: npx right-hooks override"
  exit 2
fi

# Count how many gates were actually checked
GATE_COUNT=0
for g in "$REQUIRE_CI" "$REQUIRE_DOD" "$REQUIRE_DOC_CONSISTENCY" "$REQUIRE_PLANNING" "$REQUIRE_CODE_REVIEW" "$REQUIRE_QA" "$REQUIRE_LEARNINGS"; do
  [ "$g" = "true" ] && GATE_COUNT=$((GATE_COUNT + 1))
done
rh_pass "pre-merge" "all ${GATE_COUNT} gates passed"
exit 0
