# Exec Plan: `npx right-hooks stats`

**Status:** COMPLETE

See full plan: `docs/superpowers/plans/2026-03-23-stats.md`

## Tasks (all complete)
1. Add `rh_record_event` to `_preamble.sh`
2. Add per-gate recording to `pre-merge.sh`
3. Add stop reason recording to `stop-check.sh`
4. Create `src/stats.js` CLI command
5. Wire into init, doctor, gitignore
6. Extend integration tests
7. Sync hooks and update TODOS.md

## Definition of Done
- [x] `rh_record_event` function in `_preamble.sh` writes valid JSONL
- [x] `rh_pass`/`rh_block` auto-record when 3rd arg (gate) provided
- [x] `pre-merge.sh` records per-gate pass/block events (7 gates)
- [x] `stop-check.sh` records stop events with `stop_reason` at all 6 exit paths
- [x] `npx right-hooks stats` prints gate table + human involvement table
- [x] `.stats/` directory created during init, checked by doctor
- [x] `.right-hooks/.stats/` in `.gitignore`
- [x] 286 unit tests pass, 17 integration tests pass
- [x] Source hooks synced to `.right-hooks/hooks/`
