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

# Determine active profile gates
BRANCH_TYPE=$(rh_branch_type)
PROFILE=$(cat .right-hooks/active-profile.json 2>/dev/null || echo '{}')

# Load profile matching branch type, or try all profiles
REQUIRE_CI=true
REQUIRE_DOD=true
REQUIRE_DOC_CONSISTENCY=true
REQUIRE_PLANNING=false
REQUIRE_ENG_REVIEW=false
REQUIRE_CODE_REVIEW=false
REQUIRE_QA=false
REQUIRE_LEARNINGS=false

# Check profiles for branch type match
for profile_file in .right-hooks/profiles/*.json; do
  [ -f "$profile_file" ] || continue
  MATCHES=$(jq -r --arg bt "$BRANCH_TYPE" '.triggers.branchPrefix // [] | map(gsub("/"; "")) | index($bt)' "$profile_file" 2>/dev/null)
  if [ "$MATCHES" != "null" ] && [ -n "$MATCHES" ]; then
    REQUIRE_PLANNING=$(jq -r '.gates.planningArtifacts // false' "$profile_file" 2>/dev/null)
    REQUIRE_ENG_REVIEW=$(jq -r '.gates.engReview // false' "$profile_file" 2>/dev/null)
    REQUIRE_CODE_REVIEW=$(jq -r '.gates.codeReview // false' "$profile_file" 2>/dev/null)
    REQUIRE_QA=$(jq -r '.gates.qa // false' "$profile_file" 2>/dev/null)
    REQUIRE_LEARNINGS=$(jq -r '.gates.learnings // false' "$profile_file" 2>/dev/null)
    break
  fi
done

ERRORS=""
OWNER_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")

# ── Check 1: CI green ──
if [ "$REQUIRE_CI" = "true" ]; then
  if ! rh_has_override "ci" "$PR_NUM"; then
    CI_FAILURES=$(gh pr checks "$PR_NUM" 2>/dev/null | grep -cE "fail|pending" || echo "0")
    if [ "$CI_FAILURES" -gt 0 ]; then
      ERRORS="${ERRORS}CI: ${CI_FAILURES} check(s) failing or pending\n"
    fi
  fi
fi

# ── Check 2: DoD items checked ──
if [ "$REQUIRE_DOD" = "true" ]; then
  if ! rh_has_override "dod" "$PR_NUM"; then
    UNCHECKED=$(gh pr view "$PR_NUM" --json body --jq '.body' 2>/dev/null | grep -c '- \[ \]' || echo "0")
    if [ "$UNCHECKED" -gt 0 ]; then
      ERRORS="${ERRORS}DoD: ${UNCHECKED} unchecked item(s) in PR description\n"
    fi
  fi
fi

# ── Check 3: Doc consistency ──
if [ "$REQUIRE_DOC_CONSISTENCY" = "true" ]; then
  if ! rh_has_override "docConsistency" "$PR_NUM"; then
    DOC_PAT=$(rh_doc_pattern)
    DOC_CHECK=$(gh api "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" \
      --jq --arg pat "$DOC_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
    if [ "$DOC_CHECK" -eq 0 ]; then
      ERRORS="${ERRORS}Doc consistency: No documentation review comment found\n"
    fi
  fi
fi

# ── Check 4: Planning artifacts (feat/ only) ──
if [ "$REQUIRE_PLANNING" = "true" ]; then
  if ! rh_has_override "planningArtifacts" "$PR_NUM"; then
    DESIGN_DOC=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | grep -cE 'docs/designs/.*\.md$' || echo "0")
    EXEC_PLAN=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | grep -cE 'docs/exec-plans/.*\.md$' || echo "0")
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
    REVIEW=$(gh api "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" \
      --jq --arg pat "$REVIEW_PAT" --arg sev "$SEVERITY_PAT" '[.[] | select(.body | test($pat; "i")) | select(.body | test($sev; "i"))] | length' 2>/dev/null || echo "0")
    if [ "$REVIEW" -eq 0 ]; then
      ERRORS="${ERRORS}Code Review: No review comment with severity markers found\n"
    fi

    # Check staleness — are there commits after last review?
    # Exempt: learnings-only commits (avoids infinite loop where
    # learnings commit → stale → re-review → more learnings → stale...)
    LAST_REVIEW_TIME=$(gh api "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" \
      --jq --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | last | .created_at // ""' 2>/dev/null || echo "")
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
    REVIEW_COUNT=$(gh api "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" \
      --jq --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
    if [ "$REVIEW_COUNT" -ge 2 ]; then
      HAS_BLOCKERS=$(gh api "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" \
        --jq 'last | .body | test("CRITICAL|HIGH"; "i")' 2>/dev/null || echo "false")
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
    QA=$(gh api "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" \
      --jq --arg pat "$QA_PAT" --arg res "$QA_RESULT_PAT" '[.[] | select(.body | test($pat; "i")) | select(.body | test($res; "i"))] | length' 2>/dev/null || echo "0")
    if [ "$QA" -eq 0 ]; then
      ERRORS="${ERRORS}QA: No QA comment with test result markers found\n"
    fi
  fi
fi

# ── Check 7: Learnings ──
if [ "$REQUIRE_LEARNINGS" = "true" ]; then
  if ! rh_has_override "learnings" "$PR_NUM"; then
    LEARNINGS=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | grep -cE 'docs/retros/.*-learnings\.md$' || echo "0")
    if [ "$LEARNINGS" -eq 0 ]; then
      ERRORS="${ERRORS}Learnings: No learnings document in PR diff\n"
    else
      # Check for per-agent sections with substance
      LEARNINGS_FILE=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | grep -E 'docs/retros/.*-learnings\.md$' | head -1)
      if [ -n "$LEARNINGS_FILE" ] && [ -f "$LEARNINGS_FILE" ]; then
        REVIEW_HEADER=$(rh_review_learnings_header)
        QA_HEADER=$(rh_qa_learnings_header)
        HAS_REVIEW_SECTION=$(grep -cF "$REVIEW_HEADER" "$LEARNINGS_FILE" 2>/dev/null || echo "0")
        HAS_QA_SECTION=$(grep -cF "$QA_HEADER" "$LEARNINGS_FILE" 2>/dev/null || echo "0")
        if [ "$HAS_REVIEW_SECTION" -eq 0 ] || [ "$HAS_QA_SECTION" -eq 0 ]; then
          ERRORS="${ERRORS}Learnings: Missing agent sections (need ${REVIEW_HEADER} and ${QA_HEADER})\n"
        fi
        # Check for "Rules to Extract" section — at least one actionable rule
        RULES_SECTIONS=$(grep -c '### Rules to Extract' "$LEARNINGS_FILE" 2>/dev/null || echo "0")
        if [ "$RULES_SECTIONS" -eq 0 ]; then
          ERRORS="${ERRORS}Learnings: Missing '### Rules to Extract' section (required for knowledge distillation)\n"
        else
          RULE_LINES=$(sed -n '/### Rules to Extract/,/^---$\|^## \|^### [^R]/p' "$LEARNINGS_FILE" | grep -c '^- ' 2>/dev/null || echo "0")
          if [ "$RULE_LINES" -eq 0 ]; then
            ERRORS="${ERRORS}Learnings: '### Rules to Extract' has no actionable rules (add at least one '- ...' line)\n"
          fi
        fi
      fi
    fi
  fi
fi

# ── Result ──
if [ -n "$ERRORS" ]; then
  rh_block "pre-merge" "gates not satisfied"
  echo "" >&2
  printf "$ERRORS" >&2
  echo "" >&2
  echo "Override a gate: npx right-hooks override --gate=<gate> --reason=\"...\"" >&2
  exit 2
fi

# Count how many gates were checked
GATE_COUNT=0
for g in ci dod docConsistency planningArtifacts codeReview qa learnings; do
  VAL=$(echo "$PROFILE" | jq -r ".gates.${g} // false" 2>/dev/null)
  [ "$VAL" = "true" ] && GATE_COUNT=$((GATE_COUNT + 1))
done
rh_pass "pre-merge" "all ${GATE_COUNT} gates passed"
exit 0
