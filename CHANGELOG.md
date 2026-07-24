# Changelog

All notable changes to VM Sentinel are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]
- Complete the manual Unraid 7.2 test matrix (`docs/TESTING.md`).
- Resolve remaining `docs/RESEARCH.md` §7 hardware-verification items.

## [0.1.6] — 2026-07-24
### Fixed
- **Discord "Send test" failed unless Discord alerts were already enabled.** The
  test button exists to validate a webhook *before* enabling it, but the provider
  refused to run while `discord_enabled=0`. That gate lives in the dispatcher
  (which controls live events); the provider no longer re-checks it, so the test
  validates the saved webhook regardless of the enable toggle.
- **Health-check service could stop.** The processor and health loops now run
  each pass in a subshell, so a `set -u` fault on one VM can never terminate the
  loop (the service stays alive).

## [0.1.5] — 2026-07-24
### Fixed
- **Saves/tests still rejected with "Invalid CSRF token"** even after 0.1.4:
  Unraid rewrites `/var/local/emhttp/var.ini` frequently, so the `csrf_token`
  the page embedded no longer matched the value `save.php` read a moment later
  (a race, not staleness — a hard refresh did not help). The CSRF check now
  passes if *either* the token matches *or* the request is same-origin
  (`Origin`/`Referer` host == server host, which a cross-site attacker cannot
  forge) — a standard CSRF defense that is immune to the token race and still
  backed by Unraid's authenticated session.
- Test buttons now surface the real error instead of mislabeling a rejected
  request as "No providers enabled".

## [0.1.4] — 2026-07-24
### Fixed
- **Settings/webhook wouldn't save; test buttons did nothing.** The POST handler
  rejected every request with "Invalid CSRF token": in the POST execution
  context `parse_ini_file('/var/local/emhttp/var.ini')` could return false (the
  file is dynamic), so the expected token came back empty and the check failed
  closed. `vms_csrf_token()` now falls back to a raw regex read of `var.ini`, and
  when the token is genuinely unavailable in-context the check no longer
  hard-blocks an already-authenticated request (it still requires a token).
- CSRF/handler failures now return **JSON** and the WebGUI **shows the error
  on-screen** (vms.js no longer swallows non-JSON responses), so failures are
  never silent again.

## [0.1.3] — 2026-07-24
### Fixed
- **WebGUI blank page:** the settings UI used 5 separate `.page` files with
  Unraid multi-level menu nesting (a parent + children via `Menu=`), which on
  Unraid 7.2 rendered the page body blank (the PHP itself was error-free). The UI
  is now a **single self-contained page with in-page JS tabs** (Overview / VMs /
  Notifications / Event History / Diagnostics), which renders reliably. Removed
  the four child `.page` files and the shared nav include.
- `build-release.yml` now runs `php -l` on every `.php`/`.page` file and **aborts
  the release** on any parse error, so a broken WebGUI can never be published.

## [0.1.2] — 2026-07-24
### Fixed
- **Release tooling:** `release.sh` stamped the package `SHA256` by replacing a
  one-time placeholder, so the *second* release kept the previous release's hash
  (version updated, checksum did not) — an install would fail checksum
  verification. The stamper now rewrites the whole `sha256`/`version` entity
  lines every time, and `build-release.yml` fails the run if the stamped `.plg`
  hash does not match the built `.txz`. (The 0.1.1 hook fix is carried forward.)

## [0.1.1] — 2026-07-24
### Fixed
- **Critical:** the installed libvirt hook could not be executed
  (`Exec format error`, exit 126), and during the libvirt `prepare` phase this
  **blocked affected VMs from starting**. Cause: the installer prepended the
  ownership-marker comment ahead of the `#!` shebang, displacing it from line 1.
  The hook is now installed **verbatim** with the shebang on line 1 (and marker
  on line 2), and the installer refuses to install a source lacking a line-1
  shebang.
- **Hardening (fail-open):** the hook now handles the `prepare`/`reconnect`
  phases and exits `0` *before* sourcing any library, so a broken library, full
  disk, or other fault can never veto a VM start. Shebang changed to `#!/bin/bash`
  (always present on Unraid) to avoid `env` indirection on the critical path.
- Added `tests/integration/test_install_hook.sh` regression test asserting the
  installed hook has a line-1 shebang, is executable, passes `bash -n`, and exits
  0 on `prepare` — it reproduces and guards against this exact failure.

### Verified on hardware
- Confirmed that Unraid 7.2's libvirt **does execute `qemu.d/` hooks** (the
  previously highest-risk `[VERIFY]` assumption in `docs/RESEARCH.md` §7).

## [0.1.0] — 2026-07-23 (alpha status)
### Added
- Initial public **alpha** (release version `0.1.0`; alpha status noted here and
  via the Community Applications Beta flag).
- VM lifecycle monitoring via a namespaced libvirt `qemu.d/50-vm-sentinel` hook
  that coexists with other plugins and never blocks VM operations (fail-open).
- Spool + single-flight processor architecture (runtime in tmpfs).
- Honest intent classification: `expected` / `unexpected` / `indeterminate`.
- Native Unraid notifications provider + Discord webhook provider (rich embeds,
  no bot). Test buttons for both.
- Optional agentless health checks (ICMP / TCP / QEMU guest agent) with stateful
  thresholds, startup grace, and anti-spam.
- Event history (rotated JSON Lines), quiet hours, maintenance suppression,
  per-event cooldown, deduplication.
- WebGUI: Overview, VM Configuration, Notification Settings, Event History,
  Diagnostics (with a sanitized support bundle).
- Original logo + programmatic icon generator.
- Automated unit / security / integration test suite; CI workflows; build,
  package, release, and validation scripts; full documentation set.

### Known issues
- Not yet validated on a broad matrix of real Unraid 7.2 hardware. Several
  platform assumptions are flagged **[VERIFY]** (see `docs/RESEARCH.md`).
- No automatic VM restart/recovery (intentionally out of scope for v1).

[Unreleased]: https://github.com/BGriffin63/unraid-vm-sentinel/compare/v0.1.6...HEAD
[0.1.6]: https://github.com/BGriffin63/unraid-vm-sentinel/releases/tag/v0.1.6
[0.1.5]: https://github.com/BGriffin63/unraid-vm-sentinel/releases/tag/v0.1.5
[0.1.4]: https://github.com/BGriffin63/unraid-vm-sentinel/releases/tag/v0.1.4
[0.1.3]: https://github.com/BGriffin63/unraid-vm-sentinel/releases/tag/v0.1.3
[0.1.2]: https://github.com/BGriffin63/unraid-vm-sentinel/releases/tag/v0.1.2
[0.1.1]: https://github.com/BGriffin63/unraid-vm-sentinel/releases/tag/v0.1.1
[0.1.0]: https://github.com/BGriffin63/unraid-vm-sentinel/releases/tag/v0.1.0
