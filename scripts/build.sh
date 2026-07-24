#!/usr/bin/env bash
# ReelSentry — assemble the installable plugin tree into build/stage (spec §20).
# SPDX-License-Identifier: MIT
# Runs on Linux/CI. Copies src/ libraries into the WebGUI package tree so the
# result mirrors exactly what installs to /usr/local/emhttp/plugins/reelsentry.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$ROOT/build/stage"
PLUGDST="$STAGE/usr/local/emhttp/plugins/reelsentry"

echo "==> Cleaning stage"
rm -rf "$STAGE"; mkdir -p "$PLUGDST"

echo "==> Copying WebGUI package tree"
cp -a "$ROOT/package/usr/local/emhttp/plugins/reelsentry/." "$PLUGDST/"

echo "==> Copying source libraries into package"
for d in lib hooks notifications services; do
    mkdir -p "$PLUGDST/$d"
    cp -a "$ROOT/src/$d/." "$PLUGDST/$d/"
done

echo "==> Version + assets"
cp "$ROOT/VERSION" "$PLUGDST/VERSION"
mkdir -p "$PLUGDST/assets"
cp "$ROOT/assets/reelsentry-128.png" "$PLUGDST/assets/" 2>/dev/null || true
cp "$ROOT/LICENSE" "$PLUGDST/LICENSE"

echo "==> Normalizing permissions"
find "$PLUGDST" -type f -name '*.sh' -exec chmod 755 {} +
chmod 755 "$PLUGDST/hooks/reelsentry-hook" "$PLUGDST/services/reelsentry-service" 2>/dev/null || true
find "$PLUGDST" -type f \( -name '*.php' -o -name '*.page' -o -name '*.css' -o -name '*.js' -o -name '*.png' \) -exec chmod 644 {} +

echo "==> Stage ready at $STAGE"
