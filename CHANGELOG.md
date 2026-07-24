# Changelog

All notable changes to VM Sentinel are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]
- Complete the manual Unraid 7.2 test matrix (`docs/TESTING.md`).
- Resolve remaining `docs/RESEARCH.md` §7 hardware-verification items.

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

[Unreleased]: https://github.com/BGriffin63/unraid-vm-sentinel/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/BGriffin63/unraid-vm-sentinel/releases/tag/v0.1.1
[0.1.0]: https://github.com/BGriffin63/unraid-vm-sentinel/releases/tag/v0.1.0
