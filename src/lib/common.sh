#!/usr/bin/env bash
# VM Sentinel — common paths and helpers.
# SPDX-License-Identifier: MIT
# This file is sourced, never executed. It must not call `exit`.
#
# All paths are overridable via environment variables so the test suite can run
# entirely outside Unraid against a temporary filesystem.

# --- Identity -----------------------------------------------------------------
: "${VMS_ID:=vm.sentinel}"
: "${VMS_NAME:=VM Sentinel}"

# --- Persistent config (small, survives reboot; on the flash) -----------------
: "${VMS_CONFIG_DIR:=/boot/config/plugins/${VMS_ID}}"
: "${VMS_CONFIG_FILE:=${VMS_CONFIG_DIR}/config.json}"
: "${VMS_SECRETS_FILE:=${VMS_CONFIG_DIR}/secrets.json}"

# --- Runtime (tmpfs; lost on reboot by design) --------------------------------
: "${VMS_RUN_DIR:=/var/run/${VMS_ID}}"
: "${VMS_SPOOL_DIR:=${VMS_RUN_DIR}/spool}"
: "${VMS_SPOOL_BAD_DIR:=${VMS_SPOOL_DIR}/bad}"
: "${VMS_LOCK_DIR:=${VMS_RUN_DIR}/locks}"
: "${VMS_HEALTH_DIR:=${VMS_RUN_DIR}/health}"
: "${VMS_STATE_DIR:=${VMS_RUN_DIR}/state}"
: "${VMS_UUIDMAP:=${VMS_RUN_DIR}/uuidmap}"

# --- Event history (high churn; appdata with tmpfs fallback) ------------------
: "${VMS_HISTORY_DIR:=/mnt/user/appdata/${VMS_ID}/history}"
: "${VMS_HISTORY_FALLBACK_DIR:=/var/log/${VMS_ID}/history}"
: "${VMS_HISTORY_FILE:=history.jsonl}"

# --- Logging ------------------------------------------------------------------
: "${VMS_LOG_DIR:=/var/log/${VMS_ID}}"
: "${VMS_LOG_FILE:=${VMS_LOG_DIR}/vm-sentinel.log}"
: "${VMS_LOG_MAX_BYTES:=1048576}"   # 1 MiB then rotate
: "${VMS_LOG_KEEP:=3}"
: "${VMS_DEBUG:=0}"

# --- Behaviour tunables (safe defaults) ---------------------------------------
: "${VMS_QUEUE_MAX:=500}"           # max spool files before dropping non-critical
: "${VMS_DEDUP_WINDOW:=5}"          # seconds: collapse identical lifecycle events
: "${VMS_HEALTH_MIN_INTERVAL:=30}"  # seconds: never poll faster than this
: "${VMS_NET_CONNECT_TIMEOUT:=5}"   # seconds
: "${VMS_NET_TOTAL_TIMEOUT:=10}"    # seconds
: "${VMS_HTTP_RETRIES:=2}"          # bounded retries for Discord

# vms_now_iso: absolute ISO-8601 timestamp with timezone offset.
vms_now_iso() { date +%Y-%m-%dT%H:%M:%S%z 2>/dev/null | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/'; }

# vms_epoch_ns: nanosecond epoch (falls back to seconds*1e9 if %N unsupported).
vms_epoch_ns() {
    local n; n=$(date +%s%N 2>/dev/null)
    case "$n" in
        *N|"") echo "$(( $(date +%s) * 1000000000 ))" ;;
        *) echo "$n" ;;
    esac
}

# vms_rand_token: short unpredictable token for temp/spool names (no external deps).
vms_rand_token() {
    local t=""
    if [ -r /dev/urandom ]; then
        t=$(LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 12)
    fi
    [ -n "$t" ] && { printf '%s' "$t"; return 0; }
    printf '%s%s' "$$" "${RANDOM}${RANDOM}"
}

# vms_server_name: best-effort Unraid server hostname.
vms_server_name() {
    if [ -n "${VMS_SERVER:-}" ]; then printf '%s' "$VMS_SERVER"; return 0; fi
    hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || echo "unraid"
}

# --- Locking (dependency-free; no reliance on util-linux `flock`) -------------
# Uses mkdir() atomicity. A stale lock whose holder PID is dead is reclaimed.
# vms_lock_acquire <name> [timeout_s]  -> 0 acquired / 1 not.
#   timeout 0/absent = single non-blocking attempt.
vms_lock_acquire() {
    local name=$1 timeout=${2:-0}
    local safe=${name//[^A-Za-z0-9._-]/_}
    local d="${VMS_LOCK_DIR}/${safe}.lockd"
    mkdir -p "$VMS_LOCK_DIR" 2>/dev/null || return 1
    local deadline=$(( $(date +%s) + timeout ))
    while :; do
        if mkdir "$d" 2>/dev/null; then
            printf '%s' "$$" > "$d/pid" 2>/dev/null
            return 0
        fi
        # Stale-holder reclaim.
        local p; p=$(cat "$d/pid" 2>/dev/null)
        if [ -n "$p" ] && ! kill -0 "$p" 2>/dev/null; then
            rm -rf "$d" 2>/dev/null
            continue
        fi
        [ "$timeout" -gt 0 ] && [ "$(date +%s)" -lt "$deadline" ] || return 1
        sleep 0.2 2>/dev/null || sleep 1
    done
}

vms_lock_release() {
    local safe=${1//[^A-Za-z0-9._-]/_}
    rm -rf "${VMS_LOCK_DIR}/${safe}.lockd" 2>/dev/null
}

# vms_mkrundirs: create tmpfs runtime tree with tight perms. Never aborts caller.
vms_mkrundirs() {
    local d
    for d in "$VMS_RUN_DIR" "$VMS_SPOOL_DIR" "$VMS_SPOOL_BAD_DIR" \
             "$VMS_LOCK_DIR" "$VMS_HEALTH_DIR" "$VMS_STATE_DIR"; do
        mkdir -p "$d" 2>/dev/null || return 1
        chmod 700 "$d" 2>/dev/null || true
    done
    return 0
}
