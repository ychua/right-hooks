# Git Workflow

- **All work happens on branches** — never commit directly to `master` or `main`
- All changes go through a PR process with CI checks passing before merge

## Branch Naming Convention

Branches must follow `{type}/{description}`. Enforced by husky pre-push hook.

| Type | When to use |
|------|-------------|
| `feat` | New feature (requires design doc + exec plan) |
| `fix` | Bug fix |
| `chore` | Maintenance, dependency updates |
| `docs` | Documentation changes |
| `test` | Test additions or fixes |
| `hotfix` | Urgent production fix |
| `refactor` | Code restructuring (no behavior change) |
| `perf` | Performance improvement |
| `ci` | CI/CD changes |
| `plan` | Planning PRs (design doc + exec plan only, no code) |

Description: lowercase alphanumeric with dashes.
Example: `feat/user-auth`, `fix/hook-false-positive`.

## Parallel Work (recommended)

For working on multiple features simultaneously, git worktrees provide isolation
without switching branches:

```bash
git worktree add .worktrees/<name> -b <branch-name>
```

Add `.worktrees/` to `.gitignore`. This is optional — regular branches work fine
for sequential work.

## Enforcement by Branch Type

| Branch type | CI | DoD | Doc check | Planning | Review/QA | Learnings |
|---|---|---|---|---|---|---|
| `feat/` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `fix/` | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `refactor/` | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| `docs/` | ✓ | ✓ | ✓ | — | — | — |
| `chore/` | ✓ | ✓ | ✓ | — | — | — |
| `hotfix/` | ✓ | ✓ | ✓ | — | — | — |

## Secret Management

- **Never commit secrets** (database URLs, API keys, tokens) to the repository
- Write code that reads secrets from environment variables or `.env` files (gitignored)
- Use `.env.example` files to document required environment variables
