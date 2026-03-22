# Git Workflow

- **All work happens on branches** — never commit directly to `master` or `main`
- All changes go through a PR process with CI checks passing before merge

## Branch Naming Convention

Branches must follow `{type}/{description}`. Enforced by husky pre-push hook (GH).

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

## Enforcement by Branch Type

**GH** = Git Hook (husky), **CH** = Claude Code Hook, **B** = Behavioral (rules only)

| Branch type | Push protection | Branch naming | CI | DoD | Doc check | Planning | Review/QA | Learnings |
|---|---|---|---|---|---|---|---|---|
| `feat/` | GH + CH | GH | CH | CH | CH | CH | CH | CH |
| `fix/` | GH + CH | GH | CH | CH | CH | — | CH | CH |
| `refactor/` | GH + CH | GH | CH | CH | CH | — | CH | CH |
| `docs/` | GH + CH | GH | CH | CH | CH | — | — | — |
| `chore/` | GH + CH | GH | CH | CH | CH | — | — | — |
| `hotfix/` | GH + CH | GH | CH | CH | CH | — | — | — |

Additional enforcement (all branches):
| What | Type | Hook |
|------|------|------|
| Post-edit validation (tsc/mypy/cargo) | CH | `post-edit-check` |
| Stop prevention (no quitting before review) | CH | `stop-check` |
| Subagent output verification | CH | `subagent-stop-check` |
| Override protection (humans only) | CH | `block-agent-override` |
| Config tamper protection | CH | `config-change` |
| TDD discipline | B | `rules/testing.md` (opt-in) |
| Design doc quality | B | `rules/design-docs.md` (opt-in) |
