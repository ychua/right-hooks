# Changelog

All notable changes to Right Hooks will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.0.0] - 2026-03-23

### Added
- 12 Claude Code hooks for full lifecycle enforcement
- 2 git hooks via husky (pre-push test runner + post-merge learnings extraction)
- Multi-agent orchestration: workflow-orchestrator + inject-skill
- 3-level skill enforcement: signature + provenance + behavioral
- Configurable skill dispatch via `skills.json`
- 5 language presets: TypeScript, Python, Go, Rust, Generic
- 4 enforcement profiles: Strict, Standard, Light, Custom
- CLI commands: init, scaffold, status, skills, stats, doctor, diff, override, upgrade, explain
- Gate effectiveness metrics (`npx right-hooks stats`)
- Discoverable help system (`npx right-hooks explain <gate>`)
- ANSI color output with NO_COLOR standard support
- 330+ tests (unit + integration)
- HOOK-CONTRACT.md defining portable hook interface
