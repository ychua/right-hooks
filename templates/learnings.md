# Learnings: [Feature Name]

**PR:** #[number]
**Branch:** [branch]
**Date:** [YYYY-MM-DD]

## Orchestrator

### What Went Wrong
- [Repeated fixes attempted — what failed and why]
- [Wrong turns and detours — approaches tried then abandoned]
- [Debugging dead-ends — hypotheses that turned out to be wrong]

### What Went Right
- [Approaches that worked well]
- [Tools or techniques that saved time]

### Unnecessary Human Involvement
- [Where the agent could have been autonomous but asked for help]
- [Example: copying build logs instead of reading via `gh run view`]

### Rules to Extract
- [Actionable rule for future agents — one line, no context needed]
- [Example: "Always run `tsc --noEmit` before declaring implementation complete"]

---

## Review Agent

### Findings Summary
- [Key issues found during code review]
- [Patterns noticed across the codebase]

### What Was Missed
- [Issues that should have been caught earlier]
- [Suggestions for improving the review process]

### Rules to Extract
- [Actionable rule for future reviews]

---

## QA Agent

### Findings Summary
- [Test gaps identified]
- [DoD items that weren't fully implemented]

### What Was Missed
- [Edge cases not tested]
- [Integration points not verified]

### Rules to Extract
- [Actionable rule for future QA]

---

## Post-Merge Extraction

*After merge, extract actionable rules from above into `.right-hooks/rules/learned-patterns.md`.*
*Format: one line per rule, actionable, no context.*
