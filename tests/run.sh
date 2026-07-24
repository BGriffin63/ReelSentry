#!/usr/bin/env bash
# ReelSentry — run all tests (spec §27, §28). SPDX-License-Identifier: MIT
set -uo pipefail
TESTS_ROOT="$(cd "$(dirname "$0")" && pwd)"
total_fail=0; files=0
for group in unit security integration; do
    for t in "$TESTS_ROOT/$group"/*.sh; do
        [ -f "$t" ] || continue
        files=$((files+1))
        echo "### $group/$(basename "$t")"
        if ! bash "$t"; then total_fail=$((total_fail+1)); fi
        echo
    done
done
echo "==================================="
if [ "$total_fail" -eq 0 ]; then
    echo "ALL TEST FILES PASSED ($files files)"; exit 0
else
    echo "$total_fail TEST FILE(S) FAILED"; exit 1
fi
