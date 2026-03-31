# Exec Plan: Hook Surface Expansion

Status: COMPLETE

## Definition of Done

- [x] inject-skill.sh reads agent_type (not agent_name)
- [x] skills.js preserves extra fields on skills set
- [x] settings-merge.js keys on matcher+command
- [x] agent-spawn-guard.sh blocks dangerous patterns
- [x] stop-failure-logger.sh logs StopFailure events
- [x] block-scheduling.sh blocks CronCreate/RemoteTrigger
- [x] stats.js shows Session Failures section
- [x] skills.json templates have agentTypes arrays
- [x] doctor.js expectedHooks updated (15 hooks)
- [x] settings.json registers new event types
- [x] README has Hook API Coverage table
- [x] TODOS.md has FileChanged tamper detection (P2)
- [x] All 391 tests pass (374 unit + 17 integration)
- [x] All hooks valid bash
