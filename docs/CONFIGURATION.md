# VM Sentinel — Configuration Reference (spec §8, §15)

Configuration is edited in the WebGUI (**Settings → VM Sentinel**). This document
describes what is stored, where, and every setting.

## Files

| File | Perms | Purpose |
|------|-------|---------|
| `/boot/config/plugins/vm.sentinel/config.json` | 0644 | Canonical, human-readable settings. Atomic writes; `.bak` kept. |
| `/boot/config/plugins/vm.sentinel/config.snapshot` | 0644 | Flat, tab-delimited cache the bash services read (regenerated from `config.json`). |
| `/boot/config/plugins/vm.sentinel/secrets.json` | 0600 | Discord webhook only. Never logged/exported. |

Bash services never parse `config.json` (no `jq` dependency); the WebGUI writes
both files atomically so they never diverge.

## Global settings

| Key | Default | Meaning |
|-----|---------|---------|
| `monitoring_enabled` | `0` | Master switch. Off = no notifications at all. |
| `native_enabled` | `1` | Send via Unraid's notification system. |
| `discord_enabled` | `0` | Send via Discord webhook. |
| `discord_username` / `discord_avatar` | — | Display overrides for Discord. |
| `discord_mention_role` / `discord_mention_user` | — | Numeric IDs to mention. |
| `history_max_events` | `5000` | Hard cap on stored events. |
| `history_retention_days` | `30` | Age cap on stored events. |
| `cooldown_seconds` | `0` | Global per-event cooldown. |
| `quiet_enabled` | `0` | Enable quiet hours. |
| `quiet_start` / `quiet_end` | `22:00`/`07:00` | Quiet window (server local time). |
| `quiet_days` | `0..6` | Days (0=Sun) the window applies. |
| `quiet_bypass_critical` | `1` | Critical alerts ignore quiet hours. |
| `notify_start` | `0` | Global default: notify on start. |
| `notify_stop` | `1` | Global default: notify on stop. |
| `notify_shutdown` | `1` | Global default: notify on shutdown. |
| `notify_crash` | `1` | Global default: notify on crash/failure. |
| `notify_pause`/`notify_resume`/`notify_reboot` | `0` | Global defaults. |
| `notify_health_fail`/`notify_health_recover` | `1` | Global defaults. |
| `debug` | `0` | Debug logging (off by default). |

## Per-VM settings (keyed by UUID)

Any global default can be overridden per VM. Additional per-VM keys:

| Key | Default | Meaning |
|-----|---------|---------|
| `enabled` | `1` | Monitor this VM (requires `monitoring_enabled`). |
| `name` | — | Last-seen display name (auto-updated; config keyed by UUID). |
| `health_type` | `none` | `none` / `icmp` / `tcp` / `agent`. |
| `health_target` | — | Host/IP for ICMP/TCP. |
| `health_port` | — | TCP port for `tcp`. |
| `health_interval` | `60` | Seconds between checks (clamped to ≥30). |
| `health_timeout` | `5` | Per-probe timeout seconds. |
| `health_fail_threshold` | `3` | Consecutive fails → Unhealthy. |
| `health_recover_threshold` | `2` | Consecutive successes → Recovered. |
| `startup_grace` | `120` | Seconds after start before failure alerts. |
| `cooldown_seconds` | inherit | Per-VM cooldown override. |

### Rename & delete behavior
- **Rename:** settings persist because they're keyed by UUID; the display name
  updates automatically.
- **Delete:** the VM is shown as *unavailable* and its history/config is retained
  until you click **Forget** on the VMs tab.

## Health-state machine

`Unknown → PendingFailure → Unhealthy → PendingRecovery → Recovered → Healthy`.
Only confirmed `Unhealthy` and `Recovered` transitions notify. Checks are
suspended while libvirt reports the VM stopped, and skipped during the startup
grace period. See [`ARCHITECTURE.md`](ARCHITECTURE.md) §6.

## Storage locations (runtime & history)

- Runtime (spool, locks, health state, PID): `/var/run/vm.sentinel/` (tmpfs).
- History: `/mnt/user/appdata/vm.sentinel/history/history.jsonl`, falling back to
  `/var/log/vm.sentinel/history/` if appdata is unavailable. Rotated by count +
  age. Never written to `/boot`.
