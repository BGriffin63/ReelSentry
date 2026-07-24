#!/usr/bin/env bash
# VM Sentinel — lint shell + PHP + XML (spec §28).
# SPDX-License-Identifier: MIT
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rc=0

echo "==> ShellCheck"
if command -v shellcheck >/dev/null 2>&1; then
    # -x follows sourced files; -e SC1091 ignores un-followable sources in CI.
    mapfile -t sh < <(find "$ROOT/src" "$ROOT/scripts" -type f \( -name '*.sh' -o -name 'vm-sentinel-hook' -o -name 'vm-sentinel-service' \))
    shellcheck -x -S warning "${sh[@]}" || rc=1
else
    echo "   shellcheck not installed; skipping (CI installs it)"
fi

echo "==> PHP lint"
if command -v php >/dev/null 2>&1; then
    while IFS= read -r f; do php -l "$f" >/dev/null || rc=1; done \
        < <(find "$ROOT/package" -name '*.php' -o -name '*.page')
else
    echo "   php not installed; skipping (CI installs it)"
fi

echo "==> XML well-formedness"
if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout "$ROOT/vm.sentinel.plg" || rc=1
    for x in "$ROOT"/templates/*.xml; do xmllint --noout "$x" || rc=1; done
else
    echo "   xmllint not installed; skipping (CI installs it)"
fi

[ "$rc" = 0 ] && echo "LINT OK" || echo "LINT FAILED"
exit $rc
