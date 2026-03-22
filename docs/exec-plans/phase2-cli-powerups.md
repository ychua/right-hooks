---
status: ACTIVE
design_doc: docs/designs/right-hooks-v1-review.md
phase: 2 of 5
---
# Execution Plan: Phase 2 — CLI Power-Ups

## Overview

Add three new CLI commands that improve developer experience: `scaffold` (create
docs directories), `doctor --fix` (auto-repair issues), and `diff` (preview
upgrade changes). All three are small, self-contained, and have no dependencies
on each other.

**Branch:** `feat/phase2-cli-powerups`
**Estimated:** human ~1 week / CC ~30-45 min

## Tasks

### Task 1: `npx right-hooks scaffold`

**Files:** `src/scaffold.js` (new), `bin/right-hooks.js`, `src/init.js`

Create docs directories with `.gitkeep` files so first-time `feat/` branch users
don't hit confusing `pre-pr-create` hook failures.

**Steps:**
1. Create `src/scaffold.js` with a `run()` function that:
   - Creates `docs/designs/`, `docs/exec-plans/`, `docs/retros/` with `.gitkeep`
   - Creates `.right-hooks/rules/learned-patterns.md` if missing
   - Idempotent — skips directories that already exist
   - Prints what was created vs what already existed
2. Add `scaffold` to `COMMANDS` in `bin/right-hooks.js`
3. Add routing case in the switch statement
4. Call `scaffold.run()` at the end of `install()` in `src/init.js`

**Test:** `tests/unit/cli/test-scaffold.sh`
- scaffold creates all 3 directories with .gitkeep
- scaffold is idempotent (second run changes nothing)
- scaffold creates learned-patterns.md when missing
- scaffold skips learned-patterns.md when it exists

### Task 2: `npx right-hooks doctor --fix`

**Files:** `src/doctor.js`

Extend doctor to auto-fix common issues instead of just diagnosing them.

**Steps:**
1. Parse `--fix` flag from args
2. For each existing check, add a fix action when `--fix` is set:
   - Missing hooks → re-copy from package
   - Non-executable hooks → chmod +x
   - Checksum mismatch → offer to regenerate (since user may have customized)
   - Missing .checksums → regenerate from current hooks
   - Missing version file → write current version
   - Malformed JSON files → log error (can't auto-fix)
   - Missing rules symlinks → re-create
3. Track fixes applied, print summary at end
4. If `--fix` flag not present, current behavior unchanged

**Test:** extend `tests/unit/cli/test-doctor.sh`
- doctor --fix restores missing hooks
- doctor --fix fixes permissions
- doctor --fix regenerates missing checksums
- doctor without --fix still only diagnoses

### Task 3: `npx right-hooks diff`

**Files:** `src/diff.js` (new), `bin/right-hooks.js`

Preview what `upgrade` would change, without modifying anything. Uses the same
comparison logic as `upgrade.js`.

**Steps:**
1. Create `src/diff.js` with `run()` that:
   - Loads installed checksums from `.right-hooks/.checksums`
   - Compares each package hook against installed version
   - Categories: `updated` (would change), `preserved` (user modified, would keep),
     `added` (new hook), `unchanged` (identical)
   - Also compares rules and templates
   - Prints summary with counts
   - Exit 0 always (read-only)
2. Add `diff` to `COMMANDS` in `bin/right-hooks.js`
3. Add routing case in the switch statement

**Test:** `tests/unit/cli/test-diff.sh`
- diff shows "unchanged" when hooks match package
- diff shows "would update" when package has newer version
- diff shows "preserved" when user modified a hook
- diff shows "new" for hooks not yet installed

## Execution Order

```
1. Task 1 — scaffold (unblocks init integration)
2. Task 2 — doctor --fix (extends existing command)
3. Task 3 — diff (new command, no dependencies)
4. Tests for all three
5. Full test suite verification
```

## Definition of Done

- [ ] `npx right-hooks scaffold` creates docs directories
- [ ] `npx right-hooks init` also runs scaffold
- [ ] `npx right-hooks doctor --fix` auto-repairs common issues
- [ ] `npx right-hooks diff` shows what upgrade would change
- [ ] All new commands appear in `--help` output
- [ ] New tests pass
- [ ] All existing tests still pass (`npm test`)
- [ ] CI green
