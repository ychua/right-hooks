# Phase 2: CLI Power-Ups

**Parent design:** `docs/designs/right-hooks-v1-review.md` (Phase 1 CEO review)
**Status:** Active

## Problem

After Phase 1's bug fixes and enforcement improvements, users still face three
DX gaps:

1. **Bootstrapping pain:** `init` doesn't create `docs/` directories, so the
   first `feat/` branch immediately fails `pre-pr-create` with a confusing
   "missing design doc" error before the user even knows what directories exist.

2. **Doctor is read-only:** `doctor` diagnoses issues but can't fix them. Users
   must manually re-copy hooks, chmod files, and regenerate checksums — tedious
   and error-prone.

3. **Upgrade is blind:** `upgrade` modifies files without preview. Users who've
   customized hooks have no way to see what would change before committing.

## Solution

Three small, independent CLI commands:

### `scaffold`
Creates `docs/designs/`, `docs/exec-plans/`, `docs/retros/` with `.gitkeep`.
Also runs during `init`. Idempotent — safe to run repeatedly.

### `doctor --fix`
Extends existing `doctor` with auto-repair. Fixes: missing hooks (re-copy from
package), bad permissions (chmod), missing checksums (regenerate), broken
symlinks, missing version file.

### `diff`
Read-only preview using the same comparison logic as `upgrade`. Shows each hook
as updated/preserved/added/unchanged plus rules comparison.

## Alternatives Considered

**Single "repair" command instead of extending doctor:** Rejected — doctor
already has the diagnostic logic, adding `--fix` keeps the mental model simple
(diagnose → fix) rather than introducing a new command.

**Interactive diff with patch selection:** Over-engineered for v1. The diff
command shows what would change; users can then run upgrade or not. Cherry-picking
individual hook updates would add complexity without clear user value yet.

## Scope

**In:** scaffold, doctor --fix, diff + tests for all three
**Out:** stats command (Phase 3, needs data model), VCS abstraction (Phase 4)
