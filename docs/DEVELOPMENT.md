# VM Sentinel — Development Guide

## Layout

```
src/lib/           pure bash libraries (unit-testable off Unraid)
src/hooks/         libvirt hook + idempotent installer
src/notifications/ provider interface + native + discord + dispatcher
src/services/      processor, healthcheck, supervisor, tools
package/…/vm.sentinel/  WebGUI (PHP .page files, include/, js, css, icon)
tests/             unit + security + integration (bash harness)
scripts/           build / package / release / lint / test / validate / icons
```

The build (`scripts/build.sh`) copies `src/{lib,hooks,notifications,services}`
into the WebGUI package tree, so the installed layout mirrors the repo.

## Principles

- **Fail-open:** nothing on the VM lifecycle path may block or error a VM
  operation. The hook only validates + spools + exits 0.
- **No jq / no bundled binaries:** JSON is built/escaped by `src/lib/json.sh`.
- **Untrusted input** is validated at ingress (`src/lib/validate.sh`) and escaped
  at egress (JSON/HTML).
- **Locks** are dependency-free (`vms_lock_acquire` in `common.sh`), not `flock`.

## Running locally

```bash
scripts/test.sh        # full suite
scripts/lint.sh        # shellcheck + php -l + xmllint (installs in CI)
scripts/build.sh
scripts/package.sh     # produces build/*.txz + .sha256
scripts/validate.sh
python3 scripts/generate-icons.py
```

Tests set `VMS_*` env vars to a temp dir (see `tests/lib/testlib.sh`), so they
never touch a real host. Add a test file under `tests/{unit,security,integration}`
and it is auto-discovered by `tests/run.sh`.

## Adding a notification provider

1. Create `src/notifications/<name>.sh` defining `provider_<name>_send` that reads
   the exported `EV_*` fields and prints `ok=<0|1> code=<int> msg=<redacted>`.
2. Register it in `src/notifications/dispatch.sh` behind an enable gate.
3. Build JSON with `src/lib/json.sh`; validate any URL/host; enforce timeouts;
   redact secrets. Add unit + security tests.

Future providers (generic/Slack/Teams/Gotify/ntfy/Telegram) are intentionally
**not** implemented in v1 — see spec §12. Any generic-webhook provider must add
SSRF protections before shipping (see SECURITY.md).

## Coding standards

- Shell: `set -u`; quote expansions; no `eval`; no unquoted untrusted data in
  commands; ShellCheck clean at `-S warning`.
- PHP: escape output with `h()`; CSRF-check every state-changing POST; never echo
  secrets.
- Keep the hook tiny and side-effect-free beyond a single tmpfs write.
