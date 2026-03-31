# Right Hooks — Developer Guide

## Rules for AI Agents

**NEVER run `right-hooks override`.** Overrides are reserved for humans only.
The `block-agent-override` hook mechanically enforces this, but the rule is
also behavioral: if a gate blocks you, fix the underlying issue — don't try
to bypass enforcement. If you're stuck, ask the human to override.

**NEVER modify `.claude/settings.json` hooks.** The `config-change` hook blocks
this, but don't attempt workarounds. The hook configuration is the enforcement
contract.

**Always sync source hooks to `.right-hooks/hooks/`** after modifying files in
`hooks/`. The installed copies in `.right-hooks/hooks/` are what actually run.

**Always run all tests locally before pushing.** The husky pre-push hook enforces
this, but don't bypass with `HUSKY=0`. If tests fail, fix them.

**NEVER post review or QA comments directly.** Always dispatch a real subagent
to do the review/QA work. The stop hook verifies comments via sentinel files
(`.right-hooks/.review-comment-id`, `.right-hooks/.qa-comment-id`). Comments
without sentinel verification will be flagged as potentially faked.

Subagents must follow this protocol after posting:
```bash
COMMENT_URL=$(gh pr comment $PR_NUM --body "$FINDINGS" 2>&1)
COMMENT_ID=$(echo "$COMMENT_URL" | grep -oE '[0-9]+$')
echo "$COMMENT_ID" > .right-hooks/.review-comment-id  # or .qa-comment-id
```

**ALWAYS use the configured skill** for review, QA, and doc consistency. Check
`.right-hooks/skills.json` for the configured skill per gate. After invoking a
skill, write provenance so the hooks can verify:
```bash
echo "/review" > .right-hooks/.skill-proof-codeReview
echo "/qa" > .right-hooks/.skill-proof-qa
echo "/document-release" > .right-hooks/.skill-proof-docConsistency
```
Hooks verify three things: (1) sentinel file proves real comment, (2) comment
matches the skill's signature pattern, (3) provenance file proves the configured
skill was invoked. All three must pass.

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
src/                  CLI commands (init, scaffold, status, skills, stats, explain, gates, doctor, diff, override, upgrade, detect)
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
- `rh_match_profile <branch_type>` — find most-specific profile, sets `RH_MATCHED_PROFILE`
- `rh_gate_value <gate>` — get gate value from previously matched profile
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

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
