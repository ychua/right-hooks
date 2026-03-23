# Stats & Observability Learnings

## Review Agent

### What Went Right
- Design spec + eng review before implementation caught 4 real issues (recording API, stop reasons, performance, test coverage)
- Plan reviewer caught broken unit tests (mock-gh needed for PR-dependent hooks)
- Shell-native recording approach validated: <1ms overhead, zero dependencies

### What Went Wrong
- `&&`/`||` anti-pattern in per-gate recording identified post-implementation — attempting to fix via sed introduced a regression (pre-merge test broke). Reverted and left the working pattern.
- Pre-push integration test flakiness caused by `.stats/events.jsonl` persisting between tests — `git checkout` failed silently when untracked files blocked branch switch
- The `git config core.bare=true` bug was caused by debug work in `/tmp` repos leaking config changes

### Unnecessary Human Involvement
- None — the brainstorm → design → eng review → plan → build → review/QA/doc cycle ran end-to-end

### Rules to Extract
- Always use `if/else` over `&&`/`||` when both branches have side effects — the `A && B || C` pattern executes C if B fails, not just if A fails
- Integration tests that create files in `.right-hooks/` should clean up in `set_up()` or use `git stash` fallback for branch switches
- When adding recording/telemetry to hooks, ensure the recording function has zero subprocesses — cache values like branch name at source time

## QA Agent

### What Went Right
- 326 tests total (309 unit + 17 integration) — comprehensive coverage
- Edge cases tested: empty file, missing file, malformed JSON, missing PR number, RH_QUIET mode
- Integration tests verify end-to-end event recording after hook runs

### What Went Wrong
- The jq parse error on PR comments with control characters was not caught in QA — only surfaced during merge attempt

### Rules to Extract
- Test the merge flow end-to-end, not just individual hooks — the pre-merge hook's jq pipeline can fail on real PR comments containing control characters
- When testing CLI output, verify both presence and absence (stop block events should NOT appear in Human Involvement table)
