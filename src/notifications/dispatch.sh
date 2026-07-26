#!/usr/bin/env bash
# ReelSentry — provider dispatcher (spec §12).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`. Depends on provider.sh, native.sh,
# discord.sh, json.sh, config.sh.
#
# notify_dispatch takes the normalized event as arguments, exports EV_* for the
# providers, invokes each ENABLED provider, and prints a JSON array of results:
#   [{"provider":"native","ok":true},{"provider":"discord","ok":false,"code":404}]

# notify_dispatch <event_id> <server> <uuid> <name> <event_type> <severity> \
#                 <classification> <timestamp> <prev> <cur> <health> <summary> <details>
notify_dispatch() {
    export EV_EVENT_ID=$1 EV_SERVER=$2 EV_VM_UUID=$3 EV_VM_NAME=$4 \
           EV_EVENT_TYPE=$5 EV_SEVERITY=$6 EV_CLASSIFICATION=$7 EV_TIMESTAMP=$8 \
           EV_PREVIOUS_STATE=$9 EV_CURRENT_STATE=${10} EV_HEALTH_STATE=${11} \
           EV_SUMMARY=${12} EV_DETAILS=${13}

    local results=() provider line ok code
    for provider in native discord; do
        # Global enable gates.
        case "$provider" in
            native)  [ "$(config_get native_enabled 1)" = "1" ] || continue ;;
            discord) discord_configured || continue ;;   # send if a valid webhook is set
        esac
        notify_provider_registered "$provider" || continue
        line=$("provider_${provider}_send" 2>/dev/null)
        ok=$(printf '%s' "$line" | sed -n 's/.*ok=\([0-9]\).*/\1/p'); ok=${ok:-1}
        code=$(printf '%s' "$line" | sed -n 's/.*code=\([0-9]\+\).*/\1/p'); code=${code:-0}
        local okbool=false; [ "$ok" = "0" ] && okbool=true
        results+=("$(printf '{"provider":%s,"ok":%s,"code":%s}' \
            "$(json_escape_string "$provider")" "$okbool" "$(json_num "$code")")")
    done

    local IFS=,
    printf '[%s]' "${results[*]-}"
}
