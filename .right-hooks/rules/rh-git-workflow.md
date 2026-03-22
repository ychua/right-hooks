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

## Enforcement Method

How each check is enforced. **GH** = Git Hook, **CH** = Claude Code Hook, **B** = Behavioral.

| Check | Method | Hook / Source |
|---|---|---|
| Push protection | GH + CH | `husky/pre-push` + `pre-push-master.sh` |
| Branch naming | GH | `husky/pre-push` |
| CI green | CH | `pre-merge.sh` |
| DoD complete | CH | `pre-merge.sh` |
| Doc consistency | CH | `pre-merge.sh` |
| Planning artifacts | CH | `pre-pr-create.sh` |
| Review comment | CH | `pre-merge.sh` + `stop-check.sh` |
| QA comment | CH | `pre-merge.sh` + `stop-check.sh` |
| Learnings + Rules to Extract | CH | `pre-merge.sh` + `husky/post-merge` |
| Post-edit validation | CH | `post-edit-check.sh` |
| Subagent output | CH | `subagent-stop-check.sh` |
| Override protection | CH | `block-agent-override.sh` |
| Config tamper | CH | `config-change` |
| TDD discipline | B | `rh-testing.md` |
| Design doc quality | B | `rh-design-docs.md` |
