# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Right Hooks, please report it responsibly.

**Do NOT open a public issue.**

Instead, use [GitHub's private vulnerability reporting](https://github.com/ychua/right-hooks/security/advisories/new).

You should receive a response within 48 hours. We'll work with you to understand
the issue and coordinate a fix before public disclosure.

## Scope

Right Hooks runs locally as shell hooks and a Node.js CLI. It:
- Reads/writes files in `.right-hooks/` and `.claude/`
- Calls `gh` CLI for GitHub API access (uses existing auth)
- Never sends data to external servers
- Never stores credentials (relies on `gh auth`)

## Known Limitations

1. **Hook checksums detect tampering but don't prevent it.** An agent could modify
   hooks — checksums make this visible, not impossible.
2. **An agent could `rm -rf .right-hooks/`.** Defense is visibility (doctor detects
   this), not prevention.
3. **Override files are committed to git.** This is by design — they provide a
   visible audit trail in the PR diff.
