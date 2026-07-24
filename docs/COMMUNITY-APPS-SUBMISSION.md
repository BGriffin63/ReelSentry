# VM Sentinel — Community Applications Submission (spec §22)

> Field names and the submission flow evolve. **[VERIFY]** each step against the
> current Community Applications (CA) documentation and the CA appfeed schema
> before submitting. `templates/vm-sentinel.xml` and `templates/ca_profile.xml`
> use the current public reference and must pass CA validation/scanning.

## 1. Repository prerequisites
- Public GitHub repo `unraid-vm-sentinel`, OSI license (MIT ✔), README ✔,
  screenshots in `docs/screenshots/`.
- A published GitHub **Release** with the `.txz` + `.sha256`, and a `vm.sentinel.plg`
  on `main` whose `packageURL`/`<SHA256>` point at that release (see RELEASE.md).
- All `YOUR_*` placeholders replaced (see [`MAINTAINER-CHECKLIST.md`](MAINTAINER-CHECKLIST.md)).

## 2. Validation steps
- `scripts/lint.sh` (xmllint on `.plg` + templates), `scripts/test.sh`,
  `scripts/build.sh && scripts/package.sh && scripts/validate.sh` all green.
- The `validate-community-apps` GitHub workflow passes.
- Confirm the `.plg` installs on a real Unraid 7.2 box and checksum validation
  succeeds.

## 3. Live scan steps
- CA runs an automated scan (dockerHub/URL reachability, template shape, icon
  reachability). Ensure the icon URL (`assets/vm-sentinel-128.png` raw link) and
  `PluginURL` resolve publicly.

## 4. Duplicate check
- Search CA for existing "VM"/"Sentinel"/VM-monitoring plugins to confirm the
  name and scope don't collide with an existing app.

## 5. Listing preview review
- Verify Name, Overview, Category (`Tools: Utilities`), Icon, Screenshot,
  MinVer (`7.2.0`), Beta flag, Author, Support/Project URLs render correctly in
  the CA preview.

## 6. Manual testing requirements
- Complete the manual matrix in [`TESTING.md`](TESTING.md) on real hardware. CA
  moderators expect a working, non-misrepresented plugin.

## 7. Release creation
- Follow [`RELEASE.md`](RELEASE.md); tag + GitHub Release + stamped `.plg`.

## 8. Submission process
- Open the CA submission request per current CA docs (typically a forum post in
  the CA support thread and/or a PR to the CA appfeed with your plugin template),
  linking the repo, `.plg`, support thread, and screenshots.

## 9. Moderator-response workflow
- Respond promptly to moderator feedback; make requested changes; keep the
  support thread updated. Re-run validation after each change.

## 10. Post-approval maintenance obligations
- Keep the `.plg`/release assets and checksums valid.
- Respond to issues/support; publish security fixes promptly (see SECURITY.md).
- Keep the CA template accurate as features change; bump versions via RELEASE.md.
- Maintain the beta/stable status honestly in the listing.
