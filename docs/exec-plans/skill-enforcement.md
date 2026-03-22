---
status: COMPLETE
design_doc: docs/designs/skill-enforcement.md
---
# Execution Plan: 3-Level Skill Enforcement

## Tasks (all complete)

1. Add `skillSignature` to skills.json templates (gstack, superpowers, generic)
2. Add `rh_skill_signature_match` helper to _preamble.sh
3. Add `rh_skill_provenance_check` helper to _preamble.sh
4. Update stop-check.sh — verify signature + provenance after sentinel
5. Update pre-merge.sh — verify signature + provenance for review/QA/doc
6. Update CLAUDE.md with provenance protocol
7. Update .gitignore for provenance files
8. Update integration tests with provenance + skill signatures

## Definition of Done

- [x] All 3 levels enforced for review, QA, doc consistency gates
- [x] Null skills (prompt-based) skip signature + provenance checks
- [x] Integration tests verify the full flow
- [x] All 179 tests pass
