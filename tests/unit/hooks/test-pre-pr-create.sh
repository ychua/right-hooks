#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../../hooks/pre-pr-create.sh"

echo "pre-pr-create"

# Helper: create an isolated git repo and cd into it
# Sets REPO_DIR to the created directory
# Usage: new_repo <default_branch> <feature_branch>
new_repo() {
  REPO_DIR=$(mktemp -d)
  cd "$REPO_DIR"
  git init -q -b "$1"
  git commit --allow-empty -m "init" -q
  git checkout -q -b "$2"
}

# --- Test 7 ONLY (isolation test for CI debugging) ---
describe "detects design doc with main as default branch"
new_repo main feat/main-test
mkdir -p docs/designs docs/exec-plans
echo "# Design" > docs/designs/main-test.md
printf '# Exec Plan\n\n## Definition of Done\n- [ ] works\n' > docs/exec-plans/main-test.md
git add . && git commit -q -m "add planning docs"
# Diagnostics: verify repo state
DIAG_TOP=$(git rev-parse --show-toplevel 2>&1)
DIAG_BR=$(git branch 2>&1 | tr '\n' ' ')
DIAG_LOG=$(git log --oneline --all 2>&1 | tr '\n' ' ')
DIAG_DIFF=$(git diff --name-only main...HEAD 2>&1 | tr '\n' ' ')
DIAG_PWD=$(pwd)
DIAG_GITDIR=$(git rev-parse --git-dir 2>&1)
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title test"}}'
if [ "$LAST_EXIT" -eq 0 ]; then
  pass
else
  fail "exit=$LAST_EXIT top=$DIAG_TOP br=[$DIAG_BR] log=[$DIAG_LOG] diff=[$DIAG_DIFF] pwd=$DIAG_PWD gitdir=$DIAG_GITDIR"
fi
rm -rf "$REPO_DIR"

print_summary
