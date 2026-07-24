#!/usr/bin/env bash
# ReelSentry — native Unraid notification provider (spec §10).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`. Depends on provider.sh, classify.sh.
#
# Uses Unraid's built-in `notify` CLI. Every argument is passed as a separate,
# fully-quoted argv element — untrusted VM names are NEVER interpolated into a
# shell string, so command injection is impossible here (spec §18).

: "${VMS_NOTIFY_BIN:=/usr/local/emhttp/webGui/scripts/notify}"

# Map our severity to Unraid importance tokens.
# [VERIFY] exact accepted tokens on Unraid 7.2 (see RESEARCH.md §2).
_native_importance() {
    case "$1" in
        critical) echo "alert" ;;
        warning)  echo "warning" ;;
        *)        echo "normal" ;;
    esac
}

# provider_native_send: emit via the Unraid notify CLI.
provider_native_send() {
    if [ ! -x "$VMS_NOTIFY_BIN" ]; then
        notify_result 1 0 "native notify CLI not found"
        return 0
    fi
    local importance subject description link
    importance=$(_native_importance "${EV_SEVERITY:-info}")
    subject="${VMS_NAME}: ${EV_SUMMARY:-VM event}"
    description="${EV_DETAILS:-}"
    [ -z "$description" ] && description="$EV_SUMMARY"
    # Link back to the plugin page if the WebGUI base is known.
    link="/Settings/reelsentry"

    # Bounded execution; the notify CLI is local and fast, but guard anyway.
    if timeout 10 "$VMS_NOTIFY_BIN" \
        -e "ReelSentry" \
        -s "$subject" \
        -d "$description" \
        -i "$importance" \
        -l "$link" >/dev/null 2>&1; then
        notify_result 0 0 "native ok"
    else
        notify_result 1 0 "native notify failed"
    fi
    return 0
}
