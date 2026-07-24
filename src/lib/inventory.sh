#!/usr/bin/env bash
# VM Sentinel — libvirt/virsh inventory with graceful degradation (spec §19).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`. Depends on common.sh, validate.sh.
#
# Every function tolerates libvirt/virsh being absent or the array being stopped:
# it returns empty/failure rather than erroring. Output is validated before use.

: "${VMS_VIRSH:=virsh}"

virsh_available() { command -v "$VMS_VIRSH" >/dev/null 2>&1 && "$VMS_VIRSH" version >/dev/null 2>&1; }

# inv_list_uuids: all defined domain UUIDs (running + stopped). Empty on failure.
inv_list_uuids() {
    virsh_available || return 0
    "$VMS_VIRSH" list --all --uuid 2>/dev/null | while IFS= read -r u; do
        u=$(printf '%s' "$u" | tr -d '[:space:]')
        [ -n "$u" ] && valid_uuid "$u" && printf '%s\n' "$u"
    done
}

# inv_name_of <uuid> -> display name (validated/sanitized). Empty on failure.
inv_name_of() {
    local uuid=$1 name
    valid_uuid "$uuid" || return 1
    virsh_available || return 1
    name=$("$VMS_VIRSH" domname "$uuid" 2>/dev/null | head -n1)
    [ -n "$name" ] || return 1
    sanitize_vm_name "$name"
}

# inv_uuid_of <name> -> uuid. The name is passed to virsh as a single argv element.
inv_uuid_of() {
    local name=$1 uuid
    virsh_available || return 1
    uuid=$("$VMS_VIRSH" domuuid "$name" 2>/dev/null | tr -d '[:space:]')
    valid_uuid "$uuid" && printf '%s' "$uuid"
}

# inv_state_of <uuid> -> running|paused|shutoff|crashed|... ; empty on failure.
inv_state_of() {
    local uuid=$1 st
    valid_uuid "$uuid" || return 1
    virsh_available || return 1
    st=$("$VMS_VIRSH" domstate "$uuid" 2>/dev/null | head -n1)
    printf '%s' "${st// /_}"
}

# inv_refresh_uuidmap: cache uuid<TAB>name pairs to tmpfs for the hot-path hook
# and the GUI. Cheap; called by the processor loop.
inv_refresh_uuidmap() {
    virsh_available || return 0
    vms_mkrundirs || return 0
    local uuid name tmp; tmp="${VMS_UUIDMAP}.tmp.$(vms_rand_token)"
    : > "$tmp" 2>/dev/null || return 0
    while IFS= read -r uuid; do
        [ -n "$uuid" ] || continue
        name=$(inv_name_of "$uuid") || name=""
        printf '%s\t%s\n' "$uuid" "$name" >> "$tmp" 2>/dev/null
    done < <(inv_list_uuids)
    mv -f "$tmp" "$VMS_UUIDMAP" 2>/dev/null || rm -f "$tmp" 2>/dev/null
}

# uuidmap_name <uuid> / uuidmap_uuid <name> : read from cache (hook-safe, no virsh).
uuidmap_name() {
    [ -f "$VMS_UUIDMAP" ] || return 1
    awk -F'\t' -v u="$1" '$1==u{print $2; found=1} END{exit !found}' "$VMS_UUIDMAP" 2>/dev/null
}
uuidmap_uuid() {
    [ -f "$VMS_UUIDMAP" ] || return 1
    awk -F'\t' -v n="$1" '$2==n{print $1; found=1; exit} END{exit !found}' "$VMS_UUIDMAP" 2>/dev/null
}

# --- Per-VM last-known state map (tmpfs) for previous_state tracking ----------
state_get() { cat "${VMS_STATE_DIR}/vmstate.${1}" 2>/dev/null; }
state_set() { printf '%s' "$2" > "${VMS_STATE_DIR}/vmstate.${1}" 2>/dev/null || true; }

# --- Maintenance context marker (spec §7) ------------------------------------
# Set by the service when array-stop / VM-Manager-shutdown is detected (best
# effort). Presence within its TTL marks events as maintenance.
maintenance_active() {
    local f="${VMS_STATE_DIR}/maintenance" now until
    [ -f "$f" ] || return 1
    now=$(date +%s); until=$(cat "$f" 2>/dev/null || echo 0)
    [ "$now" -lt "${until:-0}" ]
}
maintenance_mark() {
    local ttl=${1:-120}
    vms_mkrundirs
    printf '%s' "$(( $(date +%s) + ttl ))" > "${VMS_STATE_DIR}/maintenance" 2>/dev/null || true
}
