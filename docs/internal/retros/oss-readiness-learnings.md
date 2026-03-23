# OSS Readiness Learnings

## Review Agent

### What Went Right
- CEO review + eng review before implementation caught the `prepare: husky` blocker and the corrupted temp file (`hooks/.!76736!pre-merge.sh`) — both would have shipped to npm
- Spec reviewer caught that docs reorg would break `pre-pr-create.sh` paths — eng review then correctly invalidated this concern (hooks check git diff, not filesystem)
- Gate registry design emerged naturally from the `explain` command requirement — now `doctor`, `status`, and `explain` all share a single source of truth
- Plan reviewer caught test framework mismatch (`it`/`assert_equals` don't exist in this project) before implementation started

### What Went Wrong
- `git add -A` in first commit picked up the entire `~/.claude/skills/gstack/` directory (233 files) — had to reset and re-commit. The `.gitignore` was missing `.claude/skills/`
- The CEO plan's "downstream impact" note for docs reorg was wrong — claimed hook paths needed updating, but hooks check `git diff --name-only` not filesystem paths. This would have caused unnecessary work if not caught in eng review

### Unnecessary Human Involvement
- None — the CEO review → eng review → plan → build → review/QA/doc cycle ran end-to-end

### Rules to Extract
- Always add `.claude/skills/` to `.gitignore` — user-local skill installations should never be committed to project repos
- Never use `git add -A` or `git add .` without checking `git status` first — it catches untracked files from tool installations
- When hooks check paths via `git diff --name-only`, moving files on main doesn't affect what the hook sees on feature branches — the check is against the branch diff, not the filesystem
- Use the project's actual test framework helpers (read `tests/unit/helpers.sh`) — don't assume standard testing patterns like `it`/`assert_equals` exist
- `npm pack --dry-run` is the single most important pre-publish check — catches junk files, corrupted names, and unintended directory inclusions
- The `prepare: husky` script must use `|| true` for npm packages — without it, `npm install` fails for consumers who don't have husky as a devDependency

## QA Agent

### What Went Right
- 348 unit tests + 17 integration tests — 39 new tests covering gates, explain, and colors
- ANSI color testing solved with `_RH_COLOR_FORCE=1` env var — avoids TTY dependency in CI
- `NO_COLOR` standard compliance tested explicitly
- Fuzzy matching for gate names (Levenshtein distance) tested with both match and no-match cases

### What Went Wrong
- No issues found during QA

### Rules to Extract
- For terminal color testing in CI, always provide a force-enable env var (like `_RH_COLOR_FORCE=1`) since CI has no TTY
- Follow the `NO_COLOR` standard (no-color.org) — don't invent custom env vars like `RH_NO_COLOR`
- When building CLI help systems, always include fuzzy matching for command/gate names — typos are the #1 new-user frustration
