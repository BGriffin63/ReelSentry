# Third-Party Notices

VM Sentinel is licensed under the MIT License (see [`LICENSE`](LICENSE)).

## Bundled third-party code
**None.** VM Sentinel bundles no third-party source code or binaries. No code was
copied from other plugins.

## Runtime dependencies (provided by Unraid, not bundled)
VM Sentinel relies only on tools already present on a supported Unraid system:

| Tool | Provided by | Use |
|------|-------------|-----|
| `bash`, coreutils (`sed`, `awk`, `grep`, `find`, `base64`, `date`, `tar`, `xz`) | Slackware base (Unraid) | Core logic, packaging |
| `curl` | Unraid | Discord webhook delivery (HTTPS) |
| `libvirt` / `virsh` | Unraid VM Manager | VM inventory, state, guest-agent check |
| Unraid `notify` CLI | Unraid | Native notifications |
| PHP | Unraid emhttp | WebGUI |
| Python 3 stdlib | build-time only | Icon generation (`scripts/generate-icons.py`) |

None of these are redistributed by this project.

## Assets
The VM Sentinel logo and all icons are **original works** created for this project
and are licensed under the project's MIT License. No copyrighted third-party
artwork is included.

## Trademarks
"Unraid" and "Lime Technology" are trademarks of Lime Technology, Inc. "Discord"
is a trademark of Discord Inc. These names are used only for identification and
interoperability. VM Sentinel is not affiliated with or endorsed by either.

_If future changes introduce third-party code, list each work here with its
license and attribution before merging._
