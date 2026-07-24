#!/usr/bin/env bash
# VM Sentinel — agentless health checks with stateful transitions (spec §9).
# SPDX-License-Identifier: MIT
#
# Opt-in, disabled by default. Only CONFIRMED transitions to Unhealthy and
# Recovered emit notifications (anti-spam). Checks are suspended while the VM is
# intentionally stopped, and a startup grace period avoids false alarms during
# guest boot. Minimum interval clamped to VMS_HEALTH_MIN_INTERVAL.

set -u
VMS_LIBDIR="${VMS_LIBDIR:-/usr/local/emhttp/plugins/vm.sentinel/lib}"
VMS_NOTIFYDIR="${VMS_NOTIFYDIR:-/usr/local/emhttp/plugins/vm.sentinel/notifications}"
# shellcheck source=/dev/null
for f in common validate json redact log config queue history inventory classify; do
    . "${VMS_LIBDIR}/${f}.sh" || exit 1
done
# shellcheck source=/dev/null
for f in provider native discord dispatch; do . "${VMS_NOTIFYDIR}/${f}.sh" || exit 1; done

# --- Individual check primitives (strictly validated, no shell fragments) -----

# hc_icmp <host> <timeout_s> -> 0 up / 1 down
hc_icmp() {
    local host=$1 to=$2
    valid_hostname "$host" || return 1
    # -c1 one packet, -w total deadline. host is a single argv element.
    ping -c 1 -w "$to" -- "$host" >/dev/null 2>&1
}

# hc_tcp <host> <port> <timeout_s> -> 0 open / 1 closed
hc_tcp() {
    local host=$1 port=$2 to=$3
    valid_hostname "$host" || return 1
    valid_port "$port" || return 1
    # Prefer bash /dev/tcp (no external dep); wrap in timeout.
    timeout "$to" bash -c 'exec 3<>"/dev/tcp/$0/$1"' "$host" "$port" >/dev/null 2>&1
}

# hc_agent <uuid> <timeout_s> -> 0 responding / 1 not
# [VERIFY] guest-agent path/permission on Unraid 7.2 (RESEARCH.md §7).
hc_agent() {
    local uuid=$1 to=$2
    valid_uuid "$uuid" || return 1
    virsh_available || return 1
    timeout "$to" "$VMS_VIRSH" qemu-agent-command "$uuid" \
        '{"execute":"guest-ping"}' >/dev/null 2>&1
}

# hc_run <uuid> -> 0 healthy / 1 unhealthy for one probe based on config.
hc_run() {
    local uuid=$1 type target port to
    type=$(config_vm_get "$uuid" health_type none)
    to=$(config_vm_get "$uuid" health_timeout 5); case "$to" in ''|*[!0-9]*) to=5 ;; esac
    target=$(config_vm_get "$uuid" health_target "")
    port=$(config_vm_get "$uuid" health_port "")
    case "$type" in
        icmp)  hc_icmp "$target" "$to" ;;
        tcp)   hc_tcp "$target" "$port" "$to" ;;
        agent) hc_agent "$uuid" "$to" ;;
        *)     return 2 ;;   # disabled / none
    esac
}

# --- State machine ------------------------------------------------------------
_hstate() { cat "${VMS_HEALTH_DIR}/${1}.state" 2>/dev/null || echo "Unknown"; }
_hset()   { printf '%s' "$2" > "${VMS_HEALTH_DIR}/${1}.state" 2>/dev/null || true; }
_hcnt()   { cat "${VMS_HEALTH_DIR}/${1}.${2}" 2>/dev/null || echo 0; }
_hcntset(){ printf '%s' "$3" > "${VMS_HEALTH_DIR}/${1}.${2}" 2>/dev/null || true; }

# hc_emit <uuid> <name> <event_type health_fail|health_recover> <severity> <summary> <details>
hc_emit() {
    local uuid=$1 name=$2 etype=$3 sev=$4 summary=$5 details=$6
    local key
    case "$etype" in
        health_fail)    key=notify_health_fail ;;
        health_recover) key=notify_health_recover ;;
    esac
    local server ts eid results="[]" attempted="false"
    server=$(vms_server_name); ts=$(vms_now_iso); eid="e_$(vms_epoch_ns)_$(vms_rand_token)"
    if config_vm_enabled "$uuid" && \
       [ "$(config_vm_get "$uuid" "$key" 1)" = "1" ] && \
       ! suppression_active "$uuid" && quiet_allows "$etype" "$sev" && \
       cooldown_ok "$uuid" "$etype"; then
        attempted="true"
        results=$(notify_dispatch "$eid" "$server" "$uuid" "$name" "$etype" "$sev" \
            "indeterminate" "$ts" "n/a" "n/a" "$(_hstate "$uuid")" "$summary" "$details")
    fi
    local rec
    rec=$(printf '{%s,%s,%s,%s,%s,%s,%s,%s,%s,"notify_results":%s,%s,%s,%s}' \
        "$(json_kv_str event_id "$eid")" "$(json_kv schema 1)" \
        "$(json_kv_str timestamp "$ts")" "$(json_kv_str server "$server")" \
        "$(json_kv_str vm_uuid "$uuid")" "$(json_kv_str vm_name "$name")" \
        "$(json_kv_str event_type "$etype")" "$(json_kv_str severity "$sev")" \
        "$(json_kv_str classification indeterminate)" "$results" \
        "$(json_kv health_state "$(json_escape_string "$(_hstate "$uuid")")")" \
        "$(json_kv notify_attempted "$attempted")" \
        "$(printf '%s,%s' "$(json_kv_str summary "$summary")" "$(json_kv_str details "$details")")")
    history_append "$rec"
}

# hc_step <uuid>: advance the state machine one probe.
hc_step() {
    local uuid=$1
    config_vm_enabled "$uuid" || return 0
    [ "$(config_vm_get "$uuid" health_type none)" != "none" ] || return 0

    # Suspend while intentionally stopped.
    local st; st=$(inv_state_of "$uuid")
    case "$st" in
        running|"") : ;;                     # empty = unknown, still probe target
        *) _hset "$uuid" "Suspended"; return 0 ;;
    esac

    # Respect min interval + configured interval.
    local iv last now; iv=$(config_vm_get "$uuid" health_interval 60)
    case "$iv" in ''|*[!0-9]*) iv=60 ;; esac
    [ "$iv" -lt "$VMS_HEALTH_MIN_INTERVAL" ] && iv=$VMS_HEALTH_MIN_INTERVAL
    last=$(_hcnt "$uuid" lastrun); now=$(date +%s)
    [ $(( now - last )) -lt "$iv" ] && return 0
    _hcntset "$uuid" lastrun "$now"

    # Startup grace: skip failure escalation shortly after VM start.
    local grace started; grace=$(config_vm_get "$uuid" startup_grace 120)
    case "$grace" in ''|*[!0-9]*) grace=120 ;; esac
    started=$(cat "${VMS_STATE_DIR}/started.${uuid}" 2>/dev/null || echo 0)
    local in_grace=0
    [ "$started" -gt 0 ] && [ $(( now - started )) -lt "$grace" ] && in_grace=1

    hc_run "$uuid"; local rc=$?
    [ "$rc" = "2" ] && return 0   # disabled mid-flight

    local fail_th rec_th; fail_th=$(config_vm_get "$uuid" health_fail_threshold 3)
    rec_th=$(config_vm_get "$uuid" health_recover_threshold 2)
    case "$fail_th" in ''|*[!0-9]*) fail_th=3 ;; esac
    case "$rec_th" in ''|*[!0-9]*) rec_th=2 ;; esac

    local cur; cur=$(_hstate "$uuid")
    local name; name=$(uuidmap_name "$uuid" 2>/dev/null || echo "$uuid")

    if [ "$rc" = "0" ]; then
        # success
        _hcntset "$uuid" fails 0
        case "$cur" in
            Unhealthy|PendingRecovery)
                local s=$(( $(_hcnt "$uuid" succ) + 1 )); _hcntset "$uuid" succ "$s"
                _hset "$uuid" "PendingRecovery"
                if [ "$s" -ge "$rec_th" ]; then
                    _hset "$uuid" "Recovered"; _hcntset "$uuid" succ 0
                    hc_emit "$uuid" "$name" health_recover info \
                        "$name health check recovered" \
                        "The $(config_vm_get "$uuid" health_type '') check for $name is passing again."
                    _hset "$uuid" "Healthy"
                fi ;;
            *) _hset "$uuid" "Healthy"; _hcntset "$uuid" succ 0 ;;
        esac
    else
        # failure
        _hcntset "$uuid" succ 0
        if [ "$in_grace" = "1" ]; then
            vms_log_debug health "$uuid in startup grace; not escalating failure"
            return 0
        fi
        local ftype target port desc
        ftype=$(config_vm_get "$uuid" health_type '')
        target=$(config_vm_get "$uuid" health_target '')
        port=$(config_vm_get "$uuid" health_port '')
        case "$cur" in
            Unhealthy|Recovered) : ;;   # already unhealthy; stay (no repeat spam)
            *)
                local fcount=$(( $(_hcnt "$uuid" fails) + 1 )); _hcntset "$uuid" fails "$fcount"
                _hset "$uuid" "PendingFailure"
                if [ "$fcount" -ge "$fail_th" ]; then
                    _hset "$uuid" "Unhealthy"
                    case "$ftype" in
                        tcp)  desc="The $name health check failed ${fcount} consecutive times on TCP port ${port}." ;;
                        icmp) desc="The $name health check failed ${fcount} consecutive pings to ${target}." ;;
                        *)    desc="The $name health check failed ${fcount} consecutive times." ;;
                    esac
                    hc_emit "$uuid" "$name" health_fail warning \
                        "$name health check failing" "$desc"
                fi ;;
        esac
    fi
    return 0
}

hc_all() {
    vms_mkrundirs || return 0
    vms_lock_acquire health 0 || return 0
    inv_refresh_uuidmap
    local uuid
    while IFS= read -r uuid; do
        [ -n "$uuid" ] || continue
        if vms_lock_acquire "health.${uuid}" 0; then
            hc_step "$uuid"
            vms_lock_release "health.${uuid}"
        fi
    done < <(config_list_uuids)
    vms_lock_release health
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-once}" in
        once) hc_all ;;
        loop) while :; do hc_all; sleep 15; done ;;
        *) echo "usage: $0 {once|loop}" >&2; exit 2 ;;
    esac
fi
