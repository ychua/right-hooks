# Execution Plan: Init Integration for Flow Orchestration

**Status:** COMPLETE
**Design Doc:** docs/designs/init-flow-orchestration.md
**Branch:** feat/init-flow-orchestration
**Date:** 2026-03-23

## Implementation Steps

### Step 1: Wire hooks into settings.json template
- [x] Add PostToolUse/Bash entry for workflow-orchestrator.sh
- [x] Add SubagentStart entry for inject-skill.sh

### Step 2: Update init.js
- [x] Copy agents/*.md to .claude/agents/ during init

### Step 3: Update doctor.js
- [x] Add workflow-orchestrator.sh and inject-skill.sh to expectedHooks

### Step 4: Update upgrade.js
- [x] Copy/update agent definitions on upgrade

### Step 5: Update README and TODOS
- [x] Remove 🔜 markers from README
- [x] Update hook/agent counts
- [x] Mark Phase 2.5 complete in TODOS.md

## Definition of Done

- [x] All CI checks green (265 unit + 13 integration)
- [x] Doctor validates 12 hooks
- [x] Init installs 3 agents
- [x] README matches shipping state
