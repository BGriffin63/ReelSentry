#!/usr/bin/env bash
# ReelSentry — bounded structured logging (spec §26).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`. Depends on common.sh, redact.sh.
#
# Levels: error, warning, info, debug (debug OFF by default).
# Categories: lifecycle, health, notify, config, queue, service, security.
# Every line is redacted before it hits disk — secrets can never be logged.

vms_log_rotate_if_needed() {
    [ -f "$VMS_LOG_FILE" ] || return 0
    local sz
    sz=$(wc -c < "$VMS_LOG_FILE" 2>/dev/null || echo 0)
    [ "${sz:-0}" -lt "$VMS_LOG_MAX_BYTES" ] && return 0
    local i
    for (( i=VMS_LOG_KEEP; i>=1; i-- )); do
        [ -f "${VMS_LOG_FILE}.$((i-1))" ] && mv -f "${VMS_LOG_FILE}.$((i-1))" "${VMS_LOG_FILE}.$i" 2>/dev/null
    done
    mv -f "$VMS_LOG_FILE" "${VMS_LOG_FILE}.1" 2>/dev/null || :
    : > "$VMS_LOG_FILE" 2>/dev/null || :
}

# vms_log <level> <category> <message...>
vms_log() {
    local level=$1 category=$2; shift 2
    local msg="$*"
    # Suppress debug unless enabled.
    if [ "$level" = "debug" ] && [ "${VMS_DEBUG}" != "1" ]; then return 0; fi
    mkdir -p "$VMS_LOG_DIR" 2>/dev/null || return 0
    vms_log_rotate_if_needed
    local line
    line="$(vms_now_iso) [$level] [$category] $msg"
    # Redaction is mandatory and belt-and-suspenders even though callers should
    # never pass secrets.
    printf '%s\n' "$line" | redact_stream >> "$VMS_LOG_FILE" 2>/dev/null || :
}

vms_log_error()   { vms_log error   "$@"; }
vms_log_warning() { vms_log warning "$@"; }
vms_log_info()    { vms_log info    "$@"; }
vms_log_debug()   { vms_log debug   "$@"; }
