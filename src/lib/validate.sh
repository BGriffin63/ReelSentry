#!/usr/bin/env bash
# ReelSentry — input validation. All external input is untrusted (spec §18).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`. Every function returns 0 (valid) / 1.

: "${VMS_MAX_NAME_LEN:=128}"

# valid_uuid: canonical 8-4-4-4-12 hex, case-insensitive.
valid_uuid() {
    local u=$1
    [[ $u =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

# valid_port: integer 1-65535, no leading zeros trickery.
valid_port() {
    local p=$1
    [[ $p =~ ^[0-9]{1,5}$ ]] || return 1
    (( p >= 1 && p <= 65535 ))
}

# valid_ipv4
valid_ipv4() {
    local ip=$1 o IFS=.
    [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1
    # shellcheck disable=SC2206
    local parts=($ip)
    for o in "${parts[@]}"; do (( o >= 0 && o <= 255 )) || return 1; done
    return 0
}

# valid_hostname: RFC-1123-ish label rules; also accepts a bare IPv4.
# Rejects anything with shell metacharacters, spaces, or scheme separators.
valid_hostname() {
    local h=$1
    [ ${#h} -ge 1 ] && [ ${#h} -le 253 ] || return 1
    if valid_ipv4 "$h"; then return 0; fi
    # Each label: alnum with internal hyphens, 1-63 chars; no leading/trailing hyphen.
    [[ $h =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$ ]]
}

# valid_interval: seconds, integer, clamped to a floor by caller.
valid_interval() { [[ $1 =~ ^[0-9]+$ ]]; }

# valid_threshold: 1..100 integer.
valid_threshold() { [[ $1 =~ ^[0-9]{1,3}$ ]] && (( $1 >= 1 && $1 <= 100 )); }

# valid_discord_webhook: must be HTTPS to a documented Discord webhook host,
# path must be /api/webhooks/<id>/<token>. No shell metacharacters permitted.
# Returns 0 if acceptable.
valid_discord_webhook() {
    local u=$1
    # Reject anything containing characters that could enable injection if the
    # URL were ever (incorrectly) interpolated. curl gets it as a single arg,
    # but defense in depth: allow only URL-legal characters.
    [[ $u =~ ^[A-Za-z0-9._~:/?#@!$\&\'\(\)\*\+,\;=%-]+$ ]] || return 1
    # Scheme must be https.
    [[ $u =~ ^https:// ]] || return 1
    # Host must be an approved Discord host (allow the documented set).
    local host
    host=${u#https://}
    host=${host%%/*}
    host=${host%%:*}
    case "$host" in
        discord.com|discordapp.com|ptb.discord.com|canary.discord.com) : ;;
        *) return 1 ;;
    esac
    # Path shape /api/webhooks/<digits>/<token>
    local path=${u#https://*/}
    [[ /$path =~ ^/api/webhooks/[0-9]+/[A-Za-z0-9_-]+([?].*)?$ ]]
}

# sanitize_vm_name: return a bounded, control-char-free display name.
# This does NOT make the name safe for shell/HTML/JSON on its own — those
# contexts have their own escapers. It only bounds length and strips NUL/newlines
# so the value stays a single spool field.
sanitize_vm_name() {
    local n=$1
    n=${n//$'\n'/ }
    n=${n//$'\r'/ }
    n=${n//$'\t'/ }
    n=${n//$'\0'/}
    # Bound length.
    if [ ${#n} -gt "$VMS_MAX_NAME_LEN" ]; then n=${n:0:$VMS_MAX_NAME_LEN}; fi
    printf '%s' "$n"
}

# valid_path_component: reject traversal/absolute/empty for a single path segment.
valid_path_component() {
    local c=$1
    [ -n "$c" ] || return 1
    case "$c" in
        *..*|*/*|.|"") return 1 ;;
    esac
    [[ $c =~ ^[A-Za-z0-9._-]+$ ]]
}
