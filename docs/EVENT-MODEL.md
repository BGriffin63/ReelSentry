# VM Sentinel — Event Model (spec §5, §7)

VM Sentinel normalizes raw libvirt hook actions into a stable internal event
vocabulary, then classifies intent. The mapping is the single source of truth in
[`../src/lib/normalize.sh`](../src/lib/normalize.sh) and
[`../src/lib/classify.sh`](../src/lib/classify.sh), covered by
[`../tests/unit/test_normalize_classify.sh`](../tests/unit/test_normalize_classify.sh).

## Raw → normalized

libvirt invokes the hook as `<vm-name> <operation> <sub-operation> <extra>`.

| libvirt operation | sub | Normalized event | Recorded state |
|-------------------|-----|------------------|----------------|
| `prepare` / `start` | begin | `starting` | starting |
| `started` | begin | `started` | running |
| `stopped` | begin | `stopping` | stopping |
| `stopped` | end | `stopped` | stopped |
| `shutdown` | * | `shutdown` | stopped |
| `reboot` | * | `rebooted` | running |
| `suspend`/`pmsuspend` | * | `suspended` | paused |
| `resume`/`restore`/`pmwakeup` | * | `resumed` | running |
| `pause` | * | `paused` | paused |
| `unpause` | * | `resumed` | running |
| `crashed`/`panicked` | * | `crashed` | stopped |
| `release` | end | `released` | stopped |
| `migrate` | * | `migrated` | migrated |
| `define` / `undefine` | * | `defined` / `undefined` | defined / stopped |
| `reconnect` | * | *(ignored on hot path)* | — |
| anything else | * | `unknown` | unknown |

> Raw action names are **not** assumed identical across every transition — the
> normalization layer exists precisely so the rest of the system depends on the
> stable vocabulary, not on libvirt's wording.

## Classification (intent)

Three honest values: `expected`, `unexpected`, `indeterminate`.

| Situation | Classification | User-facing wording |
|-----------|----------------|---------------------|
| Graceful `shutdown` | expected | "VM shut down normally." |
| libvirt `crashed`/`panicked` | unexpected | "VM crashed." |
| Bare `stopped end`, no context | indeterminate | "VM stopped; the reason could not be determined." |
| Any stop during a detected maintenance window | expected | "Monitoring was interrupted during an Unraid or VM Manager restart." |
| `started`/`resumed`/`paused`/`rebooted`/… | expected (informational) | plain description |

**Maintenance context** is a best-effort marker set when the array is stopping or
VM Manager is shutting down (if a reliable signal exists on the host). When
present, mass VM stops are labeled maintenance rather than crashes. When no
reliable signal exists, VM Sentinel does **not** guess — it uses
`indeterminate`.

## Severity

| Event / class | Severity |
|---------------|----------|
| `crashed`, unexpected stop, prolonged health failure | `critical` |
| indeterminate stop, health degradation | `warning` |
| `started`, `resumed`, recovery, informational | `info` |

Severity drives Unraid importance (`normal`/`warning`/`alert`) and the Discord
embed color **plus** an explicit text Status field (never color alone).

## Normalized notification object

Providers receive this shape (also the history record schema):

```json
{
  "event_id": "e_<epoch_ns>_<rand>",
  "server": "TOWER",
  "vm_uuid": "…",
  "vm_name": "Game PC",
  "event_type": "crashed",
  "severity": "critical",
  "classification": "unexpected",
  "timestamp": "2026-07-23T20:42:13-05:00",
  "previous_state": "running",
  "current_state": "stopped",
  "health_state": "suspended",
  "summary": "Game PC crashed",
  "details": "Libvirt reported a crash lifecycle event."
}
```
