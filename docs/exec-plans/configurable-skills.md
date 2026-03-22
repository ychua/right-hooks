---
status: COMPLETE
design_doc: docs/designs/configurable-skills.md
---
# Execution Plan: Configurable Skill Dispatch

## Overview

Replace hardcoded tool detection (if/elif gstack/superpowers chains) with
configurable `skills.json` that maps each gate to a skill command + provider.
Hooks read the config at runtime and suggest the configured skill, with a
4-tier fallback: skill → fallback text → runtime detection → generic.

**Branch:** `feat/configurable-skills`

## Tasks (all complete)

1. Update design doc with eng review decisions (gate names, 4-tier fallback)
2. Create skills.json templates (gstack, superpowers, generic)
3. Add `rh_skill_command` helper to `_preamble.sh`
4. Refactor `stop-check.sh` and `pre-merge.sh` — replace if/elif chains
5. Add skills.json generation to `init.js` and `upgrade.js`
6. Create `src/skills.js` — status + set CLI
7. Add skills validation to `doctor.js`
8. Wire `skills` command in CLI + dedup `learned-patterns.md`
9. Write tests (7 preamble + 10 CLI) and verify full suite

## Definition of Done

- [x] `skills.json` generated during init with correct template
- [x] Hooks suggest configured skills instead of hardcoded gstack/superpowers
- [x] 4-tier fallback: skill → fallback → runtime detection → generic
- [x] Runtime provider check — don't suggest dead commands
- [x] `npx right-hooks skills` shows configuration
- [x] `npx right-hooks skills set` updates config
- [x] `doctor` validates skills.json and provider availability
- [x] Sentinel protocol hints in block messages
- [x] All 179 tests pass (166 unit + 13 integration)
- [x] `learned-patterns.md` deduplicated
