#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../../hooks/judge.sh"

echo "judge"

cd "$TEST_TMPDIR"
mkdir -p .right-hooks
echo '{"language":"generic","orphanDetection":{"fileExtensions":[".ts",".js"]}}' > .right-hooks/active-preset.json

# Test 1: Block praise-heavy comment (fails multiple checks: praise ratio, no file refs, no severity, short)
describe "blocks praise-heavy comment"
PRAISE_COMMENT="Looks good!
Great job on this code!
Well done with the implementation!
Nice work overall!
Excellent structure!"
run_hook "$HOOK" "$PRAISE_COMMENT"
assert_exit_code 2 "$LAST_EXIT"

# Test 2: Stderr mentions too much praise
describe "stderr mentions too much praise"
assert_stderr_contains "Too much praise" "$LAST_STDERR"

# Test 3: Allow substantive review comment
describe "allows substantive review with file refs and severity"
GOOD_COMMENT="## Code Review Agent — Review Round 1

### Findings

**HIGH** — src/auth.ts:45 — The authentication handler doesn't validate JWT expiration.
The \`verifyToken\` function at src/auth.ts line 45 accepts expired tokens because it only checks
the signature but not the \`exp\` claim. This allows replay attacks with captured tokens.

**MEDIUM** — src/database.ts:112 — SQL query uses string concatenation instead of parameterized queries.
The query builder at src/database.ts constructs queries with template literals, which is vulnerable
to SQL injection when user input flows through the \`searchTerm\` parameter.

**LOW** — src/utils.ts:8 — Unused import of \`lodash\` adds unnecessary bundle weight.
The lodash import is unused after the refactor in commit abc123. Remove it to reduce bundle size.

**INFORMATIONAL** — src/config.ts:3 — Consider using environment-specific config files instead
of a single config object with conditionals. This would improve testability and make deployments
more predictable across staging and production environments.

### Summary
4 findings total: 1 HIGH, 1 MEDIUM, 1 LOW, 1 INFORMATIONAL.
The HIGH severity JWT issue should be fixed before merge."
run_hook "$HOOK" "$GOOD_COMMENT"
assert_exit_code 0 "$LAST_EXIT"

# Test 4: Block comment that's too short
describe "blocks comment that is too short"
SHORT_COMMENT="Reviewed src/index.ts — looks fine. MEDIUM severity."
run_hook "$HOOK" "$SHORT_COMMENT"
assert_exit_code 2 "$LAST_EXIT"

# Test 5: Block comment with no severity markers and few file refs
describe "blocks comment without severity markers and few file refs"
NO_SEVERITY="## Code Review

The authentication module has an issue with token validation that should be addressed.
The database access code uses string concatenation for queries which is a security concern.
The utility module has an unused import that should be cleaned up to reduce bundle size.
The configuration setup could benefit from environment-specific files for better deployments.
There are also concerns about the error handling which eats exceptions silently.
Additionally the request pipeline doesn't properly chain the next handler in some edge cases.
The codebase needs attention to security patterns especially around input validation
and proper error propagation through the request pipeline and the API access for robustness."
run_hook "$HOOK" "$NO_SEVERITY"
assert_exit_code 2 "$LAST_EXIT"

print_summary
