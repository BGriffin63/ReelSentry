# VM Sentinel — Testing (spec §27)

## Automated tests (run anywhere)

```bash
scripts/test.sh          # unit + security + integration (bash)
scripts/lint.sh          # ShellCheck + php -l + xmllint (if installed)
scripts/build.sh && scripts/package.sh && scripts/validate.sh
```

The automated suite runs **entirely off Unraid** using fixtures and mocks:

- **Unit** — normalization, classification, severity, UUID/port/host/URL
  validation, VM-name sanitization, JSON escaping, secret redaction, config
  snapshot parsing, atomic writes, dedup, cooldown, quiet hours, suppression,
  history retention.
- **Security** — hostile VM names (`$()`, backticks, `;`, `|`, `&&`, quotes,
  HTML/JS, path traversal, newlines, huge names) driven through the **real** hook
  + processor; asserts no command execution, valid JSON, no traversal; Discord
  payload safety with hostile input; webhook validation + redaction.
- **Integration** — hook → spool → processor → history → notification dispatch
  (mocked native notifier), fast-return hook, missing/extra args, corrupt-record
  quarantine, notifier-failure fail-open, single-flight locking.

CI runs the same on every push (see `.github/workflows/`).

## Manual Unraid test matrix (required before "submission ready")

These require a real Unraid **7.2+** system and are **not** yet completed. Track
results here. Until every row passes, the release verdict stays at most
**Beta ready**.

| # | Scenario | Expected | Result |
|---|----------|----------|--------|
| 1 | Clean 7.2 install via `.plg` | Installs, appears under Settings, service running | ☐ |
| 2 | Existing production-like server | Installs without disturbing other plugins/hooks | ☐ |
| 3 | Existing unrelated `qemu.d/` hook present | Both hooks run; ours is `50-vm-sentinel` | ☐ |
| 4 | VM Manager disabled | GUI shows warning, no crash | ☐ |
| 5 | Windows VM lifecycle (start/stop/shutdown/crash) | Correct events + classification | ☐ |
| 6 | Linux VM lifecycle | Correct events | ☐ |
| 7 | Multiple simultaneous VM changes | All captured, ordered, deduped | ☐ |
| 8 | VM rename | Config retained by UUID, name updates | ☐ |
| 9 | VM delete | Marked unavailable; Forget works | ☐ |
| 10 | Server reboot | Config persists; service restarts; maintenance context | ☐ |
| 11 | Array start/stop | Services idle/resume cleanly | ☐ |
| 12 | libvirt restart | Hook still present (self-heal), no VM impact | ☐ |
| 13 | Discord offline / internet offline | Bounded timeout, failure recorded, queue continues | ☐ |
| 14 | Email/native agents configured | Alerts delivered via Unraid | ☐ |
| 15 | Health check: ICMP/TCP fail then recover | Unhealthy after threshold, Recovered after threshold, no spam | ☐ |
| 16 | Startup grace | No false unhealthy during boot | ☐ |
| 17 | Quiet hours + critical bypass | Suppressed except critical | ☐ |
| 18 | Upgrade from previous VM Sentinel | Settings preserved, migration runs | ☐ |
| 19 | Reinstall | Idempotent, no duplicate hook | ☐ |
| 20 | Uninstall with running VMs | Only our hook removed; VMs unaffected; config kept | ☐ |
| 21 | Diagnostics bundle | Downloads; contains **no** secrets | ☐ |
| 22 | Test buttons (native/discord) | Both deliver | ☐ |
| 23 | Flash read-only simulation | Clear error on save; runtime unaffected | ☐ |

## Verification items needing hardware

See [`RESEARCH.md`](RESEARCH.md) §7 — `qemu.d/` execution, `notify` flags, `.page`
nesting, guest-agent path, appdata presence.
