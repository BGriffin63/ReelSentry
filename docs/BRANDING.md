# VM Sentinel — Branding Guidelines (spec §4)

## The mark

VM Sentinel's logo is an original, hand-authored/programmatic mark:

- **Shield** — monitoring & protection.
- **VM window** (rectangle with a title bar + two dots) — virtualization.
- **Pulse / heartbeat line** — active monitoring.
- **Status dot** (green, white ring) — "actively watching."

Construction is clean and geometric; it stays legible at 48×48 and works as a
monochrome icon. No copyrighted logos, no Unraid trademark, no gradients
required.

## Files

| File | Use |
|------|-----|
| `assets/vm-sentinel.svg` | Full-color master (viewBox 0 0 128 128). |
| `assets/vm-sentinel-monochrome.svg` | Single-color (`currentColor`) for menus/dark & light UIs. |
| `assets/vm-sentinel-512.png` / `-256` / `-128` | Raster sizes (CA icon uses 128). |
| `assets/vm-sentinel-48.png` / `-32.png` | Small UI / favicon sizes. |
| `assets/vm-sentinel.png` | 48px copy used as the WebGUI plugin icon. |

The PNGs are **generated** from geometry by
[`../scripts/generate-icons.py`](../scripts/generate-icons.py) using only the
Python standard library — no external assets, fonts, tracking data, or metadata.
Regenerate with:

```bash
python3 scripts/generate-icons.py
```

## Colors

| Token | Hex | Use |
|-------|-----|-----|
| Shield blue | `#1f6feb` | Primary shield fill |
| Deep navy | `#0b2a5b` | Shield border, VM window |
| Pulse green | `#7ee787` | Heartbeat line |
| Status green | `#2ea043` | Active status dot |
| Accent blue | `#5fb0ff` | Window title dots |

Severity palette (UI/Discord): info `#2ecc71`, warning `#f39c12`, critical
`#e74c3c` — always paired with text/emoji, never color alone (accessibility).

## Voice

Understated, infrastructure-focused, honest. Avoid cartoon styling and avoid
over-claiming (never "always knows why a VM stopped"). Tagline: **"Monitor every
VM. Know when something changes."**

## Trademark

Do not imply endorsement by Unraid/Lime Technology. Always include the
non-affiliation statement where the project is presented.
