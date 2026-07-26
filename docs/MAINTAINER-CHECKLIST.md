# ReelSentry — Maintainer Checklist

Everything that must be replaced or verified before a public release / CA
submission. Search the repo for each placeholder token and replace it.

## Placeholder replacements

| Placeholder | Meaning | Files |
|-------------|---------|-------|
| `YOUR_GITHUB_USERNAME` | Your GitHub user/org | `reelsentry.plg`, `ca_profile.xml`, `reelsentry.xml`, `README.md`, docs |
| `YOUR_DISPLAY_NAME` | Your public maintainer name | `LICENSE`, `reelsentry.plg`, `ca_profile.xml`, `reelsentry.xml` |
| `YOUR_SUPPORT_THREAD_URL` | Unraid forum support thread | `reelsentry.plg`, `ca_profile.xml`, `reelsentry.xml`, `README.md`, `docs/SUPPORT.md` |
| `YOUR_PROJECT_URL` | Project home (repo or site) | `ca_profile.xml`, `reelsentry.xml` |

Quick find:
```bash
grep -RIl 'YOUR_GITHUB_USERNAME\|YOUR_DISPLAY_NAME\|YOUR_SUPPORT_THREAD_URL\|YOUR_PROJECT_URL' .
```

## Before first release
- [ ] Replace all placeholders above.
- [ ] Add real screenshots to `docs/screenshots/` (Overview, VMs, Notifications,
      History, Diagnostics, Discord).
- [ ] Fill the security contact in `.github/SECURITY.md`.
- [ ] Complete the manual test matrix in `docs/TESTING.md` on Unraid 7.2.
- [ ] Resolve every **[VERIFY]** item in `docs/RESEARCH.md` §7.
- [ ] `scripts/lint.sh`, `scripts/test.sh`, `scripts/validate.sh` all green.
- [ ] `scripts/release.sh`; publish GitHub Release with `.txz` + `.sha256`.
- [ ] Commit the stamped `reelsentry.plg`; confirm install on real hardware.

## Before CA submission
- [ ] Follow `docs/COMMUNITY-APPS-SUBMISSION.md`.
- [ ] Confirm icon + PluginURL resolve publicly.
- [ ] Duplicate-name check on CA.
- [ ] `validate-community-apps` workflow passes.

## Ongoing
- [ ] Keep checksums/release assets valid.
- [ ] Triage issues; ship security fixes fast.
- [ ] Keep beta/stable status honest.
