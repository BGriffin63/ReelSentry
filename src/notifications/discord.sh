#!/usr/bin/env bash
# VM Sentinel — Discord incoming-webhook provider (spec §11). NO BOT.
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`. Depends on provider.sh, json.sh,
# validate.sh, redact.sh, common.sh.
#
# Security posture:
#   * Webhook URL read from the 0600 secrets file, validated as an HTTPS Discord
#     webhook, and NEVER logged, echoed, or placed in argv-visible form beyond
#     curl's single URL argument.
#   * JSON body built with json.sh escapers — VM names/details can't break out.
#   * Hard connect + total timeouts; bounded retries with backoff; 429 respected.
#   * A dead endpoint can never block the queue.

# Color per severity (also conveyed by emoji + a text Status field; not color-only).
_discord_color() {
    case "$1" in
        critical) echo 15158332 ;;  # red
        warning)  echo 15965202 ;;  # orange
        *)        echo 3066993  ;;  # green
    esac
}
_discord_emoji() {
    case "$1" in
        critical) printf '🔴' ;;
        warning)  printf '🟠' ;;
        *)        printf '🟢' ;;
    esac
}

# discord_read_webhook: print the stored webhook (stdout only). Caller must not log it.
discord_read_webhook() {
    [ -f "$VMS_SECRETS_FILE" ] || return 1
    # secrets.json is a tiny JSON: {"discord_webhook":"https://..."}
    # Extract without jq using a strict, anchored sed. Value is a JSON string.
    local raw
    raw=$(sed -n 's/.*"discord_webhook"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$VMS_SECRETS_FILE" 2>/dev/null | head -n1)
    [ -n "$raw" ] || return 1
    printf '%s' "$raw"
}

# discord_field: build one embed field object.  <name> <value> [inline]
_discord_field() {
    local name=$1 value=$2 inline=${3:-true}
    printf '{"name":%s,"value":%s,"inline":%s}' \
        "$(json_escape_string "$name")" \
        "$(json_escape_string "${value:-—}")" \
        "$inline"
}

# discord_build_payload: emit the JSON body for the current EV_* event.
discord_build_payload() {
    local color emoji title mention username avatar
    color=$(_discord_color "${EV_SEVERITY:-info}")
    emoji=$(_discord_emoji "${EV_SEVERITY:-info}")
    title="${emoji} VM Alert: ${EV_SUMMARY:-VM event}"
    username=$(config_get discord_username "VM Sentinel")
    avatar=$(config_get discord_avatar "")

    # Optional mention text (role/user), sanitized to digits + Discord mention chars.
    mention=""
    local mrole muser
    mrole=$(config_get discord_mention_role "")
    muser=$(config_get discord_mention_user "")
    [[ $mrole =~ ^[0-9]{1,25}$ ]] && mention="<@&${mrole}> "
    [[ $muser =~ ^[0-9]{1,25}$ ]] && mention="${mention}<@${muser}> "

    # Fields (spec §11).
    local fields
    fields=$(printf '%s,%s,%s,%s,%s,%s,%s' \
        "$(_discord_field "VM" "${EV_VM_NAME}")" \
        "$(_discord_field "Event" "${EV_EVENT_TYPE}")" \
        "$(_discord_field "Server" "${EV_SERVER}")" \
        "$(_discord_field "Previous state" "${EV_PREVIOUS_STATE}")" \
        "$(_discord_field "Current state" "${EV_CURRENT_STATE}")" \
        "$(_discord_field "Classification" "${EV_CLASSIFICATION}")" \
        "$(_discord_field "Health" "${EV_HEALTH_STATE:-n/a}")")

    local embed
    embed=$(printf '{"title":%s,"description":%s,"color":%s,"fields":[%s],"footer":{"text":%s},"timestamp":%s}' \
        "$(json_escape_string "$title")" \
        "$(json_escape_string "${EV_DETAILS:-$EV_SUMMARY}")" \
        "$color" \
        "$fields" \
        "$(json_escape_string "VM Sentinel • Monitor every VM")" \
        "$(json_escape_string "${EV_TIMESTAMP}")")

    # content carries the mention (embeds don't ping); allowed_parsed keeps it tight.
    local content_json='""'
    [ -n "$mention" ] && content_json=$(json_escape_string "$mention")

    local body="{\"content\":${content_json},\"embeds\":[${embed}]"
    [ -n "$username" ] && body="${body},\"username\":$(json_escape_string "$username")"
    [[ $avatar =~ ^https:// ]] && body="${body},\"avatar_url\":$(json_escape_string "$avatar")"
    body="${body}}"
    printf '%s' "$body"
}

# discord_post <url> <payload> -> prints "code=<http> ok=<0|1>"; bounded retries.
discord_post() {
    local url=$1 payload=$2 attempt=0 http code
    while :; do
        attempt=$((attempt+1))
        # -sS quiet; --max-time total cap; --connect-timeout connect cap.
        http=$(curl -sS -o /dev/null -w '%{http_code}' \
                --connect-timeout "$VMS_NET_CONNECT_TIMEOUT" \
                --max-time "$VMS_NET_TOTAL_TIMEOUT" \
                -H 'Content-Type: application/json' \
                -X POST --data-binary "$payload" \
                "$url" 2>/dev/null)
        code=${http:-0}
        case "$code" in
            2*) printf 'code=%s ok=1' "$code"; return 0 ;;
            429)
                # Respect rate limit; bounded backoff, still capped by retries.
                [ "$attempt" -gt "$VMS_HTTP_RETRIES" ] && { printf 'code=429 ok=0'; return 0; }
                sleep "$(( attempt * 2 ))"
                ;;
            5*|000)
                [ "$attempt" -gt "$VMS_HTTP_RETRIES" ] && { printf 'code=%s ok=0' "$code"; return 0; }
                sleep "$(( attempt ))"
                ;;
            *) printf 'code=%s ok=0' "$code"; return 0 ;;  # 4xx: don't retry
        esac
    done
}

# provider_discord_send: the provider entry point.
provider_discord_send() {
    [ "$(config_get discord_enabled 0)" = "1" ] || { notify_result 1 0 "discord disabled"; return 0; }
    local url
    url=$(discord_read_webhook) || { notify_result 1 0 "no discord webhook configured"; return 0; }
    if ! valid_discord_webhook "$url"; then
        notify_result 1 0 "stored discord webhook invalid"
        return 0
    fi
    local payload result code ok
    payload=$(discord_build_payload)
    result=$(discord_post "$url" "$payload")
    code=${result#code=}; code=${code%% *}
    ok=${result##*ok=}
    if [ "$ok" = "1" ]; then
        notify_result 0 "$code" "discord ok"
    else
        notify_result 1 "$code" "discord http $code"
    fi
    return 0
}
