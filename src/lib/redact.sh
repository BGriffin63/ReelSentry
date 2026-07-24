#!/usr/bin/env bash
# ReelSentry — secret redaction for logs, diagnostics, and exports (spec §26).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`.
#
# Rule: never reveal enough of a token to aid reconstruction. For Discord we show
# the id (not secret) and the FIRST FEW chars only, then REDACTED.

# redact_discord_webhook: turn a full webhook URL into a safe display form.
#   https://discord.com/api/webhooks/123456789/AbCdEf-verylongtoken
#     -> https://discord.com/api/webhooks/123456789/AbC…/REDACTED
redact_discord_webhook() {
    local u=$1
    if [[ $u =~ ^(https://[^/]+/api/webhooks/[0-9]+)/([A-Za-z0-9_-]+) ]]; then
        local base=${BASH_REMATCH[1]} tok=${BASH_REMATCH[2]}
        printf '%s/%s…/REDACTED' "$base" "${tok:0:3}"
    else
        printf '[redacted-webhook]'
    fi
}

# redact_stream: filter arbitrary text (stdin) removing secrets. Used by the
# diagnostics bundle and any log path. Redacts:
#   - Discord webhook URLs (any host)
#   - Authorization / bearer headers
#   - anything that looks like a long opaque token after common secret keys
redact_stream() {
    # Order matters: strip "Bearer <tok>" before the broader Authorization rule,
    # and redact an Authorization header value through end-of-line.
    sed -E \
        -e 's#(https?://[^/[:space:]]*/api/webhooks/[0-9]+)/[A-Za-z0-9_-]+#\1/REDACTED#g' \
        -e 's#(discord(app)?\.com/api/webhooks/[0-9]+)/[A-Za-z0-9_-]+#\1/REDACTED#g' \
        -e 's#([Bb]earer[[:space:]]+)[A-Za-z0-9._-]+#\1REDACTED#g' \
        -e 's#([Aa]uthorization:[[:space:]]*).*$#\1REDACTED#g' \
        -e 's#("?(webhook_url|token|password|secret|api_key|apikey|auth)"?[[:space:]]*[:=][[:space:]]*"?)[^"[:space:],}]+#\1REDACTED#gI'
}

# redact_text: convenience wrapper for a single string argument.
redact_text() { printf '%s' "$1" | redact_stream; }
