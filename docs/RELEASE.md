# VM Sentinel — Release Process (spec §29)

Semantic versioning. Progression: `0.1.0-alpha` → `0.2.0-beta` → `0.9.0-rc1` →
`1.0.0`.

## Version sources
- `VERSION` — semver source of truth (e.g. `0.1.0-alpha`).
- `.plg` `<!ENTITY version>` — filled by `scripts/release.sh`.
- Slackware package version replaces `-` with `_` (e.g. `0.1.0_alpha`) because
  Slackware versions cannot contain `-`.

> **Note on Unraid update comparison:** Unraid compares plugin versions to detect
> updates. If pre-release semver causes comparison issues in practice, switch the
> `.plg` version to date-based (`YYYY.MM.DD`) for the public channel and keep
> semver on GitHub release tags. Decide before the first CA submission and record
> the choice here.

## Build the release

```bash
scripts/release.sh
```

This runs `generate-icons.py`, `build.sh`, `package.sh`, then stamps a copy of the
`.plg` in `build/` with the version and the real package **SHA256**. Artifacts:

- `build/vm.sentinel-<pkgver>-x86_64-1.txz`
- `build/vm.sentinel-<pkgver>-x86_64-1.txz.sha256`
- `build/vm.sentinel.plg` (stamped)

## Publish (manual, human-confirmed)

1. Tag: `git tag v<version> && git push --tags`.
2. Create a GitHub **Release** `v<version>`; upload the `.txz` **and** `.sha256`.
3. Commit the stamped `vm.sentinel.plg` to `main` (its `packageURL` points at the
   immutable release asset; the `<SHA256>` matches).
4. Verify: install the `.plg` on a test Unraid box; confirm checksum validation
   passes and the plugin installs.

Never use floating "latest" URLs that would bypass checksum validation — the
`.plg` references versioned, immutable assets with a pinned hash.

## Release notes template

```
## v<version> — <date>
### Added / Changed / Fixed
- …
### Upgrade notes
- Settings are preserved; config schema migrations run automatically.
### Known issues
- …
### Rollback
- Reinstall the previous `.plg` release; config is backward-compatible within a
  major version. `.bak` config copies are kept automatically.
```

## Post-release
- Update `CHANGELOG.md`.
- Watch the support thread / issues.
- For CA, follow [`COMMUNITY-APPS-SUBMISSION.md`](COMMUNITY-APPS-SUBMISSION.md).
