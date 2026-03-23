# OSS Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare right-hooks for public npm publish with community infrastructure, discoverable help system, ANSI colors, and polished first-run experience.

**Architecture:** Three layers of work: (1) shared gate registry (`src/gates.js`) that `explain`, `status`, and `doctor` all use, (2) ANSI colors + block hints in `_preamble.sh` affecting all 12 hooks, (3) community files and README reposition. The gate registry is the foundation — build it first, then everything else builds on top.

**Tech Stack:** Node.js (CLI commands), Bash (hooks/preamble), GitHub YAML (issue templates)

---

## File Structure

**New files:**
- `src/gates.js` — Shared gate registry: descriptions, how-to-satisfy, how-to-override for all 10 gates. Validates against `profiles/*.json` at load.
- `src/explain.js` — CLI command: `explain <gate>` for specific gate, `explain` for interactive listing.
- `CONTRIBUTING.md` — How to contribute (dev setup, test running, PR process).
- `CHANGELOG.md` — Version history (v1.0.0 entry + all prior features).
- `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1.
- `SECURITY.md` — Responsible disclosure policy.
- `.github/ISSUE_TEMPLATE/bug-report.yml` — Structured bug report template.
- `.github/ISSUE_TEMPLATE/feature-request.yml` — Structured feature request template.
- `.github/PULL_REQUEST_TEMPLATE.md` — PR checklist.
- `tests/unit/cli/test-explain.sh` — Unit tests for explain command.
- `tests/unit/cli/test-gates.sh` — Unit tests for gate registry.
- `tests/unit/hooks/test-colors.sh` — Unit tests for ANSI color output.

**Modified files:**
- `hooks/_preamble.sh` — ANSI color variables, `_rh_explain_hint()` helper, color in `rh_pass`/`rh_block`/`rh_info`/`rh_debug`, hint in `rh_block()`/`rh_block_end()`.
- `bin/right-hooks.js` — Add `explain` command dispatch.
- `src/init.js` — Add GitHub check before install.
- `src/doctor.js` — Validate gate names against registry.
- `src/status.js` — Use gate descriptions from registry.
- `hooks/pre-merge.sh` — Rich block messages with gate context, explain hint in `rh_block_end`.
- `hooks/stop-check.sh` — Rich block messages, explain hint.
- `hooks/pre-pr-create.sh` — Explain hint in block message.
- `hooks/post-edit-check.sh` — Explain hint in block message.
- `hooks/pre-push-master.sh` — Explain hint in block message.
- `package.json` — Fix `prepare` script, fix `description`.
- `README.md` — Reposition as Claude Code-first with gstack as integration.

**Deleted files:**
- `feature.ts` — Junk file at root ("feature code").
- `hooks/.!76736!pre-merge.sh` — Corrupted temp file.

**Moved files (docs reorg):**
- `docs/designs/*` → `docs/internal/designs/*`
- `docs/exec-plans/*` → `docs/internal/exec-plans/*`
- `docs/retros/*` → `docs/internal/retros/*`
- `docs/superpowers/*` → `docs/internal/superpowers/*`

## Definition of Done

- [ ] All 309+ existing tests still pass
- [ ] 30+ new tests pass (explain, gates, colors)
- [ ] `npm pack --dry-run` shows no junk files
- [ ] `npx right-hooks explain ci` prints description, how-to, override instructions
- [ ] `npx right-hooks explain` lists all 10 gates with enabled/disabled per profile
- [ ] Block messages include explain hint
- [ ] Colors appear in TTY, suppressed with `NO_COLOR=1`
- [ ] `npx right-hooks init` on non-GitHub repo gives clear error
- [ ] CONTRIBUTING.md, CHANGELOG.md, CODE_OF_CONDUCT.md, SECURITY.md exist
- [ ] GitHub issue templates and PR template exist
- [ ] README positions Claude Code first, gstack as integration
- [ ] Historical docs moved to `docs/internal/`
- [ ] `package.json` prepare script doesn't fail for npm consumers

---

### Task 1: Branch + Cleanup

**Files:**
- Delete: `feature.ts`
- Delete: `hooks/.!76736!pre-merge.sh`
- Modify: `package.json`

- [ ] **Step 1: Create branch**

```bash
git checkout -b chore/oss-readiness
```

- [ ] **Step 2: Delete junk files and stale worktree**

```bash
rm feature.ts
rm "hooks/.!76736!pre-merge.sh"
rm -rf .claude/worktrees/agent-a053469c
```

- [ ] **Step 3: Fix package.json**

In `package.json`, change two fields:

```json
"description": "Lifecycle enforcement hooks for autonomous AI coding agents — ensures every PR goes through design, review, QA, and documentation before merge",
"prepare": "husky || true"
```

The `prepare` change is critical: without `|| true`, `npm install right-hooks` fails for consumers who don't have husky (it's a devDependency, not shipped to consumers).

- [ ] **Step 4: Verify npm pack looks clean**

```bash
npm pack --dry-run 2>&1 | grep -v "^npm notice" | head -5
```

Expected: No `.!76736!` file, no `feature.ts` in the output.

- [ ] **Step 5: Run existing tests**

```bash
npm run test:unit
```

Expected: All 309 tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: cleanup junk files, fix package.json for npm consumers"
```

---

### Task 2: Shared Gate Registry

**Files:**
- Create: `src/gates.js`
- Create: `tests/unit/cli/test-gates.sh`

- [ ] **Step 1: Write test file skeleton**

Create `tests/unit/cli/test-gates.sh` using the project's actual test framework (`describe`/`pass`/`fail` pattern from `tests/unit/helpers.sh`):

```bash
#!/usr/bin/env bash
# Tests for: src/gates.js gate registry
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"

# --- core registry ---
describe "GATE_REGISTRY has all 10 gates"
COUNT=$(node -e "const g = require('$CLI_ROOT/src/gates'); console.log(Object.keys(g.GATE_REGISTRY).length)")
if [ "$COUNT" = "10" ]; then pass; else fail "Expected 10 gates, got $COUNT"; fi

describe "each gate has description, howToSatisfy, howToOverride"
VALID=$(node -e "
  const g = require('$CLI_ROOT/src/gates');
  const ok = Object.values(g.GATE_REGISTRY).every(v => v.description && v.howToSatisfy && v.howToOverride);
  console.log(ok);
")
if [ "$VALID" = "true" ]; then pass; else fail "Some gates missing required fields"; fi

describe "getAllGateNames returns sorted array starting with ci"
FIRST=$(node -e "const g = require('$CLI_ROOT/src/gates'); console.log(g.getAllGateNames()[0])")
if [ "$FIRST" = "ci" ]; then pass; else fail "Expected first gate 'ci', got '$FIRST'"; fi

describe "getGateInfo returns info for known gate"
DESC=$(node -e "const g = require('$CLI_ROOT/src/gates'); console.log(g.getGateInfo('ci').description)")
if echo "$DESC" | grep -q "CI"; then pass; else fail "ci gate description missing 'CI'"; fi

describe "getGateInfo returns null for unknown gate"
RESULT=$(node -e "const g = require('$CLI_ROOT/src/gates'); console.log(g.getGateInfo('nonexistent'))")
if [ "$RESULT" = "null" ]; then pass; else fail "Expected null, got '$RESULT'"; fi

describe "suggestGate returns closest match for typo"
SUGGEST=$(node -e "const g = require('$CLI_ROOT/src/gates'); console.log(g.suggestGate('codereview'))")
if [ "$SUGGEST" = "codeReview" ]; then pass; else fail "Expected 'codeReview', got '$SUGGEST'"; fi

describe "suggestGate returns null when nothing is close"
SUGGEST=$(node -e "const g = require('$CLI_ROOT/src/gates'); console.log(g.suggestGate('xyzabc'))")
if [ "$SUGGEST" = "null" ]; then pass; else fail "Expected null, got '$SUGGEST'"; fi

describe "validateRegistry passes for shipped profiles"
WARNINGS=$(node -e "const g = require('$CLI_ROOT/src/gates'); console.log(g.validateRegistry('$CLI_ROOT/profiles').length)")
if [ "$WARNINGS" = "0" ]; then pass; else fail "Expected 0 warnings, got $WARNINGS"; fi

print_summary
```

- [ ] **Step 3: Implement gate registry**

Create `src/gates.js`:

```javascript
'use strict';

const fs = require('fs');
const path = require('path');

// All 10 gates with human-readable descriptions.
// Source of truth — profiles/*.json reference these names.
const GATE_REGISTRY = {
  ci: {
    description: 'CI checks must be green before merge',
    howToSatisfy: 'Push your changes and wait for GitHub Actions to pass. Check status: gh run list',
    howToOverride: 'npx right-hooks override --gate=ci --reason="<your reason>"',
    alwaysOn: true,
  },
  dod: {
    description: 'Definition of Done — every checklist item in the PR body must be checked',
    howToSatisfy: 'Edit the PR description and check all [ ] items. Use: gh pr edit --body "..."',
    howToOverride: 'npx right-hooks override --gate=dod --reason="<your reason>"',
    alwaysOn: false,
  },
  docConsistency: {
    description: 'Documentation must be reviewed for consistency with code changes',
    howToSatisfy: 'Spawn a doc-reviewer subagent or run the configured doc skill. The subagent posts a PR comment.',
    howToOverride: 'npx right-hooks override --gate=docConsistency --reason="<your reason>"',
    alwaysOn: true,
  },
  planningArtifacts: {
    description: 'Design doc + execution plan required before PR creation (feat/ branches only)',
    howToSatisfy: 'Create docs/designs/<feature>.md and docs/exec-plans/<feature>.md. Templates in .right-hooks/templates/',
    howToOverride: 'npx right-hooks override --gate=planningArtifacts --reason="<your reason>"',
    alwaysOn: false,
  },
  engReview: {
    description: 'Engineering review required before merge',
    howToSatisfy: 'Run /plan-eng-review or have a human review the architecture',
    howToOverride: 'npx right-hooks override --gate=engReview --reason="<your reason>"',
    alwaysOn: false,
  },
  codeReview: {
    description: 'Code review comment with severity findings must exist on the PR',
    howToSatisfy: 'Spawn a reviewer subagent. It runs the configured review skill and posts findings to the PR.',
    howToOverride: 'npx right-hooks override --gate=codeReview --reason="<your reason>"',
    alwaysOn: false,
  },
  qa: {
    description: 'QA test results must exist on the PR',
    howToSatisfy: 'Spawn a qa-reviewer subagent. It runs the configured QA skill and posts test results to the PR.',
    howToOverride: 'npx right-hooks override --gate=qa --reason="<your reason>"',
    alwaysOn: false,
  },
  learnings: {
    description: 'Learnings doc with "Rules to Extract" section must exist',
    howToSatisfy: 'Create docs/retros/<feature>-learnings.md with ### Rules to Extract section. Template in .right-hooks/templates/learnings.md',
    howToOverride: 'npx right-hooks override --gate=learnings --reason="<your reason>"',
    alwaysOn: false,
  },
  stopHook: {
    description: 'Agent cannot stop until review + QA cycle is complete',
    howToSatisfy: 'Complete the full review/QA workflow. The stop hook checks for review and QA sentinel files.',
    howToOverride: 'This gate cannot be overridden — it ensures the agent completes its work.',
    alwaysOn: false,
  },
  postEditCheck: {
    description: 'Code validation runs after every file edit (tsc/mypy/cargo check)',
    howToSatisfy: 'Fix the compilation/type errors shown in the hook output. The check runs automatically.',
    howToOverride: 'npx right-hooks override --gate=postEditCheck --reason="<your reason>"',
    alwaysOn: false,
  },
};

function getAllGateNames() {
  return Object.keys(GATE_REGISTRY).sort();
}

function getGateInfo(name) {
  return GATE_REGISTRY[name] || null;
}

// Read all profiles and return which gates each profile enables.
// Returns: { "strict": { ci: true, dod: true, ... }, "light": { ci: true, ... } }
function getActiveGates(profilesDir) {
  const result = {};
  if (!profilesDir || !fs.existsSync(profilesDir)) return result;

  const files = fs.readdirSync(profilesDir).filter(f => f.endsWith('.json'));
  for (const file of files) {
    try {
      const profile = JSON.parse(fs.readFileSync(path.join(profilesDir, file), 'utf8'));
      if (profile.name && profile.gates) {
        result[profile.name] = profile.gates;
      }
    } catch {
      // Skip malformed profiles
    }
  }
  return result;
}

// Validate that all gate names in profiles exist in the registry.
// Returns array of warnings (empty = all good).
function validateRegistry(profilesDir) {
  const warnings = [];
  const activeGates = getActiveGates(profilesDir);
  const registryNames = new Set(getAllGateNames());

  for (const [profileName, gates] of Object.entries(activeGates)) {
    for (const gateName of Object.keys(gates)) {
      if (!registryNames.has(gateName)) {
        warnings.push(`Profile "${profileName}" has gate "${gateName}" not in registry`);
      }
    }
  }
  return warnings;
}

// Fuzzy match for typo correction in explain command.
// Returns closest gate name or null if nothing is close enough.
function suggestGate(input) {
  const names = getAllGateNames();
  const lower = input.toLowerCase();

  // Exact substring match first
  const substring = names.find(n => n.toLowerCase().includes(lower) || lower.includes(n.toLowerCase()));
  if (substring) return substring;

  // Levenshtein distance
  let best = null;
  let bestDist = Infinity;
  for (const name of names) {
    const dist = levenshtein(lower, name.toLowerCase());
    if (dist < bestDist && dist <= 3) {
      bestDist = dist;
      best = name;
    }
  }
  return best;
}

function levenshtein(a, b) {
  const m = a.length, n = b.length;
  const dp = Array.from({ length: m + 1 }, () => Array(n + 1).fill(0));
  for (let i = 0; i <= m; i++) dp[i][0] = i;
  for (let j = 0; j <= n; j++) dp[0][j] = j;
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      dp[i][j] = a[i-1] === b[j-1]
        ? dp[i-1][j-1]
        : 1 + Math.min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]);
    }
  }
  return dp[m][n];
}

module.exports = { GATE_REGISTRY, getAllGateNames, getGateInfo, getActiveGates, validateRegistry, suggestGate };
```

- [ ] **Step 4: Tests are already complete**

Tests were written inline in Step 1 using the project's `describe`/`pass`/`fail` pattern (not stubs). No fill-in step needed.

- [ ] **Step 5: Run tests**

```bash
npm run test:unit
```

Expected: All tests pass including new gates tests.

- [ ] **Step 6: Commit**

```bash
git add src/gates.js tests/unit/cli/test-gates.sh
git commit -m "feat: shared gate registry module for explain, status, doctor"
```

---

### Task 3: ANSI Colors

**Files:**
- Modify: `hooks/_preamble.sh:43-95`
- Create: `tests/unit/hooks/test-colors.sh`

- [ ] **Step 1: Write test stubs**

Create `tests/unit/hooks/test-colors.sh`:

```bash
#!/usr/bin/env bash
# Tests for: ANSI color output in _preamble.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOKS_DIR="$(cd "$SCRIPT_DIR/../../../hooks" && pwd)"

describe "rh_pass includes green ANSI when _RH_COLOR_FORCE=1"
OUTPUT=$(RH_TEST=1 _RH_COLOR_FORCE=1 bash -c "source '$HOOKS_DIR/_preamble.sh'; rh_pass 'test' 'ok'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\[32m'; then pass; else fail "No green ANSI in: $OUTPUT"; fi

describe "rh_block includes red ANSI when _RH_COLOR_FORCE=1"
OUTPUT=$(RH_TEST=1 _RH_COLOR_FORCE=1 bash -c "source '$HOOKS_DIR/_preamble.sh'; rh_block 'test' 'blocked'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\[31m'; then pass; else fail "No red ANSI in: $OUTPUT"; fi

describe "rh_info includes blue ANSI when _RH_COLOR_FORCE=1"
OUTPUT=$(RH_TEST=1 _RH_COLOR_FORCE=1 bash -c "source '$HOOKS_DIR/_preamble.sh'; rh_info 'test' 'info'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\[34m'; then pass; else fail "No blue ANSI in: $OUTPUT"; fi

describe "rh_debug includes dim ANSI when RH_DEBUG=1 and _RH_COLOR_FORCE=1"
OUTPUT=$(RH_TEST=1 RH_DEBUG=1 _RH_COLOR_FORCE=1 bash -c "source '$HOOKS_DIR/_preamble.sh'; rh_debug 'test' 'debug'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\[2m'; then pass; else fail "No dim ANSI in: $OUTPUT"; fi

describe "rh_pass has no ANSI codes when NO_COLOR=1"
OUTPUT=$(RH_TEST=1 NO_COLOR=1 bash -c "source '$HOOKS_DIR/_preamble.sh'; rh_pass 'test' 'ok'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\['; then fail "Found ANSI in: $OUTPUT"; else pass; fi

describe "rh_block has no ANSI codes when NO_COLOR=1"
OUTPUT=$(RH_TEST=1 NO_COLOR=1 bash -c "source '$HOOKS_DIR/_preamble.sh'; rh_block 'test' 'blocked'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\['; then fail "Found ANSI in: $OUTPUT"; else pass; fi

describe "emoji preserved when colors enabled"
OUTPUT=$(RH_TEST=1 _RH_COLOR_FORCE=1 bash -c "source '$HOOKS_DIR/_preamble.sh'; rh_pass 'test' 'ok'" 2>&1)
if echo "$OUTPUT" | grep -q "🥊"; then pass; else fail "Emoji missing"; fi

describe "block hint line appears after rh_block message"
OUTPUT=$(RH_TEST=1 NO_COLOR=1 bash -c "source '$HOOKS_DIR/_preamble.sh'; rh_block 'test' 'blocked' 'ci'" 2>&1)
if echo "$OUTPUT" | grep -q "npx right-hooks explain"; then pass; else fail "No explain hint in: $OUTPUT"; fi

print_summary
```

- [ ] **Step 2: Add color variables to _preamble.sh**

Insert after line 41 (after the `fi` that closes the RH_TEST block), before the logging helpers comment:

```bash
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
```

- [ ] **Step 3: Update logging helpers to use colors**

Replace the logging helpers (lines 43-95 after the new color block) with:

```bash
# Logging helpers — all output to stderr
# Compact single-line format with ANSI colors: 🥊 hook — ✅/🚫 message

rh_pass() {
  local gate="${3:-}"
  [ -n "$gate" ] && rh_record_event "$1" "$gate" "pass"
  [ "${RH_QUIET:-}" = "1" ] && return
  printf "${_RH_GREEN}🥊 %s — ✅ %s${_RH_RESET}\n" "$1" "$2" >&2
}

# Incremental block API: rh_block_start → rh_block_item → rh_block_end
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
    [ -n "$line" ] && printf "  ${_RH_RED}%s${_RH_RESET}\n" "$line" >&2
  done
  [ -n "$hint" ] && printf "  ${_RH_DIM}%s${_RH_RESET}\n" "$hint" >&2
  _rh_explain_hint >&2
  _RH_BLOCK_HOOK=""
  _RH_BLOCK_LINES=""
}

# Legacy rh_block — one-liner with optional gate-specific hint
rh_block() {
  local gate="${3:-}"
  [ -n "$gate" ] && rh_record_event "$1" "$gate" "block"
  printf "${_RH_RED}🥊 %s — 🚫 %s${_RH_RESET}\n" "$1" "$2" >&2
  if [ -n "$gate" ]; then
    _rh_explain_hint "$gate" >&2
  else
    _rh_explain_hint >&2
  fi
}

# Explain hint — shown after every block message
_rh_explain_hint() {
  local gate="${1:-}"
  if [ -n "$gate" ]; then
    printf "  ${_RH_DIM}💡 Run 'npx right-hooks explain %s' for help${_RH_RESET}\n" "$gate"
  else
    printf "  ${_RH_DIM}💡 Run 'npx right-hooks explain' to see all gates${_RH_RESET}\n"
  fi
}

rh_info() {
  [ "${RH_QUIET:-}" = "1" ] && return
  printf "${_RH_BLUE}🥊 %s — %s${_RH_RESET}\n" "$1" "$2" >&2
}

rh_debug() {
  [ "${RH_DEBUG:-}" = "1" ] && printf "${_RH_DIM}🥊 DEBUG %-14s → %s${_RH_RESET}\n" "$1" "$2" >&2
  return 0
}
```

- [ ] **Step 4: Tests are already complete**

Tests were written inline in Step 1 using the project's `describe`/`pass`/`fail` pattern. No fill-in step needed.

- [ ] **Step 5: Run tests**

```bash
npm run test:unit
```

Expected: All tests pass, including existing 309 + new color tests.

- [ ] **Step 6: Commit**

```bash
git add hooks/_preamble.sh tests/unit/hooks/test-colors.sh
git commit -m "feat: ANSI color output with NO_COLOR standard compliance"
```

---

### Task 4: Explain Command

**Files:**
- Create: `src/explain.js`
- Modify: `bin/right-hooks.js`
- Create: `tests/unit/cli/test-explain.sh`

- [ ] **Step 1: Write test stubs**

Create `tests/unit/cli/test-explain.sh`:

```bash
#!/usr/bin/env bash
# Tests for: npx right-hooks explain CLI command
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI="$(cd "$SCRIPT_DIR/../../../" && pwd)/bin/right-hooks.js"

# --- explain specific gate ---
describe "explain ci shows gate description"
OUTPUT=$(node "$CLI" explain ci 2>&1)
if echo "$OUTPUT" | grep -q "CI checks must be green"; then pass; else fail "Missing ci description"; fi

describe "explain ci shows how-to-satisfy"
OUTPUT=$(node "$CLI" explain ci 2>&1)
if echo "$OUTPUT" | grep -q "How to satisfy"; then pass; else fail "Missing how-to-satisfy"; fi

describe "explain ci shows how-to-override"
OUTPUT=$(node "$CLI" explain ci 2>&1)
if echo "$OUTPUT" | grep -q "How to override"; then pass; else fail "Missing how-to-override"; fi

describe "explain codeReview shows review-specific guidance"
OUTPUT=$(node "$CLI" explain codeReview 2>&1)
if echo "$OUTPUT" | grep -q "review"; then pass; else fail "Missing review guidance"; fi

# --- typo handling ---
describe "explain with typo suggests correct gate"
OUTPUT=$(node "$CLI" explain codereview 2>&1 || true)
if echo "$OUTPUT" | grep -q "Did you mean"; then pass; else fail "No suggestion for typo"; fi

describe "explain unknown with no close match lists all gates"
OUTPUT=$(node "$CLI" explain xyzabc 2>&1 || true)
if echo "$OUTPUT" | grep -q "Available gates"; then pass; else fail "No gate list for unknown"; fi

# --- interactive (no args) ---
describe "explain with no args lists gates"
cd "$TEST_TMPDIR"
mkdir -p .right-hooks/profiles
cp "$(cd "$SCRIPT_DIR/../../../" && pwd)"/profiles/*.json .right-hooks/profiles/
OUTPUT=$(node "$CLI" explain 2>&1)
if echo "$OUTPUT" | grep -q "ci" && echo "$OUTPUT" | grep -q "codeReview"; then pass; else fail "Missing gates in listing"; fi

describe "explain with no args when not initialized shows gates without profiles"
cd "$TEST_TMPDIR"
rm -rf .right-hooks
OUTPUT=$(node "$CLI" explain 2>&1)
if echo "$OUTPUT" | grep -q "ci"; then pass; else fail "No gates shown without init"; fi

print_summary
```

- [ ] **Step 2: Implement explain command**

Create `src/explain.js`:

```javascript
'use strict';

const fs = require('fs');
const path = require('path');
const { GATE_REGISTRY, getAllGateNames, getGateInfo, getActiveGates, suggestGate } = require('./gates');

function run(args) {
  const gateName = args[0];

  if (!gateName) {
    showAllGates();
    return;
  }

  const info = getGateInfo(gateName);
  if (!info) {
    const suggestion = suggestGate(gateName);
    if (suggestion) {
      console.error(`Unknown gate: "${gateName}". Did you mean "${suggestion}"?\n`);
      console.error(`  npx right-hooks explain ${suggestion}\n`);
    } else {
      console.error(`Unknown gate: "${gateName}"\n`);
      console.error('Available gates:');
      for (const name of getAllGateNames()) {
        console.error(`  ${name}`);
      }
    }
    process.exit(1);
  }

  console.log(`\n🥊  Gate: ${gateName}\n`);
  console.log(`What it checks:`);
  console.log(`  ${info.description}\n`);
  console.log(`How to satisfy:`);
  console.log(`  ${info.howToSatisfy}\n`);
  console.log(`How to override:`);
  console.log(`  ${info.howToOverride}\n`);

  if (info.alwaysOn) {
    console.log(`⚠ This gate is always on — cannot be disabled per profile.\n`);
  }
}

function showAllGates() {
  const rhDir = '.right-hooks';
  const profilesDir = path.join(rhDir, 'profiles');

  console.log('\n🥊  Right Hooks — All Gates\n');

  // Load active profiles if available
  let activeGates = {};
  if (fs.existsSync(profilesDir)) {
    activeGates = getActiveGates(profilesDir);
  }

  const profileNames = Object.keys(activeGates).sort();
  const gateNames = getAllGateNames();

  // Print header
  if (profileNames.length > 0) {
    const header = 'Gate'.padEnd(22) + profileNames.map(p => p.padEnd(10)).join('');
    console.log(header);
    console.log('─'.repeat(header.length));

    for (const gate of gateNames) {
      let line = gate.padEnd(22);
      for (const profile of profileNames) {
        const enabled = activeGates[profile]?.[gate];
        const icon = enabled ? '✓' : '○';
        line += (icon + ' ').padEnd(10);
      }
      console.log(line);
    }
  } else {
    // Not initialized — just list gates
    for (const gate of gateNames) {
      const info = getGateInfo(gate);
      console.log(`  ${gate.padEnd(22)} ${info.description}`);
    }
  }

  console.log(`\nRun 'npx right-hooks explain <gate>' for details on a specific gate.\n`);
}

module.exports = { run };
```

- [ ] **Step 3: Add explain dispatch to bin/right-hooks.js**

In `bin/right-hooks.js`, add to the COMMANDS object:

```javascript
explain: 'Explain what a gate checks and how to fix blocks',
```

Add a case in the switch:

```javascript
case 'explain':
  require('../src/explain.js').run(args.slice(1));
  break;
```

- [ ] **Step 4: Tests are already complete**

Tests were written inline in Step 1 using the project's `describe`/`pass`/`fail` pattern. No fill-in step needed.

- [ ] **Step 5: Run tests**

```bash
npm run test:unit
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/explain.js bin/right-hooks.js tests/unit/cli/test-explain.sh
git commit -m "feat: explain command — discoverable help for blocked gates"
```

---

### Task 5: GitHub Check in Init

**Files:**
- Modify: `src/init.js:65-106`

- [ ] **Step 1: Add GitHub check before installation**

In `src/init.js`, add a check in the `run()` function, after `console.log('Detecting project...')` (around line 72) and before profile selection:

```javascript
// Check GitHub prerequisites
let ghAvailable = false;
try {
  execSync('gh auth status', { stdio: 'pipe' });
  ghAvailable = true;
  console.log('  ✓ GitHub CLI authenticated');
} catch {
  console.log('  ⚠ GitHub CLI (gh) not available or not authenticated');
  console.log('');
  console.log('  Right Hooks v1 requires a GitHub repository with the gh CLI authenticated.');
  console.log('  Install: https://cli.github.com/');
  console.log('  Auth:    gh auth login');
  console.log('');
  console.log('  GitLab/Bitbucket support is on the roadmap.');
  console.log('  Hooks will install but gate checks that call GitHub API will degrade gracefully.\n');
}
```

Note: This warns but does NOT block installation — hooks degrade gracefully per HOOK-CONTRACT.md. The warning ensures users know upfront.

- [ ] **Step 2: Add test for GitHub check**

Add to existing `tests/unit/cli/` or create a test that verifies the warning. Append to test-explain.sh or create a new file:

```bash
# In a new describe block or separate file
describe "init warns when gh not available"
cd "$TEST_TMPDIR"
# Mock gh to fail by using a non-existent path
OUTPUT=$(PATH="/nonexistent:$PATH" node "$CLI" init --yes 2>&1 || true)
if echo "$OUTPUT" | grep -qi "GitHub CLI"; then pass; else fail "No GitHub warning"; fi
```

- [ ] **Step 3: Run tests**

```bash
npm run test:unit
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add src/init.js
git commit -m "feat: warn about GitHub requirement during init"
```

---

### Task 6: Doctor Gate Validation

**Files:**
- Modify: `src/doctor.js`

- [ ] **Step 1: Add gate registry validation to doctor**

In `src/doctor.js`, after the existing checks (around line 280, before the summary), add:

```javascript
// Validate gate registry against profiles
try {
  const { validateRegistry } = require('./gates');
  const profilesDir = path.join(rhDir, 'profiles');
  const gateWarnings = validateRegistry(profilesDir);
  if (gateWarnings.length > 0) {
    for (const w of gateWarnings) {
      console.log(`⚠ ${w}`);
      warnings++;
    }
  } else {
    console.log('✓ Gate registry consistent with profiles');
  }
} catch {
  console.log('⚠ Could not validate gate registry');
  warnings++;
}
```

- [ ] **Step 2: Add test for gate validation**

Add a test to verify doctor reports consistency:

```bash
# Append to tests/unit/cli/test-gates.sh or add to test-doctor tests
describe "doctor reports gate registry consistent"
cd "$TEST_TMPDIR"
mkdir -p .right-hooks/profiles .right-hooks/hooks
cp "$CLI_ROOT"/profiles/*.json .right-hooks/profiles/
echo "1.0.0" > .right-hooks/version
OUTPUT=$(node "$CLI_ROOT/bin/right-hooks.js" doctor 2>&1 || true)
if echo "$OUTPUT" | grep -q "Gate registry consistent"; then pass; else fail "No gate validation message"; fi
```

- [ ] **Step 3: Run tests**

```bash
npm run test:unit
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add src/doctor.js tests/
git commit -m "feat: doctor validates gate names against registry"
```

---

### Task 7: Rich Block Messages in Hooks

**Depends on:** Task 3 complete (ANSI colors + `_rh_explain_hint` function in `_preamble.sh`).

**Files:**
- Modify: `hooks/pre-merge.sh` (find `rh_block_end` call)
- Modify: `hooks/pre-pr-create.sh` (find `rh_block` call)

- [ ] **Step 1: Update pre-merge.sh block message**

In `hooks/pre-merge.sh`, change the `rh_block_end` call (around line 270) from:

```bash
rh_block_end "Override: npx right-hooks override"
```

To include the explain hint:

```bash
rh_block_end "Override: npx right-hooks override --gate=<gate> --reason='...'"
```

The `_rh_explain_hint` in `rh_block_end` already adds the explain hint automatically (from Task 3).

- [ ] **Step 2: Update pre-pr-create.sh block message**

In `hooks/pre-pr-create.sh`, change line 79 from:

```bash
rh_block "pre-pr-create" "planning artifacts missing for feat/ branch"
```

To include the gate name as 3rd arg (triggers auto-hint):

```bash
rh_block "pre-pr-create" "planning artifacts missing for feat/ branch" "planningArtifacts"
```

- [ ] **Step 3: Sync hooks to .right-hooks/hooks/**

```bash
cp hooks/*.sh .right-hooks/hooks/
```

- [ ] **Step 4: Add test for block hints in hooks**

The color tests in `test-colors.sh` already verify the hint appears for `rh_block`. Add a hook-level test to verify `pre-pr-create` includes the hint:

```bash
# Append to tests/unit/hooks/test-colors.sh or tests/unit/hooks/test-pre-pr-create.sh
describe "pre-pr-create block includes explain hint"
# Create a minimal feat/ branch scenario that will fail the planning check
cd "$TEST_TMPDIR"
git init -q && git commit --allow-empty -m "init" -q
git checkout -b feat/test -q
JSON='{"tool_input":{"command":"gh pr create"}}'
OUTPUT=$(echo "$JSON" | RH_TEST=1 NO_COLOR=1 bash "$HOOKS_DIR/pre-pr-create.sh" 2>&1 || true)
if echo "$OUTPUT" | grep -q "npx right-hooks explain"; then pass; else fail "No explain hint in pre-pr-create block"; fi
```

- [ ] **Step 5: Run tests**

```bash
npm run test:unit
```

Expected: All tests pass. Block messages now include explain hints.

- [ ] **Step 6: Commit**

```bash
git add hooks/ .right-hooks/hooks/ tests/
git commit -m "feat: block messages include explain hints and gate context"
```

---

### Task 8: Community Files

**Files:**
- Create: `CONTRIBUTING.md`
- Create: `CHANGELOG.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `SECURITY.md`

- [ ] **Step 1: Create CONTRIBUTING.md**

```markdown
# Contributing to Right Hooks

Thanks for your interest in contributing! Right Hooks is the process enforcement layer
for autonomous AI coding agents.

## Development Setup

```bash
git clone https://github.com/ychua/right-hooks.git
cd right-hooks
npm install
npm test
```

## Running Tests

```bash
npm test                  # All tests (unit + integration)
npm run test:unit         # Unit tests only (309+ tests, bash-based)
npm run test:integration  # Integration tests only (bashunit)
```

Tests run with `RH_TEST=1` which skips dependency/auth/integrity checks in the preamble.

## Project Structure

```
bin/          CLI entry point
src/          Node.js CLI commands
hooks/        Shell hooks (copied to user's .right-hooks/hooks/ on init)
rules/        Behavioral rules (symlinked to .claude/rules/)
presets/      Language configs (typescript, python, go, rust, generic)
profiles/     Enforcement profiles (strict, standard, light, custom)
signatures/   Tool-specific comment patterns
templates/    Design doc, exec plan, learnings templates
tests/        Unit + integration tests
```

## Adding a New Hook

1. Create `hooks/my-hook.sh` sourcing `_preamble.sh`
2. Add to `src/doctor.js` `expectedHooks` array
3. Add hook config to `settings.json`
4. Write tests in `tests/unit/hooks/test-my-hook.sh`
5. Update CLAUDE.md hooks reference

## Adding a New Gate

1. Add gate metadata to `src/gates.js` `GATE_REGISTRY`
2. Add gate to relevant profiles in `profiles/*.json`
3. Implement the check in the appropriate hook
4. Write tests
5. Run `npx right-hooks doctor` to verify consistency

## Pull Request Process

1. Fork the repo and create a branch (`feat/`, `fix/`, `chore/`, etc.)
2. Write tests first (TDD encouraged)
3. Run `npm test` — all tests must pass
4. Submit a PR with a clear description

## Code Style

- Shell: POSIX-compatible bash, explicit over clever
- Node.js: `'use strict'`, CommonJS, no external dependencies
- All output to stderr (hooks), stdout for data only
- Follow existing patterns — consistency beats novelty
```

- [ ] **Step 2: Create CHANGELOG.md**

```markdown
# Changelog

All notable changes to Right Hooks will be documented in this file.

## [1.0.0] - 2026-03-23

### Added
- 12 Claude Code hooks for full lifecycle enforcement
- 2 git hooks via husky (pre-push + post-merge)
- Multi-agent orchestration: workflow-orchestrator + inject-skill
- 3-level skill enforcement: signature + provenance + behavioral
- Configurable skill dispatch via skills.json
- 5 language presets: TypeScript, Python, Go, Rust, Generic
- 4 enforcement profiles: Strict, Standard, Light, Custom
- CLI commands: init, scaffold, status, skills, stats, doctor, diff, override, upgrade
- Gate effectiveness metrics (`npx right-hooks stats`)
- `explain` command for discoverable gate help
- ANSI color output with NO_COLOR standard support
- 330+ tests (unit + integration)
```

- [ ] **Step 3: Create CODE_OF_CONDUCT.md**

Use the Contributor Covenant v2.1. Fetch from the standard source or write the standard text. Contact email: the repo maintainer's email.

- [ ] **Step 4: Create SECURITY.md**

```markdown
# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Right Hooks, please report it responsibly.

**Do NOT open a public issue.**

Instead, email: [security contact — update before publishing]

You should receive a response within 48 hours. We'll work with you to understand
the issue and coordinate a fix before public disclosure.

## Scope

Right Hooks runs locally as shell hooks and a Node.js CLI. It:
- Reads/writes files in `.right-hooks/` and `.claude/`
- Calls `gh` CLI for GitHub API access (uses existing auth)
- Never sends data to external servers
- Never stores credentials (relies on `gh auth`)

## Known Limitations

1. Hook checksums detect tampering but don't prevent it
2. An agent could `rm -rf .right-hooks/` — defense is visibility, not prevention
3. Override files are committed to git — visible audit trail, not secret
```

- [ ] **Step 5: Commit**

```bash
git add CONTRIBUTING.md CHANGELOG.md CODE_OF_CONDUCT.md SECURITY.md
git commit -m "docs: add community files for open source readiness"
```

---

### Task 9: GitHub Templates

**Files:**
- Create: `.github/ISSUE_TEMPLATE/bug-report.yml`
- Create: `.github/ISSUE_TEMPLATE/feature-request.yml`
- Create: `.github/PULL_REQUEST_TEMPLATE.md`

- [ ] **Step 1: Create bug report template**

Create `.github/ISSUE_TEMPLATE/bug-report.yml`:

```yaml
name: Bug Report
description: Report a bug in Right Hooks
labels: [bug]
body:
  - type: textarea
    id: description
    attributes:
      label: What happened?
      description: A clear description of the bug
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: What did you expect?
    validations:
      required: true
  - type: textarea
    id: reproduce
    attributes:
      label: Steps to reproduce
      value: |
        1. Run `npx right-hooks ...`
        2. ...
    validations:
      required: true
  - type: input
    id: version
    attributes:
      label: Right Hooks version
      placeholder: "npx right-hooks version"
    validations:
      required: true
  - type: dropdown
    id: os
    attributes:
      label: Operating System
      options:
        - macOS
        - Linux
        - Windows (WSL)
    validations:
      required: true
```

- [ ] **Step 2: Create feature request template**

Create `.github/ISSUE_TEMPLATE/feature-request.yml`:

```yaml
name: Feature Request
description: Suggest a new feature or improvement
labels: [enhancement]
body:
  - type: textarea
    id: problem
    attributes:
      label: What problem does this solve?
      description: Describe the problem or workflow gap
    validations:
      required: true
  - type: textarea
    id: solution
    attributes:
      label: Proposed solution
      description: How would you like this to work?
    validations:
      required: true
  - type: dropdown
    id: scope
    attributes:
      label: Area
      options:
        - Hooks (enforcement)
        - CLI (commands)
        - Multi-runtime (Codex, Cursor, etc.)
        - Documentation
        - Other
    validations:
      required: true
```

- [ ] **Step 3: Create PR template**

Create `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## Summary

<!-- What does this PR do? 1-3 sentences. -->

## Changes

<!-- Bullet list of what changed. -->

## Testing

- [ ] All existing tests pass (`npm test`)
- [ ] New tests added for new functionality
- [ ] Manual verification done

## Checklist

- [ ] Hooks synced to `.right-hooks/hooks/` (if hooks modified)
- [ ] CLAUDE.md updated (if hooks or commands added)
- [ ] README.md updated (if user-facing changes)
```

- [ ] **Step 4: Commit**

```bash
git add .github/
git commit -m "docs: add GitHub issue templates and PR template"
```

---

### Task 10: README Reposition

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README positioning**

Key changes to `README.md`:
1. Change subtitle from "A PR-Based Rigorous Engineering Workflow — Built for gstack" to "Process Enforcement for Claude Code"
2. Add line: "Also works with [gstack](https://github.com/garrytan/gstack) (best-in-class integration) and [superpowers](https://github.com/obra/superpowers)."
3. In Prerequisites, lead with "Claude Code" not "GitHub repository"
4. Update badge URLs if the GitHub org/repo name changes
5. Add a "Roadmap" section mentioning multi-runtime support (Codex, Cursor, Aider)
6. Fix the interactive setup URL reference (line 121: `https://github.com/ychua/right-hooks#enforcement-profiles`) — keep consistent with actual org

Do NOT rewrite the entire README — the narrative is strong. Only change positioning language.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: reposition README as Claude Code-first, gstack as integration"
```

---

### Task 11: Docs Reorganization

**Files:**
- Move: `docs/designs/*` → `docs/internal/designs/*`
- Move: `docs/exec-plans/*` → `docs/internal/exec-plans/*`
- Move: `docs/retros/*` → `docs/internal/retros/*`
- Move: `docs/superpowers/*` → `docs/internal/superpowers/*`

**Note:** This task moves `docs/superpowers/` which contains THIS PLAN FILE. Complete all other tasks first. Use a local copy or memory of the plan for reference during this task.

**Important:** The `pre-pr-create.sh` hook checks `docs/designs/*.md` in the git diff for new feature work. This path is UNCHANGED — new design docs still go in `docs/designs/`. Only historical artifacts move to `docs/internal/`. The hooks do NOT need updating.

- [ ] **Step 1: Create internal directory and move files**

```bash
mkdir -p docs/internal
git mv docs/designs docs/internal/designs
git mv docs/exec-plans docs/internal/exec-plans
git mv docs/retros docs/internal/retros
git mv docs/superpowers docs/internal/superpowers
```

- [ ] **Step 2: Re-create empty docs directories for new work**

```bash
mkdir -p docs/designs docs/exec-plans docs/retros
touch docs/designs/.gitkeep docs/exec-plans/.gitkeep docs/retros/.gitkeep
```

These directories are created by `npx right-hooks scaffold` and are where new design docs go. The hooks check `git diff --name-only` for `docs/designs/*.md` — this path is unchanged.

- [ ] **Step 3: Verify hooks still work**

```bash
npm run test:unit
```

Expected: All tests pass. The hooks check git diffs, not filesystem paths.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: move historical docs to docs/internal/ for OSS clarity"
```

---

### Task 12: Final Verification

- [ ] **Step 1: Run full test suite**

```bash
npm test
```

Expected: All 330+ tests pass (309 original + ~25 new).

- [ ] **Step 2: Verify npm pack is clean**

```bash
npm pack --dry-run
```

Expected: ~55 files, ~50kB. No junk files. No docs/internal/ (not in `files` array).

- [ ] **Step 3: Test fresh install**

```bash
cd /tmp
mkdir test-rh && cd test-rh
git init && git commit --allow-empty -m "init"
npx /path/to/right-hooks init --yes
```

Expected: Init succeeds, hooks installed, GitHub warning shown (no gh auth in /tmp).

- [ ] **Step 4: Test explain command**

```bash
npx right-hooks explain ci
npx right-hooks explain
npx right-hooks explain nonexistent
```

Expected: Gate info, all gates listed, "Did you mean?" suggestion.

- [ ] **Step 5: Commit any final adjustments**

```bash
git add -A
git commit -m "chore: final OSS readiness verification"
```

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 3 | CLEAR | 8 proposals, 8 accepted, 0 deferred |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 4 | CLEAR | 2 issues, 0 critical gaps |

- **VERDICT:** CEO + ENG CLEARED — ready to implement
