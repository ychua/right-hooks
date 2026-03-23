# Design: 3-Level Skill Enforcement

## Problem

The configurable skills system (PR #7) suggests skills but doesn't enforce
them. An agent can see "Run /review" in the block message, ignore it, and
post a manually crafted comment that matches the generic signature pattern.
The hooks accept it because they only check comment existence, not skill usage.

## Solution

Three enforcement levels, all required when a skill is configured:

1. **Behavioral** — hook block messages suggest the configured skill (existing)
2. **Signature** — new `skillSignature` regex in skills.json that the PR comment
   body must match. Each skill produces distinctive output markers.
3. **Provenance** — agent writes `.right-hooks/.skill-proof-{gate}` with the
   skill name after invocation. Hook verifies file matches configured skill.

When `skill` is null (prompt-based), levels 2-3 are skipped.

## Alternatives

- **Signature only (no provenance)**: Agents could study the signature pattern
  and craft matching comments. Rejected — provenance adds a second factor.
- **Provenance only (no signature)**: Agents could write provenance without
  actually running the skill. Rejected — signature verifies the output quality.
- **Platform-level enforcement**: Modify Claude Code to track skill invocations.
  Out of scope — we can't change the platform.

## Scope

**In:** skillSignature field, rh_skill_signature_match, rh_skill_provenance_check,
hook updates, CLAUDE.md protocol, integration test updates

**Out:** Platform-level skill tracking, automatic provenance writing by skills
