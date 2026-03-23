# Design: `npx right-hooks stats`

See full spec: `docs/superpowers/specs/2026-03-23-stats-design.md`

## Problem
No visibility into gate effectiveness. Can't tell which gates cause friction vs. add value.

## Decision
Shell-native event recording (JSONL append-only) via `rh_record_event` in `_preamble.sh`.
Node.js CLI reads and aggregates. No dependencies, <1ms overhead per hook.

## Alternatives Rejected
- Node.js recording daemon (50ms cold start per hook — too slow)
- Post-hoc git/API derivation (can't track agent stops — too lossy)
