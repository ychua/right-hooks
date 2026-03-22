# Learned Patterns

> Auto-extracted from PR learnings by the post-merge hook.
> Do not edit manually — new rules are appended automatically.

- Always pipe `gh api --paginate` through `jq -s 'add // []'` to flatten page arrays into one
- Always pipe `gh pr diff --name-only` through `sort -u` to deduplicate multi-commit output
- Always use `{ grep -c PATTERN || true; }` instead of `grep -c PATTERN || echo "0"` — grep -c already outputs the count, the fallback doubles it
- CI and doc consistency should be hard-enforced gates (no profile override, no escape hatch)
- Copy source hooks to .right-hooks/hooks/ after modifying — the installed copies are what actually run
- Don't build abstractions (VCS layer) without a second implementation to validate against — defer until needed
- When dogfooding hooks, run them against a real PR early — unit tests with RH_TEST=1 skip the codepaths that matter most
- Use charmbracelet/gum for terminal UI instead of hand-drawing ASCII boxes — cleaner code, better output
- Always use heredoc redirect (`<<< "$(printf ...)"`) not pipe (`printf ... | while`) when the loop body modifies parent shell state
- Optional CLI tools should be detected once in preamble and cached in a variable, not checked per-call
- Always use dynamic default branch detection (`git symbolic-ref refs/remotes/origin/HEAD`) instead of hardcoding `master` or `main`
- When `2>/dev/null` is used on git commands, consider that silenced failures may mask real bugs
- `feat/` branches require both design doc and exec plan in the PR diff, not just existing in the repo
- `doctor --fix` correctly separates diagnosis from repair — same check logic, conditional fix actions
- The `master` hardcoding bug existed since the initial commit but wasn't caught until dogfooding on a `main`-based repo
- Test hooks against both `main` and `master` default branches in integration tests
- Always include a regression test when fixing a bug found during dogfooding
- Three new files (scaffold.js, diff.js, doctor.js changes) follow existing patterns well
- 25 new tests cover all three commands comprehensively
- Idempotency tested for scaffold (safe to run repeatedly)
- Both `--fix` and non-`--fix` paths tested for doctor
- No integration test for the `pre-pr-create` default branch detection fix
- Could add a test for `diff` comparing rules (currently only tests hooks)
- Always run Codex independent review for architectural changes — it catches different classes of issues than Claude
- When replacing hardcoded behavior with config, always include a fallback that preserves the exact current behavior for existing installs
- Shell functions that need to both `cd` and return a value should use a global variable (like `REPO`), not `echo` inside `$()`
- Use `HOME="$tmpdir"` in tests to isolate from the developer's real tool installations
- Spec review caught schema gaps, missing migration story, and jq injection risk
- Codex caught the backward-compat regression that would have removed tool-specific guidance for existing users
- The `$()` subshell issue in test helpers — a bash footgun that's easy to miss
- Test helpers that `cd` must not be called inside `$()` — the `cd` is lost in the subshell
- 17 new tests cover all 4 fallback tiers, CLI operations, and edge cases
- `HOME` override pattern needed for provider detection isolation in tests
- No integration test for the full lifecycle with skills.json (hook suggests skill → agent runs → sentinel written → hook passes)
- Always override HOME in tests that check provider availability — the developer's real installations leak through
