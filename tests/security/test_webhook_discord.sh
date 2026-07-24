#!/usr/bin/env bash
# Security: Discord payload building + webhook handling (spec §11, §18, §27).
. "$(dirname "$0")/../lib/testlib.sh"
vms_test_env
trap vms_test_cleanup EXIT
vms_load common json validate redact log config queue inventory classify
vms_load_notify provider native discord dispatch

# Build a payload with a hostile VM name and ensure it is valid JSON with no breakout.
export EV_EVENT_ID=e1 EV_SERVER=TOWER EV_VM_UUID=00000000-0000-0000-0000-000000000000 \
       EV_VM_NAME='Evil "}]}<script>${jndi}' EV_EVENT_TYPE=crashed EV_SEVERITY=critical \
       EV_CLASSIFICATION=unexpected EV_TIMESTAMP=2026-07-23T20:42:13-05:00 \
       EV_PREVIOUS_STATE=running EV_CURRENT_STATE=stopped EV_HEALTH_STATE=n/a \
       EV_SUMMARY='Evil "}]}crashed' EV_DETAILS='line1
line2 "quoted"'
printf 'G\tdiscord_username\tReelSentry\n' > "$VMS_CONFIG_SNAPSHOT"

payload=$(discord_build_payload)
assert_contains "payload has embeds" "$payload" '"embeds"'
if command -v python3 >/dev/null 2>&1; then
    if printf '%s' "$payload" | python3 -c 'import json,sys; json.load(sys.stdin)'; then
        ok "discord payload is valid JSON despite hostile input"
    else
        notok "discord payload is valid JSON despite hostile input"
    fi
fi
# Safety is proven by valid JSON parse above; additionally verify the hostile
# double-quote is backslash-escaped (so it cannot terminate the JSON string).
assert_contains "hostile quote is escaped" "$payload" '\"}]}<script>'

# Stored webhook read + validation
printf '{"discord_webhook":"https://discord.com/api/webhooks/123/GoodToken_-abc"}' > "$VMS_SECRETS_FILE"
chmod 600 "$VMS_SECRETS_FILE"
url=$(discord_read_webhook)
assert_true "valid stored webhook" "valid_discord_webhook '$url'"

# A non-Discord/HTTP webhook must be rejected by the provider (no send attempted)
printf '{"discord_webhook":"http://evil.example/api/webhooks/1/x"}' > "$VMS_SECRETS_FILE"
printf 'G\tdiscord_enabled\t1\n' >> "$VMS_CONFIG_SNAPSHOT"
res=$(provider_discord_send)
assert_contains "invalid webhook rejected" "$res" "invalid"

vms_test_summary
