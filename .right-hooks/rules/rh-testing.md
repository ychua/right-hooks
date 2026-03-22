# Testing

**Every new feature, endpoint, or behaviour change MUST include tests.** No exceptions.

## TDD Process (mandatory)

All new code follows strict test-driven development:

**Phase 1 — Think (map all cases):**
Write ALL test cases as stubs before writing any assertions or implementation.
This is the thinking phase — map out every edge case, happy path, failure mode,
and boundary condition. The stub list IS the spec.

Language examples:
- JavaScript/TypeScript: `it.todo('should handle empty input')`
- Python: `@pytest.mark.skip(reason='not implemented')` or empty test body
- Go: `t.Skip("not implemented")`
- Rust: `#[ignore]`

**Phase 2 — Red-Green (one test at a time):**
Pick one stub. Fill in the assertion. Run it — it MUST fail (RED).
Write the minimum implementation to make that one test pass (GREEN).
Run again — it MUST pass. Move to the next stub. Repeat.

Do NOT write all test assertions at once. Do NOT write the full implementation
at once. One test → one implementation increment → verify → next.

**Phase 3 — Refactor:**
After all stubs are filled and green, refactor if needed. Tests must stay green.

**Anti-patterns:**
- Writing all tests with full assertions in one shot, then writing the full
  implementation (that's "test-alongside," not TDD)
- Writing implementation first and tests after (that's "test-after")
- Skipping the thinking phase (stubs) and jumping straight to assertions

## Test Layers

Most projects benefit from multiple test layers. Use what fits your project —
not every project needs all four.

```
      /\          Smoke: "Does production actually work?"
     /  \         Real requests → live deployment
    /----\
   /      \       E2E: "Does the system work end-to-end?"
  /        \      Real HTTP requests → running server
 /----------\
/            \    Integration: "Does it work with real dependencies?"
/              \  Real database, real filesystem, real services
/--------------\
/                \ Unit: "Does this function return the right output?"
/________________\ Pure functions. No I/O. Fast.
```

**Test at the lowest layer that meaningfully verifies the behaviour.**

## Directory Structure (recommended)

Organize tests however fits your project. Common patterns:

```
# Separate test directory (Node.js, Python, Go)
tests/
  unit/
  integration/
  e2e/

# Co-located tests (React, Rust)
src/
  feature/
    feature.ts
    feature.test.ts

# Language convention (Ruby, Elixir)
test/
spec/
```

## Rules

- **Prefer real dependencies over mocks when practical.** If you can test against
  a real database (e.g., Docker container), do that instead of mocking your ORM.
  This catches integration bugs that mocks hide. *(Opinionated — adjust to your
  project's constraints.)*
- **External services should be simulated.** Use fake HTTP servers, configurable
  base URLs, or recorded responses for third-party APIs you don't control.
- **New pure logic should be extractable** and unit tested independently.
