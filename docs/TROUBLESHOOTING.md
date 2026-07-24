# ReelSentry — Troubleshooting (spec §30)

Start at **Settings → ReelSentry → Diagnostics**, then match your symptom below.
Errors are written in plain language, e.g. *"Discord delivery failed: the webhook
returned HTTP 404. The webhook may have been deleted."*

## No notifications received
1. Is **Enable monitoring** on (Notifications tab)?
2. Is the VM's monitoring toggle on and the specific event enabled (VMs tab)?
3. For native: are agents configured under **Settings → Notifications**? Click
   **Send test notification**.
4. Check **quiet hours** / **maintenance suppression** aren't active.
5. Diagnostics → is the **processor** running? Is **hook status** `installed`?

## Duplicate notifications
- Rapid state cycles are deduped within a short window; if you still see dupes,
  raise the per-VM/global **cooldown**. Report a bug with the Event History rows.

## A VM is missing from settings
- ReelSentry lists VMs from libvirt. Ensure **VM Manager** is enabled and the
  **array is started**. Newly created VMs appear after the next inventory refresh.

## Discord test fails
- **HTTP 404** → webhook deleted; recreate it (see DISCORD-SETUP.md).
- **HTTP 401/403** → wrong/incomplete URL.
- **"does not look like a Discord webhook URL"** → must be
  `https://discord.com/api/webhooks/<id>/<token>`.
- **HTTP 429** → rate-limited; ReelSentry backs off automatically.

## Email not received
- ReelSentry doesn't send email directly — Unraid does. Verify **Settings →
  Notifications → email**, and that Unraid itself can send you a test.

## Health check always fails
- Confirm target IP/host and port from another machine.
- Increase **timeout** and **startup grace**.
- For the guest-agent check, the QEMU guest agent must be installed/running in
  the guest.

## Plugin reports hook missing
- Diagnostics → **hook status** `missing`/`foreign`. Restart the service:
  ```bash
  bash /usr/local/emhttp/plugins/reelsentry/services/reelsentry-service restart
  ```
  It reinstalls `qemu.d/50-reelsentry` idempotently. If status is `foreign`, a
  non-VM-Sentinel file occupies that name — investigate before overwriting.

## Stopped working after an Unraid update
- The service self-heals the hook on start. Reboot or restart the service. If the
  update changed the libvirt hook mechanism, check for a plugin update and see
  RESEARCH.md §3.

## Collect diagnostics
- Diagnostics → **Download diagnostics (sanitized)**. Safe to attach to a bug
  report — the Discord webhook and any secrets are redacted.

## Uninstall safely
- **Plugins → ReelSentry → Remove.** Only ReelSentry's own hook and runtime are
  removed; running VMs are untouched; your config/history under
  `/boot/config/plugins/reelsentry/` is kept. To fully remove:
  ```bash
  rm -rf /boot/config/plugins/reelsentry
  ```
