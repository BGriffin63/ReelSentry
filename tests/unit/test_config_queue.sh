#!/usr/bin/env bash
# Unit: config snapshot, dedup, cooldown, quiet hours, suppression (spec §8,§16,§17).
. "$(dirname "$0")/../lib/testlib.sh"
vms_test_env
vms_load common json validate redact log config queue
trap vms_test_cleanup EXIT

# Hand-author a snapshot fixture (as the PHP GUI would generate).
uuid="12345678-1234-1234-1234-123456789abc"
{
  printf 'G\tschema\t1\n'
  printf 'G\tmonitoring_enabled\t1\n'
  printf 'G\tnotify_stop\t1\n'
  printf 'G\tcooldown_seconds\t0\n'
  printf 'V\t%s\tnotify_crash\t0\n' "$uuid"
  printf 'V\t%s\tenabled\t1\n' "$uuid"
  printf 'N\t%s\tGame PC\n' "$uuid"
} > "$VMS_CONFIG_SNAPSHOT"

assert_eq "global get"        "$(config_get monitoring_enabled 0)" "1"
assert_eq "global default"    "$(config_get nonexistent 7)" "7"
assert_eq "vm override"       "$(config_vm_get "$uuid" notify_crash 1)" "0"
assert_eq "vm falls to global" "$(config_vm_get "$uuid" notify_stop 0)" "1"
assert_eq "vm name"           "$(config_vm_name "$uuid")" "Game PC"
assert_true "vm enabled"      "config_vm_enabled $uuid"

# Atomic write keeps a .bak
mkdir -p "$VMS_CONFIG_DIR"
printf 'v1' | config_atomic_write "$VMS_CONFIG_DIR/x.json"
printf 'v2' | config_atomic_write "$VMS_CONFIG_DIR/x.json"
assert_eq "atomic current" "$(cat "$VMS_CONFIG_DIR/x.json")" "v2"
assert_eq "atomic backup"  "$(cat "$VMS_CONFIG_DIR/x.json.bak")" "v1"

# Dedup within window
vms_mkrundirs
assert_true  "first emit"  "dedup_should_emit $uuid stopped"
assert_false "dup suppressed" "dedup_should_emit $uuid stopped"

# Cooldown: with cooldown 0 always ok; set 3600 and prove blocked
assert_true "cooldown zero ok" "cooldown_ok $uuid started"
printf 'V\t%s\tcooldown_seconds\t3600\n' "$uuid" >> "$VMS_CONFIG_SNAPSHOT"
assert_true  "cooldown first"  "cooldown_ok $uuid rebooted"
assert_false "cooldown blocks" "cooldown_ok $uuid rebooted"

# Quiet hours: construct a window covering 'now'
now_h=$(date +%H)
printf 'G\tquiet_enabled\t1\n' >> "$VMS_CONFIG_SNAPSHOT"
printf 'G\tquiet_start\t00:00\n' >> "$VMS_CONFIG_SNAPSHOT"
printf 'G\tquiet_end\t23:59\n' >> "$VMS_CONFIG_SNAPSHOT"
printf 'G\tquiet_days\t0,1,2,3,4,5,6\n' >> "$VMS_CONFIG_SNAPSHOT"
assert_true "quiet active now" "quiet_hours_active"
assert_false "quiet blocks info" "quiet_allows started info"
assert_true  "quiet bypass critical" "quiet_allows crashed critical"

# Suppression
suppression_active "$uuid" && r=1 || r=0
assert_eq "no suppression initially" "$r" "0"
printf '%s' "$(( $(date +%s) + 600 ))" > "$VMS_STATE_DIR/suppress.all"
assert_true "suppression all active" "suppression_active $uuid"

vms_test_summary
