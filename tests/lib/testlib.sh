#!/usr/bin/env bash
# VM Sentinel — minimal test harness (spec §27). SPDX-License-Identifier: MIT
# Provides assertions + an isolated temp environment so tests run entirely
# outside Unraid. Source this at the top of every test file.
set -u

TESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_ROOT/.." && pwd)"

VMS_TEST_PASS=0
VMS_TEST_FAIL=0

# Isolated filesystem so nothing touches the real host.
vms_test_env() {
    export VMS_ROOT_TMP="$(mktemp -d)"
    export VMS_CONFIG_DIR="$VMS_ROOT_TMP/config"
    export VMS_CONFIG_FILE="$VMS_CONFIG_DIR/config.json"
    export VMS_CONFIG_SNAPSHOT="$VMS_CONFIG_DIR/config.snapshot"
    export VMS_SECRETS_FILE="$VMS_CONFIG_DIR/secrets.json"
    export VMS_RUN_DIR="$VMS_ROOT_TMP/run"
    export VMS_SPOOL_DIR="$VMS_RUN_DIR/spool"
    export VMS_SPOOL_BAD_DIR="$VMS_SPOOL_DIR/bad"
    export VMS_LOCK_DIR="$VMS_RUN_DIR/locks"
    export VMS_HEALTH_DIR="$VMS_RUN_DIR/health"
    export VMS_STATE_DIR="$VMS_RUN_DIR/state"
    export VMS_UUIDMAP="$VMS_RUN_DIR/uuidmap"
    export VMS_HISTORY_DIR="$VMS_ROOT_TMP/history"
    export VMS_HISTORY_FALLBACK_DIR="$VMS_ROOT_TMP/history_fb"
    export VMS_LOG_DIR="$VMS_ROOT_TMP/log"
    export VMS_LOG_FILE="$VMS_LOG_DIR/vm-sentinel.log"
    mkdir -p "$VMS_CONFIG_DIR"
}

vms_test_cleanup() { [ -n "${VMS_ROOT_TMP:-}" ] && rm -rf "$VMS_ROOT_TMP"; }

vms_load() { for f in "$@"; do . "$REPO_ROOT/src/lib/$f.sh"; done; }
vms_load_notify() { for f in "$@"; do . "$REPO_ROOT/src/notifications/$f.sh"; done; }

ok()   { VMS_TEST_PASS=$((VMS_TEST_PASS+1)); printf 'ok   - %s\n' "$1"; }
notok(){ VMS_TEST_FAIL=$((VMS_TEST_FAIL+1)); printf 'FAIL - %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

assert_eq()   { if [ "$2" = "$3" ]; then ok "$1"; else notok "$1" "got[$2] want[$3]"; fi; }
assert_ne()   { if [ "$2" != "$3" ]; then ok "$1"; else notok "$1" "both[$2]"; fi; }
assert_true() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else notok "$1" "cmd failed: $2"; fi; }
assert_false(){ if eval "$2" >/dev/null 2>&1; then notok "$1" "cmd unexpectedly ok: $2"; else ok "$1"; fi; }
assert_contains(){ case "$2" in *"$3"*) ok "$1";; *) notok "$1" "[$2] lacks [$3]";; esac; }
assert_not_contains(){ case "$2" in *"$3"*) notok "$1" "[$2] contains [$3]";; *) ok "$1";; esac; }

vms_test_summary() {
    echo "-----"
    echo "PASS=$VMS_TEST_PASS FAIL=$VMS_TEST_FAIL"
    [ "$VMS_TEST_FAIL" -eq 0 ]
}
