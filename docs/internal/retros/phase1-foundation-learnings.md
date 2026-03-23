# Phase 1: Solid Foundation — Learnings

## Review

### What the review found
- Gate defaults bug was the highest-impact finding — 3 of 8 gates were always enforced
  regardless of profile, breaking the custom profile's "all false" mode
- Shell pipeline gotchas (`grep -c || echo "0"` doubling output, `gh api --paginate`
  producing multiple JSON arrays) were only caught in production when the stop hook ran
  against a real PR — unit tests didn't cover these paths
- Codex independent review caught that VCS abstraction was premature — "abstraction
  without a validating implementation" — which saved significant wasted work

### What went well
- CEO + Eng review pipeline produced a well-prioritized, phased plan
- DRY extraction of `rh_gate_value()` simplified two hooks simultaneously
- Comment batching reduced API calls from 8+ to 3-4 per merge check

## QA

### What QA found
- All 120 unit tests pass
- Bash syntax valid across all modified hooks
- `grep -c` pipe safety correctly handled
- Paginated API responses correctly flattened
- No regressions in existing test suites

### What QA missed initially
- The `grep -c || echo "0"` doubling bug was only caught by the live stop hook,
  not by QA verification — indicates a gap in integration testing
- The `gh pr diff --name-only` multi-commit output behavior wasn't tested

## What surprised us
- `grep -c` returns exit code 1 on zero matches while still printing "0" to stdout —
  this is POSIX-compliant but unintuitive and caused three iterations to fix
- `gh pr diff --name-only` outputs filenames per-commit, not per-PR, so multi-commit
  PRs produce duplicate filenames
- `gh api --paginate` outputs separate JSON arrays per page, not one merged array

### Rules to Extract

- Always use `{ grep -c PATTERN || true; }` instead of `grep -c PATTERN || echo "0"` — grep -c already outputs the count, the fallback doubles it
- Always pipe `gh api --paginate` through `jq -s 'add // []'` to flatten page arrays into one
- Always pipe `gh pr diff --name-only` through `sort -u` to deduplicate multi-commit output
- When dogfooding hooks, run them against a real PR early — unit tests with RH_TEST=1 skip the codepaths that matter most
- Don't build abstractions (VCS layer) without a second implementation to validate against — defer until needed
- CI and doc consistency should be hard-enforced gates (no profile override, no escape hatch)
- Copy source hooks to .right-hooks/hooks/ after modifying — the installed copies are what actually run
