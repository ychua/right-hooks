# Design Docs

Design docs are decision records, not just summaries. They exist so that future
agents and developers can understand WHY a decision was made — not just WHAT was
decided. Conversation history is ephemeral; design docs are permanent.

Every design doc MUST include:

1. **Problem statement** — What breaks without this work? Be specific about
   failure modes.

2. **Alternatives considered** — Every serious option, with concrete pros/cons.
   Include options that were rejected and why. An agent picking this up in
   3 months should not re-litigate a decision that was already thoroughly
   evaluated.

3. **Technical decisions** — For each non-obvious choice, document:
   - **Options considered** (at least 2-3, with concrete descriptions)
   - **Choice made** and **why** (the reasoning, not just the label)
   - **What we'd lose** with other options (make the tradeoff explicit)
   - **Reversibility** (one-way door vs two-way door)
   - **Upgrade path** (how to change this decision later if needed)

4. **Architecture** — ASCII diagrams of system flow, data paths, error handling.

5. **Scope** — What's in, what's out, and why each out-of-scope item was excluded.

The execution plan (`docs/exec-plans/`) implements what the design doc decides.
The design doc captures the thinking; the execution plan captures the steps.
Both are required for `feat/` branches.

## Exec Plan Lifecycle

When implementation is complete, set the exec plan's status to COMPLETE and
move it from `active/` to `completed/`.

## Anti-patterns

- A design doc that only lists decisions without rationale (a table of choices
  is not a design doc)
- Rationale trapped in conversation history instead of written down
- "We chose X" without "because Y, and not Z because..."
- Decisions made during implementation that aren't back-ported to the design doc
