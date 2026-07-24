#!/usr/bin/env bash
# VM Sentinel — set a maintenance suppression window (spec §16).
# SPDX-License-Identifier: MIT
# Usage: suppress.sh {all|<uuid>} <minutes>   Records the suppression in history.
set -u
VMS_LIBDIR="${VMS_LIBDIR:-/usr/local/emhttp/plugins/vm.sentinel/lib}"
# shellcheck source=/dev/null
for f in common validate json redact log config queue history; do . "${VMS_LIBDIR}/${f}.sh" || exit 1; done

scope=${1:-}; mins=${2:-}
case "$mins" in ''|*[!0-9]*) echo "bad minutes" >&2; exit 2 ;; esac
[ "$scope" = "all" ] || valid_uuid "$scope" || { echo "bad scope" >&2; exit 2; }
vms_mkrundirs
until=$(( $(date +%s) + mins * 60 ))
printf '%s' "$until" > "${VMS_STATE_DIR}/suppress.${scope}" 2>/dev/null

# Record the suppression event so it is never a silent drop (spec §16).
ts=$(vms_now_iso); server=$(vms_server_name)
rec=$(printf '{%s,%s,%s,%s,%s,%s,%s,%s,%s,"notify_results":[],%s,%s}' \
    "$(json_kv_str event_id "e_$(vms_epoch_ns)_$(vms_rand_token)")" \
    "$(json_kv schema 1)" "$(json_kv_str timestamp "$ts")" \
    "$(json_kv_str server "$server")" "$(json_kv_str vm_uuid "$scope")" \
    "$(json_kv_str event_type "suppression_start")" \
    "$(json_kv_str severity info)" "$(json_kv_str classification expected)" \
    "$(json_kv notify_attempted false)" \
    "$(json_kv_str summary "Notifications suppressed for ${mins} minute(s)")" \
    "$(json_kv_str details "Maintenance suppression window set for scope ${scope}.")")
history_append "$rec"
echo ok
