# ReelSentry — Research Notes (Phase 1)

> **Status:** Living document. Every claim tagged **[VERIFY]** must be confirmed on a
> real Unraid 7.2+ system before the plugin is declared "Community Applications
> submission ready." See [`TESTING.md`](TESTING.md) for the manual matrix.

This document records what was investigated before implementation, the sources
consulted, and the reasoning that shaped [`ARCHITECTURE.md`](ARCHITECTURE.md).
It deliberately avoids copying stale forum snippets; where official docs are
incomplete, the approach is derived from how currently-maintained plugins solve
the same problem and flagged for hardware verification.

---

## 1. Target platform baseline

| Item | Finding | Source class |
|------|---------|--------------|
| Minimum Unraid | **7.2.0** | Chosen for a modern libvirt (see §3) and current WebGUI notification tooling. |
| Architecture | x86-64 only | Unraid VM Manager (KVM/QEMU) is x86-64. |
| VM stack | libvirt + QEMU/KVM, managed by Unraid "VM Manager" | Official Unraid VM Manager docs. |
| Package format | Slackware `.txz` referenced by a `.plg` XML manifest | Unraid plugin convention. |
| WebGUI | emhttp / PHP pages under `/usr/local/emhttp/plugins/<id>/` with `.page` headers | Unraid plugin convention. |
| Shell | `bash` present; `curl` present; **`jq` NOT guaranteed** | Slackware base + Unraid. ReelSentry therefore does **not** depend on `jq`. |
| SQLite | `sqlite3` availability is **not guaranteed** across all installs | We use JSON Lines instead of SQLite to avoid a bundled dependency (spec §15). |

**Why Unraid 7.2 minimum:** earlier releases shipped older libvirt builds whose
hook-directory dispatch (`qemu.d/`) behavior and notification CLI flags differ.
Pinning to 7.2 lets us target one well-defined libvirt/notification surface
instead of branching on many. This is documented as a hard `<MinVer>` in the
`.plg`. **[VERIFY]** the exact libvirt version shipped in 7.2.

---

## 2. Notification system

Unraid ships a notification agent driven by a CLI, conventionally:

```
/usr/local/emhttp/webGui/scripts/notify \
  -e "<event/source>" -s "<subject>" -d "<description>" \
  -i "normal|warning|alert" [-m "<longer message>"] [-l "<link>"] [-x]
```

- Importance levels map to Unraid's `normal` / `warning` / `alert`. **[VERIFY]**
  exact accepted tokens on 7.2.
- Delivery fan-out (email, Discord/Telegram/Pushover agents, browser toast) is
  handled by Unraid itself based on the user's **Settings → Notifications**
  configuration. ReelSentry does **not** implement SMTP (spec §35).
- The `notify` script is the primary provider. ReelSentry shells out to it with
  fully-quoted, validated arguments and never interpolates untrusted VM names
  into a shell string (see `src/notifications/native.sh`).

**Reasoning:** using the native `notify` CLI means every downstream agent the
user already trusts works for free, and we inherit Unraid's own delivery
handling instead of re-implementing it.

---

## 3. libvirt / QEMU hook mechanism (the critical decision)

### The problem
Unraid historically ships a single shared hook file at
`/etc/libvirt/hooks/qemu`. Multiple plugins wanting VM lifecycle events have, in
the past, **overwritten** this file — clobbering each other. Community
Applications moderators explicitly scrutinize this. ReelSentry must **never**
own or replace the shared file.

### libvirt hook-directory dispatch
Modern libvirt (5.x+) supports a **hook directory**: alongside
`/etc/libvirt/hooks/qemu`, libvirt will also execute every executable in
`/etc/libvirt/hooks/qemu.d/` for the same event, passing the **same argv**:

```
<hook-script> <vm-name> <operation> <sub-operation> <extra>
# e.g.  qemu  Game-PC  stopped  end  -
```

Operations relevant to lifecycle: `prepare`, `start`, `started`, `stopped`,
`release`, plus `restore`/`migrate` variants. Sub-operations: `begin` / `end`.

**Chosen design:** ReelSentry installs exactly one namespaced, executable file:

```
/etc/libvirt/hooks/qemu.d/50-reelsentry
```

- It coexists with any other `qemu.d/*` consumer and with the shared `qemu`
  file. We never read, move, back up, or delete the shared file.
- The numeric prefix (`50-`) gives deterministic ordering without assuming we
  are the only consumer.
- **[VERIFY]** on real 7.2 hardware that (a) `qemu.d/` is honored by the shipped
  libvirt, and (b) the shipped `qemu` dispatcher does not *disable* `.d`
  execution. If `qemu.d/` is **not** honored, the documented fallback (§3.1)
  applies. This is the single highest-risk unverified assumption in the project
  and is called out in the final report and `ARCHITECTURE.md`.

### 3.1 Fallback if `qemu.d/` is unavailable
If and only if hardware testing shows `qemu.d/` is not executed, the fallback is
a **cooperative, append-only shim**: detect an existing `qemu` file, and if it is
not already VM-Sentinel-aware, install our own `qemu` that (1) invokes the
previous file if one existed (preserved as `qemu.orig.vmsentinel` — the *only*
backup we ever make) and (2) invokes every `qemu.d/*` script. This shim is
idempotent and removable. It is **disabled by default** and only the `qemu.d/`
path ships enabled, because the shim carries higher coexistence risk. See
`src/hooks/install-hook.sh`.

### Why the hook does no work
The hook is on the VM's critical path. It therefore:
- validates argv, normalizes the event, writes **one** small spool file to
  tmpfs, and returns `0` in single-digit milliseconds;
- performs **no** network, DNS, notification, or config-parsing work;
- can never fail a VM operation — every code path `exit 0`.

Delivery is done by a **separate processor** (`src/services/processor.sh`)
triggered after the hook returns. See `ARCHITECTURE.md §Queue`.

---

## 4. Plugins inspected for convention (coexistence & patterns)

Rather than copy any code, three classes of currently-maintained plugins were
studied for *convention*:

1. **A libvirt-hook-consuming plugin** (VM autostart/notification style) — for
   how to place files under `qemu.d/` and avoid the shared file. Confirmed the
   namespaced-file pattern is the accepted approach.
2. **A settings-page plugin** (e.g. a "Tips and Tweaks"-style plugin) — for the
   `.page` header format, `Menu=`, `Type=`, `Title=`, `Icon=` fields, and how
   `emhttp` renders PHP pages and posts settings back.
3. **A background-service plugin** (e.g. a monitoring/stats plugin) — for how a
   long-lived helper is started/stopped via the `.plg` `<FILE Run>` and an
   `rc.d`-style script, and how PID/lock files live in tmpfs.

No source was copied. Findings shaped the file layout and the `.page`/`.plg`
formats. Any convention that could not be confirmed from official docs is tagged
**[VERIFY]** in `ARCHITECTURE.md` and re-checked on hardware.

---

## 5. Storage & flash-wear

- **Config** (small, must survive reboot): `/boot/config/plugins/reelsentry/`.
  Written atomically (temp file + `mv`), previous version kept as `.bak`. This is
  Unraid convention and the writes are rare (only on Save).
- **Event history** (high churn): JSON Lines in **appdata** by default
  (`/mnt/user/appdata/reelsentry/history/`) with detection + fallback to
  `/var/log/reelsentry/` (tmpfs) if appdata is absent (cache pool not
  guaranteed, spec §15). **Never** on `/boot`.
- **Runtime** (spool, locks, PID, health state): tmpfs at `/var/run/reelsentry/`.
  Lost on reboot by design; nothing persistent lives there.

**Reasoning:** this cleanly separates "small + persistent + flash" from
"high-churn + RAM/appdata," satisfying the non-negotiable "do not write
high-frequency event data to the boot flash" constraint.

---

## 6. Licensing implications

- Plugin is MIT (spec §23). No third-party code copied; `THIRD_PARTY_NOTICES.md`
  records the (currently empty) set of bundled third-party works.
- Relies only on tools already present on Unraid (`bash`, `curl`, coreutils,
  `libvirt`/`virsh`, the `notify` CLI). Nothing is downloaded or bundled.
- Logo and all assets are original (see `BRANDING.md`).

---

## 7. Open verification items (carried to the final report)

1. `qemu.d/` execution on real 7.2 (§3). **Highest risk.**
2. Exact `notify` CLI flags/importance tokens on 7.2 (§2).
3. `.page` header field set honored by 7.2 emhttp (§4).
4. QEMU guest-agent query path (`virsh qemu-agent-command` / `domstate`) and
   whether it is safe/permitted for an optional health check (spec §9.3).
5. Presence of `sqlite3` (we assume **absent** and avoid it).
6. Presence of appdata / cache pool (we detect and fall back).

These are the items that "could not be verified without a real Unraid server."
