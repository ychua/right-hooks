#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

PREAMBLE="$SCRIPT_DIR/../../../hooks/_preamble.sh"

echo "skill-command"

# Helper: create an isolated repo and cd into it
# Sets REPO to the created directory
new_skills_repo() {
  REPO=$(mktemp -d)
  cd "$REPO"
  mkdir -p .right-hooks
}

# Test 1: Returns configured skill when provider available
describe "returns configured skill when skills.json has skill"
new_skills_repo
mkdir -p .claude/skills/gstack
cat > .right-hooks/skills.json << 'EOF'
{"codeReview":{"skill":"/review","provider":"gstack","fallback":"fallback text"}}
EOF
RESULT=$(RH_TEST=1 bash -c 'source "'"$PREAMBLE"'"; rh_skill_command "codeReview" "42"')
if [ "$RESULT" = "Run /review" ]; then pass; else fail "Expected 'Run /review', got '$RESULT'"; fi
rm -rf "$REPO"

# Test 2: Returns fallback when provider not available
describe "returns fallback when provider missing"
new_skills_repo
# No .claude/skills/gstack dir — override HOME to prevent finding real gstack
cat > .right-hooks/skills.json << 'EOF'
{"codeReview":{"skill":"/review","provider":"gstack","fallback":"Dispatch review for PR #${PR_NUM}"}}
EOF
RESULT=$(HOME="$REPO" RH_TEST=1 bash -c 'source "'"$PREAMBLE"'"; rh_skill_command "codeReview" "42"')
if [ "$RESULT" = "Dispatch review for PR #42" ]; then pass; else fail "Expected fallback with PR_NUM, got '$RESULT'"; fi
rm -rf "$REPO"

# Test 3: Returns runtime detection when skills.json missing
describe "returns runtime detection when skills.json missing"
new_skills_repo
mkdir -p .claude/skills/gstack
# No skills.json
RESULT=$(RH_TEST=1 bash -c 'source "'"$PREAMBLE"'"; rh_skill_command "codeReview" "42"')
if [ "$RESULT" = "Run /review" ]; then pass; else fail "Expected 'Run /review' (runtime), got '$RESULT'"; fi
rm -rf "$REPO"

# Test 4: Returns generic fallback when no tools and no skills.json
describe "returns generic fallback with no tools and no config"
new_skills_repo
# No skills.json, no .claude/skills dirs — override HOME to isolate
RESULT=$(HOME="$REPO" RH_TEST=1 bash -c 'source "'"$PREAMBLE"'"; rh_skill_command "codeReview" "42"')
if [ "$RESULT" = "Post a comment on the PR" ]; then pass; else fail "Expected generic, got '$RESULT'"; fi
rm -rf "$REPO"

# Test 5: Returns fallback when gate key missing from skills.json
describe "returns fallback when gate key missing"
new_skills_repo
cat > .right-hooks/skills.json << 'EOF'
{"qa":{"skill":"/qa","provider":"gstack","fallback":"run qa"}}
EOF
# Override HOME to prevent finding real gstack — tier 3 should also miss
RESULT=$(HOME="$REPO" RH_TEST=1 bash -c 'source "'"$PREAMBLE"'"; rh_skill_command "codeReview" "42"')
if [ "$RESULT" = "Post a comment on the PR" ]; then pass; else fail "Expected generic for missing gate, got '$RESULT'"; fi
rm -rf "$REPO"

# Test 6: Interpolates PR_NUM in fallback text
describe "interpolates PR_NUM in fallback"
new_skills_repo
cat > .right-hooks/skills.json << 'EOF'
{"qa":{"skill":null,"provider":null,"fallback":"Post QA on PR #${PR_NUM}"}}
EOF
RESULT=$(RH_TEST=1 bash -c 'source "'"$PREAMBLE"'"; rh_skill_command "qa" "99"')
if [ "$RESULT" = "Post QA on PR #99" ]; then pass; else fail "Expected PR_NUM=99, got '$RESULT'"; fi
rm -rf "$REPO"

# Test 7: Returns superpowers skill when superpowers available
describe "returns superpowers skill when provider available"
new_skills_repo
mkdir -p .claude/skills/superpowers
cat > .right-hooks/skills.json << 'EOF'
{"codeReview":{"skill":"superpowers:requesting-code-review","provider":"superpowers","fallback":"fallback"}}
EOF
RESULT=$(RH_TEST=1 bash -c 'source "'"$PREAMBLE"'"; rh_skill_command "codeReview" "42"')
if [ "$RESULT" = "Run superpowers:requesting-code-review" ]; then pass; else fail "Expected superpowers skill, got '$RESULT'"; fi
rm -rf "$REPO"

print_summary
