#!/usr/bin/env bash
# VM Sentinel — build the Slackware .txz package + SHA256 (spec §20, §29).
# SPDX-License-Identifier: MIT
# Produces build/vm.sentinel-<version>-x86_64-1.txz and a .sha256 sidecar.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$ROOT/build/stage"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
# Slackware package versions cannot contain '-'; map semver pre-release safely.
PKGVER="${VERSION//-/_}"
OUT="$ROOT/build/vm.sentinel-${PKGVER}-x86_64-1.txz"

[ -d "$STAGE" ] || { echo "Run build.sh first (no stage)"; exit 1; }

# Slackware metadata.
mkdir -p "$STAGE/install"
cat > "$STAGE/install/slack-desc" <<'EOF'
vm.sentinel: VM Sentinel (Unraid VM monitoring & notifications)
vm.sentinel:
vm.sentinel: Monitors VM lifecycle events and optional health checks, records a
vm.sentinel: local event history, and notifies via Unraid's native notification
vm.sentinel: system and/or a Discord webhook (no bot required). Fail-open by
vm.sentinel: design; never blocks VM operations. Independent community project,
vm.sentinel: not affiliated with Lime Technology, Inc.
vm.sentinel:
vm.sentinel: Homepage: https://github.com/BGriffin63/unraid-vm-sentinel
vm.sentinel:
EOF

echo "==> Creating $OUT"
if command -v makepkg >/dev/null 2>&1; then
    ( cd "$STAGE" && makepkg -l y -c n "$OUT" )
else
    # Portable fallback: a .txz is a tar.xz. Build with tar + xz.
    ( cd "$STAGE" && tar --owner=0 --group=0 -cf - . | xz -9 > "$OUT" )
fi

sha256sum "$OUT" | awk '{print $1}' > "$OUT.sha256"
echo "==> SHA256: $(cat "$OUT.sha256")"
echo "==> Package: $OUT"
