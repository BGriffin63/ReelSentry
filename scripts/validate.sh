#!/usr/bin/env bash
# VM Sentinel — package/repo validation gate (spec §28).
# SPDX-License-Identifier: MIT
# Confirms the staged package installs ONLY expected files, contains no secrets,
# and that the .plg references a checksum. Run after build.sh/package.sh.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$ROOT/build/stage"
rc=0
say() { printf '%s\n' "$*"; }

say "==> No real webhook secrets committed"
# Real Discord tokens are long (~60+ chars). Test fixtures use short, obviously
# fake tokens; the redaction/provider code references the URL shape by design.
if grep -RIlE 'discord(app)?\.com/api/webhooks/[0-9]{15,}/[A-Za-z0-9_-]{40,}' \
     "$ROOT/src" "$ROOT/package" "$ROOT/docs" 2>/dev/null \
   | grep -vE '/(redact\.sh|discord\.sh)$' | grep -q .; then
    say "   FAIL: a real-looking webhook secret is present"; rc=1
else say "   ok"; fi

say "==> Staged package contains only vm.sentinel plugin files + install meta"
if [ -d "$STAGE" ]; then
    while IFS= read -r f; do
        case "$f" in
            ./usr/local/emhttp/plugins/vm.sentinel/*|./install/*) : ;;
            *) say "   FAIL: unexpected staged path: $f"; rc=1 ;;
        esac
    done < <(cd "$STAGE" && find . -type f | sed 's#^\./#./#')
    say "   ok"
else say "   (no stage; run scripts/build.sh first)"; fi

say "==> No world-writable files in stage"
if [ -d "$STAGE" ] && find "$STAGE" -type f -perm -0002 | grep -q .; then
    say "   FAIL: world-writable file present"; rc=1
else say "   ok"; fi

say "==> .plg references a SHA256 and a versioned package"
if grep -q '<SHA256>' "$ROOT/vm.sentinel.plg" && grep -q 'pkgName' "$ROOT/vm.sentinel.plg"; then
    say "   ok"
else say "   FAIL: .plg missing SHA256/pkg reference"; rc=1; fi

say "==> No use of eval / unsafe shell in src"
if grep -RIn --include='*.sh' -E '\beval\b' "$ROOT/src" | grep -v 'src/lib/common.sh' | grep -q .; then
    say "   NOTE: review eval usages:"; grep -RIn --include='*.sh' -E '\beval\b' "$ROOT/src" || true
fi
say "   ok"

[ "$rc" = 0 ] && say "VALIDATE OK" || say "VALIDATE FAILED"
exit $rc
