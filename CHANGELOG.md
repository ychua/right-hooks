# Changelog

All notable changes to Right Hooks will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] - 2026-04-01

Hook surface expansion: Right Hooks now uses 11 of 25 Claude Code hook events (up from 6). Three new hooks close enforcement gaps, three bug fixes make existing hooks actually work, and the official Claude Code hooks API schema is now the source of truth.

### Fixed
- **inject-skill.sh schema bug.** The hook read `.agent_name` from SubagentStart events, but the official schema provides `.agent_type` and `.agent_id`. Skill injection was silently failing for all subagents. Now reads `.agent_type` and resolves gates via `skills.json` `agentTypes` arrays with a legacy fallback for backward compatibility.
- **skills.js field preservation.** `npx right-hooks skills set` was dropping `agentTypes`, `skillSignature`, and any other fields not explicitly listed. Now spreads the existing entry before overriding.
- **settings-merge.js matcher awareness.** The settings merge deduped hooks by command string only. Same command under a different matcher was treated as duplicate. Now keys on `matcher+command`.

### Added
- **agent-spawn-guard.sh** (PreToolUse Agent) — defense-in-depth guard for agent spawning. Allows unknown agent types (log only), blocks dangerous patterns in prompts (override attempts, hook directory destruction, settings.json modification).
- **stop-failure-logger.sh** (StopFailure) — logs agent death events (rate limits, auth failures, server errors) to `.stats` for display in `npx right-hooks stats`.
- **block-scheduling.sh** (PreToolUse CronCreate|CronDelete|RemoteTrigger) — blocks agents from scheduling their own future autonomous runs. Overridable via `npx right-hooks override --gate=scheduling`.
- **Session Failures section in `npx right-hooks stats`** — shows agent death events grouped by error type with count and last seen date.
- **`agentTypes` field in skills.json** — maps agent types to gates, replacing the hardcoded case statement. All three skills templates (gstack, superpowers, generic) updated.
- **`rh_resolve_gate_for_agent_type` helper in `_preamble.sh`** — shared function for agent type resolution, used by both inject-skill and agent-spawn-guard.
- **Hook API Coverage table in README** — documents which of the 25 Claude Code hook events Right Hooks uses and why.

### Changed
- Hook count increased from 12 to 15 (3 new hooks added to `doctor.js` expectedHooks).
- `settings.json` now registers 4 additional event types: `SubagentStart`, `StopFailure`, PreToolUse `Agent`, PreToolUse `CronCreate|CronDelete|RemoteTrigger`.

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
