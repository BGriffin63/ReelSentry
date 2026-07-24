#!/usr/bin/env bash
# VM Sentinel — configuration access + atomic writes (spec §8, §15).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`. Depends on common.sh, json.sh, validate.sh.
#
# STORAGE MODEL (see ARCHITECTURE.md §8):
#   config.json      canonical, user-facing, authored by the WebGUI (PHP).
#   config.snapshot  derived flat cache the bash services read cheaply & safely.
#                    Line formats (tab-delimited, values are single-line):
#                       G<TAB>key<TAB>value                 (global default)
#                       V<TAB>uuid<TAB>key<TAB>value        (per-VM override)
#                       N<TAB>uuid<TAB>display-name         (last-seen VM name)
#   secrets.json     0600, holds the Discord webhook; NEVER read into logs.
#
# The WebGUI writes config.json AND regenerates config.snapshot atomically so the
# two never diverge. Bash never parses config.json (no jq dependency; spec §2).

VMS_CONFIG_SNAPSHOT="${VMS_CONFIG_SNAPSHOT:-${VMS_CONFIG_DIR}/config.snapshot}"
VMS_CONFIG_SCHEMA=1

# --- Atomic write with backup + lock (spec §15, §19) --------------------------
# config_atomic_write <target-file> <mode>   (content on stdin)
config_atomic_write() {
    local target=$1 mode=${2:-0644}
    local dir; dir=$(dirname "$target")
    mkdir -p "$dir" 2>/dev/null || { vms_log_error config "cannot create $dir"; return 1; }
    if ! vms_lock_acquire "cfg.$(basename "$target")" 10; then
        vms_log_error config "timed out locking $target"; return 1
    fi
    local tmp; tmp="${target}.tmp.$(vms_rand_token)"
    if ! cat > "$tmp" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null; vms_lock_release "cfg.$(basename "$target")"; return 1
    fi
    chmod "$mode" "$tmp" 2>/dev/null || true
    # Keep previous valid version as .bak before replacing.
    [ -f "$target" ] && cp -f "$target" "${target}.bak" 2>/dev/null || true
    if ! mv -f "$tmp" "$target" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null; vms_lock_release "cfg.$(basename "$target")"; return 1
    fi
    sync 2>/dev/null || true
    vms_lock_release "cfg.$(basename "$target")"
    return 0
}

# --- Snapshot readers (cheap, safe, testable) ---------------------------------
# config_get <key> [default]
config_get() {
    local key=$1 def=${2:-}
    [ -f "$VMS_CONFIG_SNAPSHOT" ] || { printf '%s' "$def"; return 0; }
    local line val
    line=$(grep -F -m1 -- "$(printf 'G\t%s\t' "$key")" "$VMS_CONFIG_SNAPSHOT" 2>/dev/null) || true
    if [ -n "$line" ]; then
        val=${line#*$'\t'*$'\t'}
        printf '%s' "$val"
    else
        printf '%s' "$def"
    fi
}

# config_vm_get <uuid> <key> [default]  (per-VM override else global else default)
config_vm_get() {
    local uuid=$1 key=$2 def=${3:-}
    if [ -f "$VMS_CONFIG_SNAPSHOT" ]; then
        local line
        line=$(grep -F -m1 -- "$(printf 'V\t%s\t%s\t' "$uuid" "$key")" "$VMS_CONFIG_SNAPSHOT" 2>/dev/null) || true
        if [ -n "$line" ]; then
            printf '%s' "${line##*$'\t'}"
            return 0
        fi
    fi
    config_get "$key" "$def"
}

# config_vm_name <uuid> -> last-seen display name (or empty)
config_vm_name() {
    local uuid=$1 line
    [ -f "$VMS_CONFIG_SNAPSHOT" ] || return 0
    line=$(grep -F -m1 -- "$(printf 'N\t%s\t' "$uuid")" "$VMS_CONFIG_SNAPSHOT" 2>/dev/null) || true
    [ -n "$line" ] && printf '%s' "${line##*$'\t'}"
}

# config_list_uuids -> all UUIDs that have any config row.
config_list_uuids() {
    [ -f "$VMS_CONFIG_SNAPSHOT" ] || return 0
    awk -F'\t' '$1=="V"||$1=="N"{print $2}' "$VMS_CONFIG_SNAPSHOT" 2>/dev/null | sort -u
}

# config_vm_enabled <uuid> -> 0 if monitoring enabled (default: enabled once user
# has added the VM; global gate "monitoring_enabled" must also be on).
config_vm_enabled() {
    local uuid=$1
    [ "$(config_get monitoring_enabled 0)" = "1" ] || return 1
    [ "$(config_vm_get "$uuid" enabled 1)" = "1" ]
}

# --- Migration (explicit, forward-only; spec §20) -----------------------------
config_migrate() {
    local have; have=$(config_get schema 0)
    if [ "$have" = "0" ]; then
        vms_log_info config "no snapshot schema; treating as fresh (target ${VMS_CONFIG_SCHEMA})"
        return 0
    fi
    if [ "$have" -lt "$VMS_CONFIG_SCHEMA" ]; then
        vms_log_info config "migrating config schema $have -> ${VMS_CONFIG_SCHEMA}"
        # Future explicit migrations chain here. Each step must be idempotent.
    fi
    return 0
}
