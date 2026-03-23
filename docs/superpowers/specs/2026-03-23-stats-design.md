# Design: `npx right-hooks stats` — Gate Effectiveness Metrics

**Status:** APPROVED
**Date:** 2026-03-23
**Phase:** 3 — Stats & Observability

---

## Problem Statement

Right Hooks enforces a development lifecycle through shell hooks, but there's no
visibility into how well the enforcement is calibrated. Without metrics:

- You can't tell which gates block most often (friction signals)
- You can't tell which gates never block (potentially unnecessary)
- You can't measure how close you are to "review once, merge once" — the ideal
  where the automated pipeline runs end-to-end without human intervention
- Every agent stop is invisible — you don't know how many times you had to
  re-engage vs. how many times the pipeline completed autonomously

## Alternatives Considered

### A) Shell-native recording (chosen)

Each hook appends a JSON line to `.right-hooks/.stats/events.jsonl` via a shared
helper in `_preamble.sh`. The `stats` CLI command (Node.js) reads and aggregates.

**Pros:** Zero dependencies. Recording at source. <1ms overhead per hook. Simple
append-only file.
**Cons:** Shell JSON generation is manual `printf`. But events are fixed-schema
with no user-supplied strings — safe.

### B) Node.js recording daemon

Hooks pipe events to a Node.js process for JSON serialization.

**Pros:** Proper JSON handling with schema validation.
**Cons:** ~50ms cold start per hook invocation. Hooks fire on every tool use —
latency compounds fast. Rejected for performance.

### C) Post-hoc derivation from git/API

Reconstruct stats from git log, override files, and GitHub API.

**Pros:** Zero hook changes. Works retroactively.
**Cons:** Can't answer "how many times did gate X block?" — only "how many PRs
had failures." Can't track agent stops at all. Rejected as lossy.

## Technical Decisions

### Event storage format: JSONL (append-only)

**Options:** JSONL, SQLite, CSV
**Choice:** JSONL — one JSON object per line, append-only.
**Why:** No dependencies (SQLite needs a binary). Human-readable. Trivially
parseable in both shell (`jq`) and Node.js. Grep-friendly for debugging.
**What we'd lose:** SQLite would give us indexed queries, but we expect hundreds
of events per month — linear scan is fine.
**Reversibility:** Two-way door. Can migrate to SQLite later by reading JSONL.
**Upgrade path:** Add a `--migrate sqlite` flag if performance becomes an issue.

### Recording integration: hybrid (centralized + per-gate inline)

**Options:** (1) Wire into centralized helpers only, (2) Inline per-gate calls,
(3) Hybrid — centralized for simple hooks, inline for multi-gate hooks
**Choice:** Hybrid approach.
**Why:** Most hooks call `rh_pass` once → auto-recording works. But `pre-merge.sh`
checks 7 gates and calls `rh_pass` once at the end ("all N gates passed") or
`rh_block_end` once for all failures. Per-gate stats require inline recording
at each gate check point within pre-merge.sh. Similarly, `stop-check.sh` has
5 exit paths (3 silent early exits, 1 block, 1 pass) that each need explicit
recording with a stop_reason.

**Hooks by recording strategy:**
- **Auto-recorded via `rh_pass`/`rh_block`:** post-edit-check, pre-pr-create,
  pre-push-master, block-agent-override, subagent-stop-check
- **Inline per-gate recording:** pre-merge (7 gates), stop-check (5 exit paths)
- **Excluded (non-gatekeeping):** judge.sh (no preamble), workflow-orchestrator.sh,
  inject-skill.sh, session-start.sh (always exit 0, no pass/block)

**Reversibility:** Two-way door. Remove recording calls.

### Retention: single file, no rotation

**Options:** (1) Single file, (2) Monthly rotation, (3) Size-based rotation
**Choice:** Single append-only file.
**Why:** Solo/small-team project. Hundreds of events per month = <1MB/year.
Rotation adds query complexity (glob + merge) for no benefit at this scale.
**Upgrade path:** Add `--rotate` or monthly files if the file grows large.

### Stop reason derivation: hook-derived, not LLM-supplied

**Options:** (1) Hook infers from exit path, (2) LLM provides reason
**Choice:** Hook-derived from each exit path in stop-check.sh.
**Why:** Deterministic. No prompt engineering. Each exit path in stop-check.sh
has a known reason: non-enforced branch type (line 15), stop hook disabled in
profile (line 22), no PR number (line 27), API failure (line 51), block with
specific missing gates (line 138), or pipeline complete (line 141). The hook
knows exactly which path it took.

## Architecture

```
Recording flow:

  Simple hooks (post-edit-check, pre-pr-create, etc.):
    hook.sh → rh_pass()/rh_block() → auto-calls rh_record_event()
                    │                          │
                    ▼                          ▼
              stderr (display)       .stats/events.jsonl
              🥊 hook — ✅/🚫

  Multi-gate hooks (pre-merge, stop-check):
    hook.sh → per-gate check → rh_record_event() inline
                │                      │
                ▼                      ▼
          rh_block_end()      .stats/events.jsonl
          (display only)      (one event per gate)

  Non-gatekeeping hooks (judge, orchestrator, inject-skill, session-start):
    hook.sh → no recording (always exit 0, no pass/block decision)

Stats query flow:
  ┌──────────────┐
  │ npx right-    │
  │ hooks stats   │
  └──────┬───────┘
         ▼
    src/stats.js
    ├── read events.jsonl
    ├── group by gate → pass/block counts
    ├── group by stop_reason → human involvement
    └── print table
```

## Event Schema

Each event is one JSON line in `.right-hooks/.stats/events.jsonl`:

```json
{"ts":"2026-03-23T14:30:00Z","hook":"pre-merge","gate":"ci","result":"pass","branch":"feat/stats","pr":12}
{"ts":"2026-03-23T14:30:01Z","hook":"pre-merge","gate":"codeReview","result":"block","branch":"feat/stats","pr":12}
{"ts":"2026-03-23T14:35:00Z","hook":"stop-check","gate":"stop","result":"block","branch":"feat/stats","pr":12,"stop_reason":"missing_review"}
{"ts":"2026-03-23T14:40:00Z","hook":"stop-check","gate":"stop","result":"pass","branch":"feat/stats","pr":12,"stop_reason":"pipeline_complete"}
{"ts":"2026-03-23T15:00:00Z","hook":"post-edit-check","gate":"postEditCheck","result":"pass","branch":"feat/stats"}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ts` | ISO 8601 string | yes | UTC timestamp |
| `hook` | string | yes | Hook that recorded the event |
| `gate` | string | yes | Gate name or "stop" |
| `result` | "pass" \| "block" | yes | Outcome |
| `branch` | string | yes | Current branch |
| `pr` | number | no | PR number if available |
| `stop_reason` | string | no | Only on stop events |

### Stop Reasons

**Pass events** (agent actually stops — human re-engages):

| stop_reason | Exit path | Meaning |
|-------------|-----------|---------|
| `pipeline_complete` | Line 141 — all checks passed | Ideal: ready for merge |
| `no_pr` | Line 27 — no PR number | Agent stopped outside PR flow |
| `stop_disabled` | Line 22 — stopHook=false in profile | Profile doesn't enforce stop |
| `non_enforced_branch` | Line 15 — branch type not in set | Branch type skips stop-check |
| `api_unavailable` | Line 51 — GitHub API failed | Checks skipped, agent stops |

**Block events** (agent prevented from stopping — continues working):

| stop_reason | Condition | Meaning |
|-------------|-----------|---------|
| `missing_review` | No review comment/sentinel | Review not done yet |
| `missing_qa` | No QA comment/sentinel | QA not done yet |
| `missing_review_sentinel` | Comment exists, no sentinel | Subagent didn't write sentinel |
| `missing_qa_sentinel` | Comment exists, no sentinel | Subagent didn't write sentinel |
| `review_signature_mismatch` | Sentinel verified, wrong sig | Wrong skill produced review |
| `qa_signature_mismatch` | Sentinel verified, wrong sig | Wrong skill produced QA |

Note: Block events don't count as "human involvement" — the agent keeps going.
Only pass events appear in the Human Involvement table.

## CLI Output

```
🥊 Right Hooks Stats
───────────────────────────────────────────────
Gate              Pass  Block  Block%
ci                  42      3    6.7%
dod                 40      5   11.1%
docConsistency      45      0    0.0%
codeReview          38      7   15.6%
qa                  39      6   13.3%
learnings           35     10   22.2%
planningArtifacts   12      1    7.7%

Human Involvement            Count
pipeline_complete                8
no_pr                            3
stop_disabled                    2
api_unavailable                  1
non_enforced_branch              1
───────────────────────────────────────────────
Total events: 247 | Since: 2026-03-22
Avg stops per PR: 2.1 | Ideal (1.0 = fully automated)
```

No flags for MVP. Filtering (`--since`, `--pr`) deferred.

## Scope

### In scope

- `rh_record_event` function in `_preamble.sh`
- Auto-recording wired into `rh_pass` / `rh_block` (simple hooks)
- Inline per-gate recording in `pre-merge.sh` (7 gates)
- Per-exit-path recording in `stop-check.sh` (5 pass paths, 1 block path)
- `src/stats.js` CLI command
- `bin/right-hooks.js` dispatch for `stats` command
- `.stats/` directory creation in `init.js` and `doctor.js`
- `.gitignore` entry for `.right-hooks/.stats/`
- Unit tests for `rh_record_event` and stop reason derivation
- Unit tests for `src/stats.js` aggregation logic

### Out of scope

- `--since` / `--pr` filtering (deferred — add when needed)
- Monthly file rotation (deferred — single file is fine at this scale)
- Time-series trends / sparklines (deferred — Phase 3.5 if wanted)
- Dashboard / web UI (deferred indefinitely)
- Team velocity metrics (PR duration, cycle time — different feature)
- Learning accumulation metrics (different feature)
- SQLite migration (deferred — JSONL is sufficient)

## Eng Review Findings (2026-03-23)

Changes from /plan-eng-review:

1. **Recording API**: `rh_pass`/`rh_block` take optional 3rd arg (gate name).
   When present, auto-records. When absent (pre-merge summary), skips.
   `rh_record_event` accepts all fields as parameters — no network calls inside.

2. **Stop reasons simplified**: Block reasons collapsed from 6 to 2:
   `missing_review` and `missing_qa` only. Sub-reasons (sentinel missing,
   signature mismatch) are diagnostic detail already in the block message.

3. **Performance**: `rh_record_event` must NOT call `rh_branch()` or
   `rh_pr_number()`. Callers pass these values if they already have them.
   Simple hooks (post-edit-check) omit PR number entirely.

4. **Test coverage**: Extend existing integration tests (`lifecycle_test.sh`)
   to verify `events.jsonl` output after hook runs. Three test files total:
   `test-record-event.sh`, `test-stats.sh`, plus integration test extensions.

5. **Path convention**: Use `.right-hooks/.stats/` (hardcoded relative, like
   all other preamble paths). No `$RH_DIR` variable.

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `hooks/_preamble.sh` | modify | Add `rh_record_event`, wire into `rh_pass`/`rh_block` for simple hooks |
| `hooks/pre-merge.sh` | modify | Add inline `rh_record_event` at each of 7 gate check points |
| `hooks/stop-check.sh` | modify | Add `rh_record_event` at all 6 exit paths with stop_reason |
| `src/stats.js` | create | CLI command — read JSONL, aggregate, print table |
| `bin/right-hooks.js` | modify | Add `stats` case to command dispatch |
| `src/init.js` | modify | Create `.stats/` directory during init |
| `src/doctor.js` | modify | Check `.stats/` directory exists |
| `.gitignore` | modify | Add `.right-hooks/.stats/` |
| `tests/unit/hooks/test-record-event.sh` | create | Unit tests for recording function |
| `tests/unit/cli/test-stats.sh` | create | Unit tests for stats aggregation |
