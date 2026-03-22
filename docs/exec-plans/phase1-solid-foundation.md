---
status: ACTIVE
design_doc: docs/designs/right-hooks-v1-review.md
phase: 1 of 5
---
# Execution Plan: Phase 1 — Solid Foundation

## Overview

Fix all 10 known bugs, DRY duplicated code, add debug mode, create CLAUDE.md
and TODOS.md, and write gate enforcement tests. No new abstractions — just make
the existing code correct, clean, and well-tested.

**Branch:** `fix/phase1-solid-foundation`
**Estimated:** human ~2 weeks / CC ~1-2 hours

## Tasks

### Task 1: Fix pre-merge.sh gate defaults bug (CRITICAL)
**Status:** [ ] Not started
**Files:** `hooks/pre-merge.sh`

The profile matching loop (lines 39-50) only loads 5 of 8 gate values from the
matched profile. CI, DoD, and docConsistency are hardcoded to `true` on lines
29-31, meaning they're always enforced regardless of profile.

**Fix:**
1. Change defaults for ALL gates to `false` (lines 29-36)
2. Load ALL gates from matched profile in the loop (add ci, dod, docConsistency)
3. If no profile matches the branch type, all gates are `false` (safe default)

**Test:** Custom profile with all gates `false` → merge attempt exits 0 (no enforcement)

### Task 2: Fix cross-platform SHA in preamble (HIGH)
**Status:** [ ] Not started
**Files:** `hooks/_preamble.sh`

Line 22 uses `shasum -a 256` which doesn't exist on Linux. Linux uses `sha256sum`.

**Fix:** Add `rh_sha256()` helper that checks for `sha256sum` first, falls back to
`shasum -a 256`.

**Test:** Mock both commands, verify correct one is called per platform.

### Task 3: Fix settings deep merge in init.js (CRITICAL)
**Status:** [ ] Not started
**Files:** `src/init.js`

Line 258 does `existing.hooks = { ...existing.hooks, ...settings.hooks }` which
overwrites existing hook event arrays. If user had PreToolUse hooks, they're lost.

**Fix:** Deep merge per event type. For each event, check if the hook command
already exists (by command path) before adding. Append new hooks, skip duplicates.

**Test:** Create settings.json with existing hooks, run init, verify original hooks preserved.

### Task 4: Add API pagination (CRITICAL)
**Status:** [ ] Not started
**Files:** `hooks/pre-merge.sh`, `hooks/stop-check.sh`

`gh api` calls for PR comments return only first 30 items. PRs with >30 comments
get false gate failures.

**Fix:** Add `--paginate` to all `gh api` calls that fetch PR comments.

**Test:** Not easily unit-testable (needs real GitHub API), but verify the flag is present.

### Task 5: Fix doctor.js missing hook
**Status:** [ ] Not started
**Files:** `src/doctor.js`

`expectedHooks` array on line 48 has 9 hooks but 10 exist. Missing: `block-agent-override.sh`.

**Fix:** Add `'block-agent-override.sh'` to the array.

**Test:** Existing doctor tests should cover (verify hook count).

### Task 6: Fix pre-merge.sh gate count
**Status:** [ ] Not started
**Files:** `hooks/pre-merge.sh`

Lines 207-211 count gates from `PROFILE` (active-profile.json) but actual checks
use gates from the matched profile file. These can differ.

**Fix:** Count gates from the same source used for checking — the matched profile
variables, not the active-profile.json.

**Test:** Verify reported gate count matches actual gates checked.

### Task 7: Add gh api timeouts
**Status:** [ ] Not started
**Files:** `hooks/pre-merge.sh`, `hooks/stop-check.sh`

No timeout on `gh api` calls. Hooks hang if GitHub API is slow.

**Fix:** Use a wrapper that adds timeout. `gh` doesn't have a native timeout flag,
so use `timeout 10` (Linux) or background + wait (portable). Alternatively, since
we're batching comments into one call, the main risk is one slow call, not 8.

Simplest approach: set `GH_HTTP_TIMEOUT` environment variable (gh respects this,
defaults to 0 = no timeout). Set to 15 seconds.

### Task 8: Fix VERSION hardcoding
**Status:** [ ] Not started
**Files:** `src/init.js`, `bin/right-hooks.js`

Both hardcode `const VERSION = '1.0.0'`. Should read from package.json.

**Fix:** `const VERSION = require('../package.json').version;` in both files.

### Task 9: Add husky detection during init
**Status:** [ ] Not started
**Files:** `src/init.js`

Init sets up .husky/ directory but doesn't check if husky is installed. If not
installed, git hooks don't fire — silent enforcement gap.

**Fix:** After creating .husky/ files, check if husky is in node_modules or
package.json. If not found, log a warning:
"⚠ husky not found in this project. Install it: npm install -D husky"

### Task 10: DRY gstack/superpowers detection
**Status:** [ ] Not started
**Files:** `src/init.js`

Detection logic appears twice: `run()` (lines 57-63) and `install()` (lines 142-147).

**Fix:** Extract to a function `detectTooling(projectDir)` that returns
`{ hasGstack, hasSuperpowers, gstackLocation, superpowersLocation }`. Call once
in `run()`, pass results to `install()`.

### Task 11: Extract profile matching to preamble
**Status:** [ ] Not started
**Files:** `hooks/_preamble.sh`, `hooks/pre-merge.sh`, `hooks/stop-check.sh`

Profile matching logic duplicated in pre-merge.sh (lines 39-50) and
stop-check.sh (lines 19-29).

**Fix:** Add `rh_profile_for_branch()` helper to `_preamble.sh`. Takes branch
type and gate name, returns gate value from matched profile or "false".

Replace duplicated loops in both hooks with calls to the helper.

### Task 12: Batch API calls in pre-merge.sh
**Status:** [ ] Not started
**Files:** `hooks/pre-merge.sh`

Four separate `gh api` calls fetch PR comments for doc/review/QA/staleness checks.

**Fix:** Fetch all comments once with `--paginate`, cache in `RH_ALL_COMMENTS` shell
variable. All subsequent checks filter from the cached data with jq.

Add warning when fetch fails: `rh_info "pre-merge" "⚠ Could not fetch PR comments — some gates skipped"`.

### Task 13: Add RH_DEBUG=1 debug mode
**Status:** [ ] Not started
**Files:** `hooks/_preamble.sh`

No verbose output mode for troubleshooting false positives.

**Fix:** Add `rh_debug()` helper that outputs only when `RH_DEBUG=1`:
```bash
rh_debug() {
  [ "${RH_DEBUG:-}" = "1" ] && printf '🥊 DEBUG %-14s → %s\n' "$1" "$2" >&2
}
```

Add debug calls at key points: profile match, gate values, API responses.

### Task 14: Create CLAUDE.md
**Status:** [ ] Not started
**Files:** `CLAUDE.md` (new)

Developer onboarding doc covering:
- Architecture overview (3-layer: Universal → Language → Custom)
- How to run tests (`npm test`, `npm run test:unit`, `npm run test:integration`)
- How hooks work (preamble sourcing, exit codes, fail-open principle)
- How to add a new hook
- How to add a new preset
- How to add a new profile

### Task 15: Create TODOS.md
**Status:** [ ] Not started
**Files:** `TODOS.md` (new)

Track deferred work from Phases 2-5:
- Phase 2: scaffold, doctor --fix, diff
- Phase 3: stats (needs data model design)
- Phase 4: VCS abstraction + multi-runtime adapters
- Phase 5: GitHub Actions (needs separate design doc)
- Deferred: Codex adapter, PR badges, color output, init --from, explain

### Task 16: Write gate enforcement tests
**Status:** [ ] Not started
**Files:** `tests/unit/hooks/test-pre-merge.sh` (extend), new test files as needed

10 new test cases:
1. feat/ branch merge blocked without review comment (exit 2)
2. feat/ branch merge passes with all gates satisfied (exit 0)
3. Custom profile all-false → no enforcement (regression test for bug #1)
4. docs/ branch with light profile → only CI/DoD/doc gates checked
5. Cross-platform SHA helper works with sha256sum
6. Cross-platform SHA helper works with shasum
7. Settings deep merge preserves existing hooks
8. rh_profile_for_branch returns "false" for unmatched branch
9. Comment batch failure logs warning and gates pass (graceful degradation)
10. RH_DEBUG=1 produces debug output on stderr

Tests use existing `RH_TEST=1` infrastructure with mock `gh` responses.

## Execution Order

```
1.  Task 1  — Gate defaults bug (unblocks Task 6, Task 16)
2.  Task 11 — DRY profile matching (simplifies Tasks 1, 4, 7)
3.  Task 2  — Cross-platform SHA
4.  Task 12 — Batch API calls (unblocks Task 4)
5.  Task 4  — API pagination
6.  Task 7  — gh api timeouts
7.  Task 3  — Settings deep merge
8.  Task 5  — Doctor missing hook
9.  Task 6  — Gate count fix
10. Task 8  — VERSION fix
11. Task 9  — Husky detection
12. Task 10 — DRY gstack detection
13. Task 13 — Debug mode
14. Task 14 — CLAUDE.md
15. Task 15 — TODOS.md
16. Task 16 — Gate enforcement tests (last — tests verify all fixes)
```

## Definition of Done

- [ ] All 10 bugs fixed with regression tests
- [ ] Duplicated code extracted (profile matching, gstack detection)
- [ ] API calls batched (comments fetched once per hook invocation)
- [ ] RH_DEBUG=1 shows verbose output
- [ ] CLAUDE.md created with developer onboarding
- [ ] TODOS.md created with Phases 2-5 deferred items
- [ ] All existing tests still pass (`npm test`)
- [ ] 10 new gate enforcement tests pass
- [ ] Integration tests updated if affected
- [ ] CI green on both unit and integration jobs
- [ ] No new TODOs or FIXMEs introduced
