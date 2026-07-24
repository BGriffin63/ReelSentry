#!/usr/bin/env bash
# Unit: history append, count bound, retention (spec §15, §27).
. "$(dirname "$0")/../lib/testlib.sh"
vms_test_env
vms_load common json validate redact log config history
trap vms_test_cleanup EXIT

printf 'G\thistory_max_events\t5\nG\thistory_retention_days\t3650\n' > "$VMS_CONFIG_SNAPSHOT"

for i in $(seq 1 12); do
    history_append "{\"n\":$i,\"timestamp\":\"$(vms_now_iso)\"}"
done
assert_eq "count bounded to max" "$(history_count)" "5"

# Newest kept
f=$(history_path)
assert_contains "keeps newest" "$(tail -n1 "$f")" '"n":12'

# Clear
history_clear
assert_eq "cleared" "$(history_count)" "0"

# Redaction guard: even if a secret sneaks in, it must not persist
history_append '{"leak":"https://discord.com/api/webhooks/123/SeCrEtToKeN","timestamp":"2026-01-01T00:00:00+00:00"}'
assert_not_contains "history redacts secret" "$(cat "$(history_path)")" "SeCrEtToKeN"

# Fallback path used when appdata dir unwritable
export VMS_HISTORY_DIR="/root/definitely-not-writable-$$/x"
d=$(history_dir)
assert_eq "falls back" "$d" "$VMS_HISTORY_FALLBACK_DIR"

vms_test_summary
