# Execution Plan: Flow-Based Orchestration

**Status:** COMPLETE
**Design Doc:** docs/designs/flow-orchestration.md
**Branch:** feat/flow-orchestration
**Date:** 2026-03-23

## Implementation Steps

### Step 1: PostToolUse workflow orchestrator
- [x] Create `hooks/workflow-orchestrator.sh` with 4-layer fast-exit
- [x] Implement trigger detection (gh pr create, sentinel writes, gh pr comment)
- [x] Implement workflow state tracking (.right-hooks/.workflow-state)
- [x] Implement skill content loading (3-tier fallback)
- [x] Implement systemMessage JSON output
- [x] Write 22 unit tests (test-workflow-orchestrator.sh)

### Step 2: SubagentStart skill injection
- [x] Create `hooks/inject-skill.sh` with agent-name-to-gate mapping
- [x] Implement 4-tier skill content loading (reuse from orchestrator)
- [x] Create generic agent definitions (reviewer.md, qa-reviewer.md, doc-reviewer.md)
- [x] Write 25 unit tests (test-inject-skill.sh)

### Step 3: Update gate messaging
- [x] Update stop-check.sh to say "Spawn the 'reviewer'/'qa-reviewer' agent"
- [x] Update pre-merge.sh to say "Spawn the 'doc-reviewer' agent"
- [x] Sync all hooks to .right-hooks/hooks/
- [x] Verify all 265+ tests pass

## Definition of Done

- [x] All CI checks green
- [x] All test stubs filled and passing (265 unit + 13 integration)
- [x] No manual human steps remaining
- [x] Verification checklist complete
- [x] DoD copied to PR description as checklist
- [ ] Learnings document created
- [ ] Review agent findings addressed
- [ ] QA agent findings addressed

## Verification Checklist

- [x] workflow-orchestrator fast-exits for non-Bash tools
- [x] workflow-orchestrator fast-exits for irrelevant commands
- [x] workflow-orchestrator injects review after gh pr create
- [x] inject-skill maps all agent names correctly
- [x] inject-skill falls back gracefully without skill files
- [x] inject-skill output is valid JSON
- [x] stop-check references 'reviewer' and 'qa-reviewer' agents
- [x] pre-merge references 'doc-reviewer' agent
- [x] All agents have sentinel + provenance protocol

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| SubagentStart JSON schema differs from assumption | Hook silently fails | Generic fallback ensures no crash; fast-exit on missing agent_name |
| Workflow orchestrator adds latency to every Bash call | Slower agent execution | 4-layer fast-exit; no-op path avoids jq beyond initial parse |
| Skill file not found at expected path | Subagent gets generic instructions | 4-tier fallback: project → home → skills.json → generic |
