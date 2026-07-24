#!/usr/bin/env bash
# ReelSentry — release helper: build, package, and stamp the .plg (spec §29).
# SPDX-License-Identifier: MIT
# Produces immutable, checksum-referenced artifacts. Does NOT push or publish —
# that is a manual/CI step so a human confirms before release.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
PKGVER="${VERSION//-/_}"

"$ROOT/scripts/generate-icons.py" >/dev/null 2>&1 || python3 "$ROOT/scripts/generate-icons.py"
bash "$ROOT/scripts/build.sh"
bash "$ROOT/scripts/package.sh"

TXZ="$ROOT/build/reelsentry-${PKGVER}-x86_64-1.txz"
SHA="$(cat "$TXZ.sha256")"

echo "==> Stamping reelsentry.plg for v$VERSION"
OUT="$ROOT/build/reelsentry.plg"
# Match the whole entity line (not a one-time placeholder) so re-stamping works
# on every release, whether the input still has the placeholder or a prior hash.
sed -E \
    -e "s/(<!ENTITY[[:space:]]+version[[:space:]]+\")[^\"]*(\")/\1${VERSION}\2/" \
    -e "s/(<!ENTITY[[:space:]]+sha256[[:space:]]+\")[^\"]*(\")/\1${SHA}\2/" \
    "$ROOT/reelsentry.plg" > "$OUT"

echo "==> Release artifacts in build/:"
echo "    $(basename "$TXZ")"
echo "    $(basename "$TXZ").sha256"
echo "    reelsentry.plg (stamped)"
echo ""
echo "Next (manual): create GitHub release v$VERSION, upload the .txz + .sha256,"
echo "commit the stamped reelsentry.plg to main. See docs/RELEASE.md."
