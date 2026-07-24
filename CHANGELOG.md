# Changelog

All notable changes to VM Sentinel are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]
- Complete the manual Unraid 7.2 test matrix (`docs/TESTING.md`).
- Resolve `docs/RESEARCH.md` §7 hardware-verification items.

## [0.1.0-alpha] — 2026-07-23
### Added
- Initial public **alpha**.
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

[Unreleased]: https://github.com/BGriffin63/unraid-vm-sentinel/compare/v0.1.0-alpha...HEAD
[0.1.0-alpha]: https://github.com/BGriffin63/unraid-vm-sentinel/releases/tag/v0.1.0-alpha
