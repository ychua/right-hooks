#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../../hooks/workflow-orchestrator.sh"

echo "workflow-orchestrator"

# Helper: create an isolated git repo with profiles and skills.json
# Usage: new_repo <default_branch> <feature_branch>
new_repo() {
  REPO_DIR=$(mktemp -d)
  cd "$REPO_DIR"
  git init -q -b "$1"
  git config user.email "test@test.com"
  git config user.name "Test"
  git commit --allow-empty -m "init" -q
  git checkout -q -b "$2"

  # Set up profiles (strict for feat/, standard for fix/)
  mkdir -p .right-hooks/profiles
  cat > .right-hooks/profiles/strict.json <<'PROF'
{"name":"strict","triggers":{"branchPrefix":["feat/"]},"gates":{"stopHook":true,"codeReview":true,"qa":true}}
PROF
  cat > .right-hooks/profiles/standard.json <<'PROF'
{"name":"standard","triggers":{"branchPrefix":["fix/","refactor/"]},"gates":{"stopHook":true,"codeReview":true,"qa":true}}
PROF
  cat > .right-hooks/profiles/light.json <<'PROF'
{"name":"light","triggers":{"branchPrefix":["docs/","chore/"]},"gates":{"stopHook":false,"codeReview":false,"qa":false}}
PROF

  # Set up skills.json
  cat > .right-hooks/skills.json <<'SKILLS'
{
  "codeReview": {
    "skill": "/review",
    "provider": "gstack",
    "fallback": "Dispatch a code review subagent for PR #${PR_NUM}"
  },
  "qa": {
    "skill": "/qa",
    "provider": "gstack",
    "fallback": "Dispatch a QA subagent for PR #${PR_NUM}"
  }
}
SKILLS
}

# ============================================================
# Fast-exit tests
# ============================================================

# --- Test 1: Fast-exit for non-Bash tools ---
describe "fast-exits for non-Bash tool (no output)"
new_repo main feat/test1
run_hook "$HOOK" '{"tool_name":"Write","tool_input":{"file_path":"test.ts"}}'
assert_exit_code 0 "$LAST_EXIT"
STDOUT_CONTENT=$(cat "$LAST_STDOUT" 2>/dev/null)
if [ -z "$STDOUT_CONTENT" ]; then
  pass
else
  fail "Expected empty stdout for non-Bash tool, got: $STDOUT_CONTENT"
fi
rm -rf "$REPO_DIR"

# --- Test 2: Fast-exit for irrelevant Bash commands ---
describe "fast-exits for irrelevant Bash command (no output)"
new_repo main feat/test2
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"npm test"}}'
assert_exit_code 0 "$LAST_EXIT"
STDOUT_CONTENT=$(cat "$LAST_STDOUT" 2>/dev/null)
if [ -z "$STDOUT_CONTENT" ]; then
  pass
else
  fail "Expected empty stdout for irrelevant command, got: $STDOUT_CONTENT"
fi
rm -rf "$REPO_DIR"

# --- Test 3: Fast-exit for Edit tool ---
describe "fast-exits for Edit tool (no output)"
new_repo main feat/test3
run_hook "$HOOK" '{"tool_name":"Edit","tool_input":{"file_path":"src/index.ts","old_string":"a","new_string":"b"}}'
assert_exit_code 0 "$LAST_EXIT"
STDOUT_CONTENT=$(cat "$LAST_STDOUT" 2>/dev/null)
if [ -z "$STDOUT_CONTENT" ]; then
  pass
else
  fail "Expected empty stdout for Edit tool, got: $STDOUT_CONTENT"
fi
rm -rf "$REPO_DIR"

# --- Test 4: Fast-exit when command is empty ---
describe "fast-exits when command is empty"
new_repo main feat/test4
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{}}'
assert_exit_code 0 "$LAST_EXIT"
STDOUT_CONTENT=$(cat "$LAST_STDOUT" 2>/dev/null)
if [ -z "$STDOUT_CONTENT" ]; then
  pass
else
  fail "Expected empty stdout for empty command, got: $STDOUT_CONTENT"
fi
rm -rf "$REPO_DIR"

# ============================================================
# Branch-type filtering tests
# ============================================================

# --- Test 5: Fast-exit on docs/ branch (stopHook disabled) ---
describe "fast-exits on docs/ branch (stopHook disabled)"
new_repo main docs/update
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 0 "$LAST_EXIT"
STDOUT_CONTENT=$(cat "$LAST_STDOUT" 2>/dev/null)
if [ -z "$STDOUT_CONTENT" ]; then
  pass
else
  fail "Expected empty stdout on docs/ branch, got: $STDOUT_CONTENT"
fi
rm -rf "$REPO_DIR"

# --- Test 6: Fast-exit on chore/ branch ---
describe "fast-exits on chore/ branch (stopHook disabled)"
new_repo main chore/cleanup
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 0 "$LAST_EXIT"
STDOUT_CONTENT=$(cat "$LAST_STDOUT" 2>/dev/null)
if [ -z "$STDOUT_CONTENT" ]; then
  pass
else
  fail "Expected empty stdout on chore/ branch, got: $STDOUT_CONTENT"
fi
rm -rf "$REPO_DIR"

# --- Test 7: Fast-exit on main branch (not code-review type) ---
describe "fast-exits on main branch"
REPO_DIR=$(mktemp -d)
cd "$REPO_DIR"
git init -q -b main
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" -q
mkdir -p .right-hooks/profiles
cat > .right-hooks/profiles/strict.json <<'PROF'
{"name":"strict","triggers":{"branchPrefix":["feat/"]},"gates":{"stopHook":true,"codeReview":true,"qa":true}}
PROF
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 0 "$LAST_EXIT"
STDOUT_CONTENT=$(cat "$LAST_STDOUT" 2>/dev/null)
if [ -z "$STDOUT_CONTENT" ]; then
  pass
else
  fail "Expected empty stdout on main branch, got: $STDOUT_CONTENT"
fi
rm -rf "$REPO_DIR"

# ============================================================
# PR create trigger tests
# ============================================================

# --- Test 8: gh pr create triggers review injection on feat/ ---
describe "gh pr create triggers systemMessage with review on feat/"
new_repo main feat/new-feature
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title \"Add feature\" --body \"## DoD\""}}'
assert_exit_code 0 "$LAST_EXIT"
assert_stdout_contains "systemMessage" "$LAST_STDOUT"
assert_stdout_contains "code review" "$LAST_STDOUT"
rm -rf "$REPO_DIR"

# --- Test 9: gh pr create triggers review injection on fix/ ---
describe "gh pr create triggers systemMessage on fix/ branch"
new_repo main fix/bugfix
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title \"Fix bug\""}}'
assert_exit_code 0 "$LAST_EXIT"
assert_stdout_contains "systemMessage" "$LAST_STDOUT"
assert_stdout_contains "code review" "$LAST_STDOUT"
rm -rf "$REPO_DIR"

# --- Test 10: gh pr create writes workflow state ---
describe "gh pr create writes workflow state file"
new_repo main feat/state-test
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}'
assert_file_exists ".right-hooks/.workflow-state"
assert_file_contains ".right-hooks/.workflow-state" '"pr_created": true'
rm -rf "$REPO_DIR"

# --- Test 11: systemMessage includes sentinel protocol instructions ---
describe "systemMessage includes sentinel protocol instructions"
new_repo main feat/sentinel-test
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}'
assert_stdout_contains ".review-comment-id" "$LAST_STDOUT"
assert_stdout_contains ".skill-proof-codeReview" "$LAST_STDOUT"
rm -rf "$REPO_DIR"

# ============================================================
# Sentinel write trigger tests
# ============================================================

# --- Test 12: Review sentinel write updates state and triggers QA ---
describe "review sentinel write triggers QA injection"
new_repo main feat/review-done
# Pre-set state: PR created, review not done
mkdir -p .right-hooks
echo '{"pr_created":true,"review_done":false,"qa_done":false,"learnings_done":false,"docs_done":false}' > .right-hooks/.workflow-state
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"echo 12345 > .right-hooks/.review-comment-id"}}'
assert_exit_code 0 "$LAST_EXIT"
assert_stdout_contains "systemMessage" "$LAST_STDOUT"
assert_stdout_contains "QA" "$LAST_STDOUT"
assert_file_contains ".right-hooks/.workflow-state" '"review_done": true'
rm -rf "$REPO_DIR"

# --- Test 13: QA sentinel write updates state and triggers learnings ---
describe "qa sentinel write triggers learnings injection"
new_repo main feat/qa-done
mkdir -p .right-hooks
echo '{"pr_created":true,"review_done":true,"qa_done":false,"learnings_done":false,"docs_done":false}' > .right-hooks/.workflow-state
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"echo 67890 > .right-hooks/.qa-comment-id"}}'
assert_exit_code 0 "$LAST_EXIT"
assert_stdout_contains "systemMessage" "$LAST_STDOUT"
assert_stdout_contains "learnings" "$LAST_STDOUT"
assert_file_contains ".right-hooks/.workflow-state" '"qa_done": true'
rm -rf "$REPO_DIR"

# ============================================================
# Idempotency tests
# ============================================================

# --- Test 14: No re-injection when review already done ---
describe "no re-injection when review already done (idempotent)"
new_repo main feat/idempotent
mkdir -p .right-hooks
echo '{"pr_created":true,"review_done":true,"qa_done":false,"learnings_done":false,"docs_done":false}' > .right-hooks/.workflow-state
# Re-writing the review sentinel shouldn't change review_done state (already true)
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"echo 12345 > .right-hooks/.review-comment-id"}}'
assert_exit_code 0 "$LAST_EXIT"
# State didn't change (review_done was already true) — should still inject QA since qa not done
assert_file_contains ".right-hooks/.workflow-state" '"review_done": true'
rm -rf "$REPO_DIR"

# --- Test 15: No output when all steps are done ---
describe "no output when all workflow steps are complete"
new_repo main feat/all-done
mkdir -p .right-hooks
echo '{"pr_created":true,"review_done":true,"qa_done":true,"learnings_done":true,"docs_done":true}' > .right-hooks/.workflow-state
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 0 "$LAST_EXIT"
# When all steps are done, build_next_step_message returns "" — no systemMessage output
STDOUT_CONTENT=$(cat "$LAST_STDOUT" 2>/dev/null)
if [ -z "$STDOUT_CONTENT" ]; then
  pass
else
  fail "Expected no output when all steps complete, got: $STDOUT_CONTENT"
fi
rm -rf "$REPO_DIR"

# ============================================================
# PR comment trigger tests
# ============================================================

# --- Test 16: gh pr comment nudges toward sentinel protocol ---
describe "gh pr comment nudges toward sentinel protocol"
new_repo main feat/comment-test
mkdir -p .right-hooks
echo '{"pr_created":true,"review_done":false,"qa_done":false,"learnings_done":false,"docs_done":false}' > .right-hooks/.workflow-state
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr comment 42 --body \"Review findings...\""}}'
assert_exit_code 0 "$LAST_EXIT"
assert_stdout_contains "systemMessage" "$LAST_STDOUT"
assert_stdout_contains "sentinel" "$LAST_STDOUT"
rm -rf "$REPO_DIR"

# --- Test 17: gh pr comment no output when review+qa both done ---
describe "gh pr comment no output when review and qa done"
new_repo main feat/comment-done
mkdir -p .right-hooks
echo '{"pr_created":true,"review_done":true,"qa_done":true,"learnings_done":false,"docs_done":false}' > .right-hooks/.workflow-state
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr comment 42 --body \"Extra comment\""}}'
assert_exit_code 0 "$LAST_EXIT"
STDOUT_CONTENT=$(cat "$LAST_STDOUT" 2>/dev/null)
if [ -z "$STDOUT_CONTENT" ]; then
  pass
else
  fail "Expected no output when review+qa done, got: $STDOUT_CONTENT"
fi
rm -rf "$REPO_DIR"

# ============================================================
# Always non-blocking test
# ============================================================

# --- Test 18: Hook never exits with code 2 (non-blocking) ---
describe "hook always exits 0 (never blocks)"
new_repo main feat/never-block
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 0 "$LAST_EXIT"
rm -rf "$REPO_DIR"

# ============================================================
# Fallback content test
# ============================================================

# --- Test 19: Uses fallback text when skill file not found ---
describe "uses fallback text from skills.json when skill file unavailable"
new_repo main feat/fallback-test
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 0 "$LAST_EXIT"
# Since no gstack skills directory exists in test env, should use fallback
assert_stdout_contains "systemMessage" "$LAST_STDOUT"
rm -rf "$REPO_DIR"

# ============================================================
# Skill provenance file detection
# ============================================================

# --- Test 20: Skill provenance file triggers state check ---
describe "skill provenance file detected as sentinel trigger"
new_repo main feat/provenance-test
mkdir -p .right-hooks
echo '{"pr_created":true,"review_done":false,"qa_done":false,"learnings_done":false,"docs_done":false}' > .right-hooks/.workflow-state
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"echo /review > .right-hooks/.skill-proof-codeReview"}}'
assert_exit_code 0 "$LAST_EXIT"
# Provenance file alone doesn't set review_done (that requires the sentinel .review-comment-id)
# But it should still process the trigger path
assert_file_exists ".right-hooks/.workflow-state"
rm -rf "$REPO_DIR"

# ============================================================
# Valid JSON output test
# ============================================================

# --- Test 21: Output is valid JSON when systemMessage present ---
describe "output is valid JSON with systemMessage field"
new_repo main feat/json-test
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}'
if jq -e '.systemMessage' "$LAST_STDOUT" >/dev/null 2>&1; then
  pass
else
  fail "Expected valid JSON with systemMessage field"
  echo "    Actual stdout: $(cat "$LAST_STDOUT" 2>/dev/null)"
fi
rm -rf "$REPO_DIR"

# ============================================================
# Refactor branch test
# ============================================================

# --- Test 22: Works on refactor/ branch ---
describe "triggers on refactor/ branch (standard profile)"
new_repo main refactor/cleanup
run_hook "$HOOK" '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 0 "$LAST_EXIT"
assert_stdout_contains "systemMessage" "$LAST_STDOUT"
rm -rf "$REPO_DIR"

print_summary
