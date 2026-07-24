# VM Sentinel — Discord Webhook Setup (spec §25)

VM Sentinel sends Discord alerts through an **incoming webhook**. There is **no
Discord bot**, no token to manage, and no gateway connection — a webhook can only
*post* to the one channel you attach it to.

## Steps

1. Open the Discord **server** where you want alerts.
2. Choose (or create) the **channel** for VM Sentinel alerts.
3. Open **Channel Settings** (the gear icon next to the channel).
4. Go to **Integrations**.
5. Click **Create Webhook** (or **New Webhook**).
6. Name it **VM Sentinel** (optionally set an avatar).
7. Click **Copy Webhook URL**.
8. In Unraid: **Settings → VM Sentinel → Notifications → Discord webhook URL**,
   paste the URL.
9. Click **Save webhook**.
10. Click **Send test** and confirm the message appears in your channel.

Then tick **Enable Discord webhook alerts** and **Save settings**.

> Screenshots: see `docs/screenshots/discord-*.png` (placeholders). This guide
> intentionally avoids reproducing Discord's copyrighted UI artwork.

## What the alerts look like

Rich embeds (default) with:
- A colored bar **and** an emoji/text status (🟢 info, 🟠 warning, 🔴 critical) —
  never color alone.
- Fields: VM, Event, Server, Previous state, Current state, Classification, Health.
- Footer: `VM Sentinel • Monitor every VM`.
- Optional role/user mention (configured with numeric IDs).

Example title: `🔴 VM Alert: Game PC crashed`

## Security — treat the URL like a password

- **Anyone** who has the webhook URL can post to that channel. Keep it private.
- VM Sentinel stores it in `/boot/config/plugins/vm.sentinel/secrets.json` with
  `0600` permissions.
- It is **never** shown in full again — only a redacted form
  (`…/api/webhooks/123…/REDACTED`).
- It is **never** written to logs, exports, or the diagnostics bundle.
- If it is ever exposed, **delete/regenerate it in Discord** (Channel → Integrations
  → the webhook → Delete/regenerate) and paste the new one into VM Sentinel.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Test says HTTP 404 | Webhook was deleted in Discord — recreate it. |
| Test says HTTP 401/403 | URL is wrong/incomplete — copy it again. |
| "does not look like a Discord webhook URL" | Must be `https://discord.com/api/webhooks/<id>/<token>`. |
| HTTP 429 | You're being rate-limited; VM Sentinel backs off automatically. |
| Nothing arrives, no error | Check **Enable Discord webhook alerts** is on and the VM's event toggle is enabled. |
