# Contributing to ReelSentry

Thanks for your interest! ReelSentry is host-level software for Unraid, so
safety and least-privilege are non-negotiable.

## Before you start
- Read [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) and
  [`docs/SECURITY.md`](docs/SECURITY.md).
- Discuss non-trivial changes in an issue first.

## Ground rules
- **Fail-open:** nothing may block or fail a VM lifecycle operation.
- No `eval`; no shell built from untrusted input; quote everything.
- No new runtime dependencies (no `jq`, no bundled binaries, no daemons).
- Validate all external input; escape all output (JSON/HTML).
- Never log/echo/export secrets.
- No telemetry, analytics, or calls to developer infrastructure.

## Workflow
1. Fork and branch from `main`.
2. Make your change with tests.
3. Run:
   ```bash
   scripts/lint.sh
   scripts/test.sh
   scripts/build.sh && scripts/package.sh && scripts/validate.sh
   ```
4. Update docs and `CHANGELOG.md` (`[Unreleased]`).
5. Open a PR describing the change, the risk, and how you tested it. For anything
   touching the hook, notifications, or install/uninstall, describe manual Unraid
   testing.

## Commit style
- Clear, imperative subject lines. Reference issues (`Fixes #123`).

## Reviews
- Expect a security-focused review for hook, provider, and install/uninstall
  changes.

## Code of Conduct
By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
