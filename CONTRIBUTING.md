# Contributing to Right Hooks

Thanks for your interest in contributing! Right Hooks is the process enforcement layer
for autonomous AI coding agents.

## Development Setup

```bash
git clone https://github.com/ychua/right-hooks.git
cd right-hooks
npm install
npm test
```

## Running Tests

```bash
npm test                  # All tests (unit + integration)
npm run test:unit         # Unit tests only (bash-based)
npm run test:integration  # Integration tests only (bashunit)
```

Tests run with `RH_TEST=1` which skips dependency/auth/integrity checks in the preamble.

## Project Structure

```
bin/          CLI entry point
src/          Node.js CLI commands
hooks/        Shell hooks (copied to user's .right-hooks/hooks/ on init)
rules/        Behavioral rules (symlinked to .claude/rules/)
presets/      Language configs (typescript, python, go, rust, generic)
profiles/     Enforcement profiles (strict, standard, light, custom)
signatures/   Tool-specific comment patterns
templates/    Design doc, exec plan, learnings templates
tests/        Unit + integration tests
```

## Adding a New Hook

1. Create `hooks/my-hook.sh` sourcing `_preamble.sh`
2. Add to `src/doctor.js` `expectedHooks` array
3. Add hook config to `settings.json`
4. Write tests in `tests/unit/hooks/test-my-hook.sh`
5. Update CLAUDE.md hooks reference

## Adding a New Gate

1. Add gate metadata to `src/gates.js` `GATE_REGISTRY`
2. Add gate to relevant profiles in `profiles/*.json`
3. Implement the check in the appropriate hook
4. Write tests
5. Run `npx right-hooks doctor` to verify consistency

## Pull Request Process

1. Fork the repo and create a branch (`feat/`, `fix/`, `chore/`, etc.)
2. Write tests first (TDD encouraged)
3. Run `npm test` — all tests must pass
4. Submit a PR with a clear description

## Code Style

- Shell: POSIX-compatible bash, explicit over clever
- Node.js: `'use strict'`, CommonJS, no external dependencies
- All output to stderr (hooks), stdout for data only
- Follow existing patterns — consistency beats novelty
