# VM Sentinel — Security & Threat Model (spec §18)

VM Sentinel runs as host-level software on Unraid. This document is the security
review required before release. It states the trust boundaries, the threats
considered, and the concrete mitigation in code.

## Trust model

- **Trusted:** the Unraid host, the authenticated WebGUI user, Unraid's `notify`
  CLI, libvirt/`virsh`.
- **Untrusted (treated as hostile input):** VM names, libvirt hook argv,
  hostnames/IPs/ports entered for health checks, the Discord webhook URL, any
  value read from disk that could have been influenced by the above.

Instructions never come from data. Nothing read from a VM name, file, or network
response is executed or interpreted as a command.

## Core mitigations

| # | Requirement | Implementation |
|---|-------------|----------------|
| 1 | No `eval` | Verified by `scripts/validate.sh`; none in `src/`. |
| 2 | No shell built from untrusted strings | Hook writes untrusted name as a **base64 spool field**, never a token. `virsh`/`ping` receive values as single argv elements. PHP uses `escapeshellarg`. |
| 3 | Quote all variables | Shell is written with quoted expansions; ShellCheck in CI. |
| 4 | Validate UUIDs/ports/hosts/URLs/paths | `src/lib/validate.sh` + PHP mirrors; unit + security tests. |
| 5 | VM names untrusted | `sanitize_vm_name` bounds length + strips control chars; JSON/HTML escaped at output. |
| 6 | HTML escaping | PHP `htmlspecialchars(…, ENT_QUOTES)` via `h()`. |
| 7 | JSON escaping | `src/lib/json.sh` hand-rolled escaper (quotes, backslash, control chars, `/`). |
| 8 | Secure temp files | `mktemp`/`mktemp -d`, `chmod 700`, random tokens; atomic temp+rename. |
| 9 | No predictable temp names | `vms_rand_token` uses `/dev/urandom`. |
| 10 | Secret file perms | `secrets.json` `0600`; runtime dirs `0700`. |
| 11 | No world-writable files | Enforced by `scripts/validate.sh`. |
| 12–14 | No listener / API / inbound ports | The plugin never binds a socket. |
| 15 | HTTPS for Discord | `valid_discord_webhook` requires `https://` + approved host. |
| 16 | CSRF | `vms_csrf_check()` validates Unraid's token on every state-changing POST. |
| 17 | No secrets in argv | Webhook passed to `curl` as the URL only; never echoed into other commands. |
| 18 | No auth headers logged | `redact_stream` strips `Authorization`/`Bearer`. |
| 19 | No runtime code download/exec | Nothing is fetched and executed; updates go through Unraid's plugin system. |
| 20 | No separate auto-updater | Uses the `.plg`/Unraid update flow. |
| 23–26 | No telemetry/analytics/ads | None present. |
| 29 | Conservative until configured | `monitoring_enabled` defaults **off**. |

## Threat analysis

### Malicious VM name / malformed hook args
The name is captured, length-bounded, control-char-stripped, base64-encoded into
the spool, and only ever emitted through JSON/HTML escapers. Security test
`tests/security/test_injection.sh` drives the real hook + processor with names
containing `$()`, backticks, `;`, `|`, `&&`, quotes, HTML/JS, path-traversal,
newlines, and a 400-char name, and asserts **no command executes**, **every
history line is valid JSON**, and no file traversal occurs.

### Discord webhook theft / exposure
Stored in a separate `0600` file, never in `config.json`, never rendered to HTML
(only a redacted form), never logged, never in exports/diagnostics. Redaction
(`redact_discord_webhook`, `redact_stream`) reveals at most the id + 3 token
chars. The setup doc instructs users to regenerate a leaked webhook.

### CSRF / stored XSS
All POSTs require Unraid's CSRF token. History values are HTML-escaped on render;
the export is a download, not inline HTML. JSON is built with a correct escaper
so a VM named `</script>` cannot break out (the `/` is escaped).

### Command injection / path traversal / symlink
No untrusted string reaches a shell. `valid_path_component` rejects `..`/`/`.
Writes use fixed directories + atomic temp+rename; history/config paths are not
user-supplied filenames. Runtime dirs are `0700` under `/var/run`.

### Queue flooding / log flooding / retry storms
Spool is bounded (`VMS_QUEUE_MAX`); oldest non-critical events dropped and
counted. Logs rotate at a byte cap. Discord retries are bounded with backoff and
honor HTTP 429; a dead endpoint cannot wedge the queue (hard `curl` timeouts).

### Race conditions / concurrent saves
A dependency-free `mkdir`-based lock (with stale-holder reclaim) guards the
processor (single-flight), per-VM health checks, config writes, and history
appends. Concurrent GUI saves serialize; last valid write wins atomically.

### Corrupt configuration / corrupt queue event
Config load falls back to `.bak` then built-in defaults. A malformed spool record
is quarantined to `spool/bad/` and counted, never retried forever.

### Partial install / uninstall, Unraid upgrades, libvirt restarts
Install and hook install are idempotent; the service self-heals the hook on
start. Uninstall removes only VM-Sentinel-owned files and succeeds even if some
are already gone. The plugin never restarts libvirt or touches VM XML.

### SSRF (future generic webhooks)
Not applicable to v1 (Discord host allow-list only). Documented as a design
constraint for any future generic-webhook provider: enforce an allow-list / block
link-local & private ranges before shipping it.

## Reporting a vulnerability

Please do **not** open a public issue for security problems. See
[`../.github/SECURITY.md`](../.github/SECURITY.md) for private reporting.
