# Right Hooks — Developer Guide

## Architecture

Three-layer enforcement system for AI coding agents:

```
Layer 3: Custom (user-defined rules, lint gates, project-specific validations)
Layer 2: Language (preset-driven: tsc/mypy/cargo post-edit checks, orphan detection)
Layer 1: Universal (merge gates, push protection, stop hook, subagent verification)
```

All hooks follow the contract in `HOOK-CONTRACT.md`:
- Exit 0 = allow, Exit 2 = block, Exit 1 = error (fail open)
- JSON on stdin, human-readable reason on stderr
- Every hook sources `hooks/_preamble.sh` for shared helpers

## Project Structure

```
bin/right-hooks.js    CLI entry point (dispatches to src/)
src/                  CLI commands (init, status, doctor, override, upgrade, detect)
hooks/                Shell hooks (copied to user's .right-hooks/hooks/ on init)
  _preamble.sh        Shared helpers sourced by all hooks
rules/                Behavioral rules (symlinked to .claude/rules/ on init)
presets/              Language configs (typescript, python, go, rust, generic)
profiles/             Enforcement profiles (strict, standard, light, custom)
signatures/           Tool-specific comment patterns (gstack, superpowers, generic)
templates/            Design doc, exec plan, learnings templates
husky/                Git hooks (pre-push, post-merge)
tests/
  unit/               Shell-based unit tests (RH_TEST=1 mode)
    hooks/            Tests for each hook
    cli/              Tests for each CLI command
    helpers.sh        Shared test assertions
    run.sh            Test runner
  integration/        Bashunit integration tests
```

## Running Tests

```bash
npm test                  # Run both unit + integration
npm run test:unit         # Unit tests only (bash)
npm run test:integration  # Integration tests only (bashunit)
```

Tests run with `RH_TEST=1` which skips dependency/auth/integrity checks in the preamble.

## How Hooks Work

1. Claude Code reads `.claude/settings.json` which maps events to hook scripts
2. On each event (PreToolUse, PostToolUse, Stop, etc.), the hook script runs
3. The hook sources `_preamble.sh` for helpers, reads JSON from stdin
4. Fast-exit if the event isn't relevant (e.g., non-merge command)
5. Check gates from the matched profile, verify conditions, exit 0 or 2

Key helpers in `_preamble.sh`:
- `rh_gate_value <branch_type> <gate>` — get gate value from matched profile
- `rh_branch()` / `rh_branch_type()` / `rh_pr_number()` — git helpers
- `rh_has_override <gate> <pr_num>` — check for override file
- `rh_review_pattern()` / `rh_qa_pattern()` — signature patterns
- `rh_pass` / `rh_block` / `rh_info` / `rh_debug` — logging

## Adding a New Hook

1. Create `hooks/my-hook.sh` with the standard header:
   ```bash
   #!/usr/bin/env bash
   # RIGHT-HOOKS GENERATED — edits preserved on upgrade
   RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
   source "$(dirname "$0")/_preamble.sh"
   INPUT=$(cat)
   ```
2. Add the hook to `src/doctor.js` `expectedHooks` array
3. Add the hook config to `settings.json` under the appropriate event
4. Write tests in `tests/unit/hooks/test-my-hook.sh`

## Adding a New Preset

1. Create `presets/my-language.json` with `postEditValidation` and `orphanDetection`
2. Add detection logic in `src/detect.js` `DETECTORS` array
3. Test with `npx right-hooks preset my-language`

## Adding a New Profile

1. Create `profiles/my-profile.json` with `triggers.branchPrefix` and `gates`
2. Test with `npx right-hooks profile my-profile`

## Debugging

Set `RH_DEBUG=1` to see verbose hook output (profile matches, gate values, API calls).
Set `RH_QUIET=1` to suppress success messages.
