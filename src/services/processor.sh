#!/usr/bin/env bash
# VM Sentinel — event processor (spec §6, §7, §17). Runs OFF the critical path.
# SPDX-License-Identifier: MIT
#
# Drains the tmpfs spool under a single-flight lock, classifies each event,
# deduplicates, applies quiet-hours/suppression/cooldown, records history, and
# dispatches notifications. Provider failures never abort draining (fail-open).

set -u
VMS_LIBDIR="${VMS_LIBDIR:-/usr/local/emhttp/plugins/vm.sentinel/lib}"
VMS_NOTIFYDIR="${VMS_NOTIFYDIR:-/usr/local/emhttp/plugins/vm.sentinel/notifications}"

# shellcheck source=/dev/null
for f in common validate json redact log config queue history inventory normalize classify; do
    . "${VMS_LIBDIR}/${f}.sh" || { echo "processor: cannot load ${f}.sh" >&2; exit 1; }
done
# shellcheck source=/dev/null
for f in provider native discord dispatch; do
    . "${VMS_NOTIFYDIR}/${f}.sh" || { echo "processor: cannot load ${f}.sh" >&2; exit 1; }
done

# process_one <spool-file>: parse and handle a single spool record.
process_one() {
    local file=$1 line
    line=$(head -n1 "$file" 2>/dev/null)
    # Record shape: 1<TAB>ns<TAB>op<TAB>sub<TAB>name_b64<TAB>extra_b64
    local ver ns op sub name_b64 extra_b64
    IFS=$'\t' read -r ver ns op sub name_b64 extra_b64 <<<"$line"
    if [ "$ver" != "1" ] || [ -z "${op:-}" ]; then
        vms_log_warning queue "corrupt spool record; quarantining"
        mv -f "$file" "${VMS_SPOOL_BAD_DIR}/" 2>/dev/null || rm -f "$file" 2>/dev/null
        spool_bump_dropped
        return 0
    fi
    local vm_name; vm_name=$(spool_decode "$name_b64")

    # Resolve durable identity (UUID) from the cached map; backfill via virsh.
    local uuid; uuid=$(uuidmap_uuid "$vm_name" 2>/dev/null || true)
    [ -z "$uuid" ] && uuid=$(inv_uuid_of "$vm_name" 2>/dev/null || true)
    [ -z "$uuid" ] && uuid="unknown"

    # Normalize.
    local event_type current_state prev_state maint sev cls summary details
    event_type=$(normalize_event "$op" "$sub")
    current_state=$(state_for_event "$event_type")
    prev_state=$(state_get "$uuid"); prev_state=${prev_state:-unknown}

    maint=0; maintenance_active && maint=1
    cls=$(classify_event "$event_type" "$sub" "$maint")
    sev=$(severity_for_event "$event_type" "$cls")
    summary=$(summary_for_event "$vm_name" "$event_type" "$cls")
    details=$(details_for_event "$event_type" "$cls" "$maint")

    # Deduplicate identical rapid events.
    if ! dedup_should_emit "$uuid" "$event_type"; then
        vms_log_debug queue "dedup drop $uuid $event_type"
        state_set "$uuid" "$current_state"
        rm -f "$file" 2>/dev/null
        return 0
    fi

    # Decide whether to notify.
    local notify_key notify_attempted="false" results="[]" reason=""
    notify_key=$(event_is_notifiable_key "$event_type")
    local should_notify=1
    [ -z "$notify_key" ] && { should_notify=0; reason="event not user-notifiable"; }
    if [ "$should_notify" = "1" ] && ! config_vm_enabled "$uuid"; then
        should_notify=0; reason="monitoring disabled for VM"
    fi
    if [ "$should_notify" = "1" ] && [ -n "$notify_key" ] && \
       [ "$(config_vm_get "$uuid" "$notify_key" "$(_default_toggle "$notify_key")")" != "1" ]; then
        should_notify=0; reason="event toggle off"
    fi
    if [ "$should_notify" = "1" ] && suppression_active "$uuid"; then
        should_notify=0; reason="maintenance suppression active"
    fi
    if [ "$should_notify" = "1" ] && ! quiet_allows "$event_type" "$sev"; then
        should_notify=0; reason="quiet hours"
    fi
    if [ "$should_notify" = "1" ] && ! cooldown_ok "$uuid" "$event_type"; then
        should_notify=0; reason="cooldown"
    fi

    local event_id timestamp server health
    event_id="e_${ns}_$(vms_rand_token)"
    timestamp=$(vms_now_iso)
    server=$(vms_server_name)
    health=$(cat "${VMS_HEALTH_DIR}/${uuid}.state" 2>/dev/null || echo "n/a")

    if [ "$should_notify" = "1" ]; then
        notify_attempted="true"
        results=$(notify_dispatch "$event_id" "$server" "$uuid" "$vm_name" \
            "$event_type" "$sev" "$cls" "$timestamp" "$prev_state" \
            "$current_state" "$health" "$summary" "$details")
    else
        vms_log_debug notify "not notifying $uuid $event_type: $reason"
    fi

    # Build and append the history record (secrets can never appear here).
    local rec
    rec=$(build_event_json)
    history_append "$rec"

    # Update per-VM state + last-seen name mapping, then remove the spool file.
    state_set "$uuid" "$current_state"
    rm -f "$file" 2>/dev/null
    return 0
}

# _default_toggle: sensible per-event default when neither VM nor global set it.
_default_toggle() {
    case "$1" in
        notify_crash)    echo 1 ;;   # crash on by default
        notify_stop)     echo 1 ;;   # unexpected/indeterminate stop on by default
        notify_shutdown) echo 1 ;;
        notify_start|notify_pause|notify_resume|notify_reboot) echo 0 ;;
        *) echo 0 ;;
    esac
}

# build_event_json: assemble the normalized event record from locals in scope.
# 18 fields -> 18 %s placeholders (notify_results key is inlined literally).
build_event_json() {
    printf '{%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,"notify_results":%s,%s,%s,%s,%s}' \
        "$(json_kv_str event_id "$event_id")" \
        "$(json_kv schema 1)" \
        "$(json_kv_str timestamp "$timestamp")" \
        "$(json_kv_str server "$server")" \
        "$(json_kv_str vm_uuid "$uuid")" \
        "$(json_kv_str vm_name "$vm_name")" \
        "$(json_kv_str raw_action "$op")" \
        "$(json_kv_str raw_sub_action "$sub")" \
        "$(json_kv_str event_type "$event_type")" \
        "$(json_kv_str previous_state "$prev_state")" \
        "$(json_kv_str current_state "$current_state")" \
        "$(json_kv_str severity "$sev")" \
        "$(json_kv_str classification "$cls")" \
        "$results" \
        "$(json_kv_str health_state "$health")" \
        "$(json_kv "notify_attempted" "$notify_attempted")" \
        "$(json_kv_str summary "$summary")" \
        "$(json_kv_str details "$details")"
}

# process_drain: handle all spool files in timestamp order under single-flight lock.
process_drain() {
    vms_mkrundirs || return 0
    if ! vms_lock_acquire processor 0; then
        vms_log_debug queue "another processor holds the lock; exiting"
        return 0
    fi
    inv_refresh_uuidmap
    local f count=0
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        process_one "$f"
        count=$((count+1))
        [ "$count" -ge 1000 ] && break   # bound per-drain work
    done < <(find "$VMS_SPOOL_DIR" -maxdepth 1 -type f -name '*.ev' 2>/dev/null | sort)
    vms_lock_release processor
    [ "$count" -gt 0 ] && vms_log_debug queue "drained $count event(s)"
    return 0
}

# CLI: processor.sh {drain|loop}
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-drain}" in
        drain) process_drain ;;
        loop)
            while :; do
                process_drain
                # Short sleep; a hook 'trigger' file shortens perceived latency.
                for _ in 1 2 3; do
                    [ -f "${VMS_RUN_DIR}/trigger" ] && { rm -f "${VMS_RUN_DIR}/trigger"; break; }
                    sleep 1
                done
            done
            ;;
        *) echo "usage: $0 {drain|loop}" >&2; exit 2 ;;
    esac
fi
