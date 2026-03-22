#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Require planning artifacts (design doc + exec plan) for feat/ branches before PR creation

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)

# Only trigger on PR creation
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
if ! echo "$CMD" | grep -qiE "gh pr create"; then
  exit 0
fi

BRANCH=$(rh_branch)
BRANCH_TYPE=$(rh_branch_type)

# Only enforce on feat/ branches
if [ "$BRANCH_TYPE" != "feat" ]; then
  exit 0
fi

ERRORS=""

# Detect default branch (main or master)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ -z "$DEFAULT_BRANCH" ]; then
  # Fallback: try common names
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    DEFAULT_BRANCH="main"
  elif git rev-parse --verify origin/master >/dev/null 2>&1; then
    DEFAULT_BRANCH="master"
  else
    DEFAULT_BRANCH="main"
  fi
fi
rh_debug "pre-pr-create" "base branch=$DEFAULT_BRANCH"

# Get list of changed files once
CHANGED_FILES=$(git diff --name-only "${DEFAULT_BRANCH}...HEAD" 2>/dev/null || echo "")

# Check for design doc
DESIGN_DOCS=$(echo "$CHANGED_FILES" | { grep -cE 'docs/designs/.*\.md$' || true; })
if [ "$DESIGN_DOCS" -eq 0 ]; then
  ERRORS="${ERRORS}Missing design doc: Add docs/designs/<feature>.md before creating PR\n"
  ERRORS="${ERRORS}  Template: .right-hooks/templates/design-doc.md\n"
fi

# Check for exec plan (also accept superpowers plan files)
EXEC_PLANS=$(echo "$CHANGED_FILES" | { grep -cE 'docs/exec-plans/.*\.md$' || true; })
SP_PLANS=$(echo "$CHANGED_FILES" | { grep -cE 'docs/superpowers/plans/.*\.md$' || true; })
TOTAL_PLANS=$((EXEC_PLANS + SP_PLANS))
if [ "$TOTAL_PLANS" -eq 0 ]; then
  ERRORS="${ERRORS}Missing exec plan: Add docs/exec-plans/<feature>.md or docs/superpowers/plans/<feature>.md before creating PR\n"
  ERRORS="${ERRORS}  Template: .right-hooks/templates/exec-plan.md\n"
fi

# Check that exec plan has Definition of Done
if [ "$TOTAL_PLANS" -gt 0 ]; then
  EXEC_FILE=$(echo "$CHANGED_FILES" | grep -E 'docs/(exec-plans|superpowers/plans)/.*\.md$' | head -1)
  if [ -n "$EXEC_FILE" ] && [ -f "$EXEC_FILE" ]; then
    HAS_DOD=$(grep -ciE 'definition of done|## DoD' "$EXEC_FILE" 2>/dev/null || true)
    HAS_DOD=${HAS_DOD:-0}
    if [ "$HAS_DOD" -eq 0 ]; then
      ERRORS="${ERRORS}Exec plan missing Definition of Done section\n"
    fi
  fi
fi

if [ -n "$ERRORS" ]; then
  rh_block "pre-pr-create" "planning artifacts missing for feat/ branch"
  echo "" >&2
  printf "$ERRORS" >&2
  exit 2
fi

rh_pass "pre-pr-create" "design doc + exec plan found"
exit 0
