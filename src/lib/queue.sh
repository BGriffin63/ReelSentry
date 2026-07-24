#!/usr/bin/env bash
# ReelSentry — spool queue, dedup, cooldown, quiet-hours, suppression.
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`. Depends on common.sh, config.sh.
#
# Spool record is ONE line, fields tab-delimited, free-text fields base64'd so no
# untrusted byte can ever be mistaken for a delimiter or a shell token:
#   1<TAB><epoch_ns><TAB><op><TAB><sub><TAB><name_b64><TAB><extra_b64>

spool_encode() { printf '%s' "$1" | base64 2>/dev/null | tr -d '\n'; }
spool_decode() { printf '%s' "$1" | base64 -d 2>/dev/null; }

# spool_write <op> <sub> <name> <extra>   (called by the hook; must be fast+safe)
# Enforces the queue bound by dropping the OLDEST non-critical record first.
spool_write() {
    local op=$1 sub=$2 name=$3 extra=$4
    vms_mkrundirs || return 1
    spool_enforce_bound
    local ns rec tmp final
    ns=$(vms_epoch_ns)
    rec=$(printf '1\t%s\t%s\t%s\t%s\t%s' "$ns" "$op" "$sub" \
            "$(spool_encode "$name")" "$(spool_encode "$extra")")
    tmp="${VMS_SPOOL_DIR}/.tmp.${ns}.$(vms_rand_token)"
    final="${VMS_SPOOL_DIR}/${ns}.$(vms_rand_token).ev"
    printf '%s\n' "$rec" > "$tmp" 2>/dev/null || return 1
    mv -f "$tmp" "$final" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
    return 0
}

spool_count() { find "$VMS_SPOOL_DIR" -maxdepth 1 -type f -name '*.ev' 2>/dev/null | wc -l; }

# spool_enforce_bound: if over VMS_QUEUE_MAX, drop oldest NON-critical events.
# A record is "critical" if its op indicates a crash. Dropped count is recorded.
spool_enforce_bound() {
    local n; n=$(spool_count)
    [ "${n:-0}" -le "$VMS_QUEUE_MAX" ] && return 0
    local f op
    while IFS= read -r f; do
        n=$(spool_count); [ "${n:-0}" -le "$VMS_QUEUE_MAX" ] && break
        op=$(cut -f3 < "$f" 2>/dev/null)
        case "$op" in
            crashed|crash|panic|panicked) continue ;;  # preserve critical
        esac
        rm -f "$f" 2>/dev/null && spool_bump_dropped
    done < <(find "$VMS_SPOOL_DIR" -maxdepth 1 -type f -name '*.ev' 2>/dev/null | sort)
    return 0
}

spool_bump_dropped() {
    local f="${VMS_STATE_DIR}/dropped.count" c
    c=$(cat "$f" 2>/dev/null || echo 0); c=$((c+1))
    printf '%s' "$c" > "$f" 2>/dev/null || true
}
spool_dropped_count() { cat "${VMS_STATE_DIR}/dropped.count" 2>/dev/null || echo 0; }

# --- Deduplication (spec §17) -------------------------------------------------
# dedup_key <uuid> <event> -> stable key. Collapses identical lifecycle events
# arriving within VMS_DEDUP_WINDOW seconds.
dedup_key() { printf '%s:%s' "$1" "$2"; }

# dedup_should_emit <uuid> <event> -> 0 to emit, 1 to suppress as duplicate.
dedup_should_emit() {
    local key file now last
    key=$(dedup_key "$1" "$2")
    file="${VMS_STATE_DIR}/dedup.$(printf '%s' "$key" | tr -c 'A-Za-z0-9._-' '_')"
    now=$(date +%s)
    last=$(cat "$file" 2>/dev/null || echo 0)
    if [ $(( now - last )) -lt "$VMS_DEDUP_WINDOW" ]; then
        return 1
    fi
    printf '%s' "$now" > "$file" 2>/dev/null || true
    return 0
}

# --- Per-event cooldown (spec §8, §17) ----------------------------------------
# cooldown_ok <uuid> <event> -> 0 if allowed, 1 if still cooling down.
cooldown_ok() {
    local uuid=$1 ev=$2 cd now last file
    cd=$(config_vm_get "$uuid" cooldown_seconds "$(config_get cooldown_seconds 0)")
    case "$cd" in ''|*[!0-9]*) cd=0 ;; esac
    [ "$cd" -le 0 ] && return 0
    file="${VMS_STATE_DIR}/cooldown.${uuid}.${ev}"
    now=$(date +%s); last=$(cat "$file" 2>/dev/null || echo 0)
    if [ $(( now - last )) -lt "$cd" ]; then return 1; fi
    printf '%s' "$now" > "$file" 2>/dev/null || true
    return 0
}

# --- Quiet hours (spec §16) ---------------------------------------------------
# quiet_hours_active -> 0 if currently within a configured quiet window.
# Config keys: quiet_enabled, quiet_start (HH:MM), quiet_end (HH:MM),
#              quiet_days (csv 0-6, 0=Sun). Server local time.
quiet_hours_active() {
    [ "$(config_get quiet_enabled 0)" = "1" ] || return 1
    local start end days now_min dow s_min e_min
    start=$(config_get quiet_start 22:00)
    end=$(config_get quiet_end 07:00)
    days=$(config_get quiet_days 0,1,2,3,4,5,6)
    dow=$(date +%w)
    case ",$days," in *",$dow,"*) : ;; *) return 1 ;; esac
    now_min=$(( 10#$(date +%H) * 60 + 10#$(date +%M) ))
    s_min=$(( 10#${start%%:*} * 60 + 10#${start##*:} ))
    e_min=$(( 10#${end%%:*} * 60 + 10#${end##*:} ))
    if [ "$s_min" -le "$e_min" ]; then
        [ "$now_min" -ge "$s_min" ] && [ "$now_min" -lt "$e_min" ]
    else
        # window crosses midnight
        [ "$now_min" -ge "$s_min" ] || [ "$now_min" -lt "$e_min" ]
    fi
}

# quiet_allows <event> <severity> -> 0 if this event may pass despite quiet hours.
# Critical events optionally bypass (config: quiet_bypass_critical, default 1).
quiet_allows() {
    local ev=$1 sev=$2
    quiet_hours_active || return 0   # not quiet -> allowed
    if [ "$sev" = "critical" ] && [ "$(config_get quiet_bypass_critical 1)" = "1" ]; then
        return 0
    fi
    # events explicitly whitelisted during quiet hours
    case ",$(config_get quiet_allow_events '')," in
        *",$ev,"*) return 0 ;;
    esac
    return 1
}

# --- Maintenance suppression (spec §16) ---------------------------------------
# suppression_active <uuid> -> 0 if a suppression window covers this VM (or all).
suppression_active() {
    local uuid=$1 f now until
    now=$(date +%s)
    for f in "${VMS_STATE_DIR}/suppress.all" "${VMS_STATE_DIR}/suppress.${uuid}"; do
        [ -f "$f" ] || continue
        until=$(cat "$f" 2>/dev/null || echo 0)
        [ "$now" -lt "${until:-0}" ] && return 0
        # expired -> clean up
        rm -f "$f" 2>/dev/null || true
    done
    return 1
}
