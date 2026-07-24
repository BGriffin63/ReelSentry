#!/usr/bin/env bash
# Unit: event normalization, state, severity, classification (spec §5, §7, §27).
. "$(dirname "$0")/../lib/testlib.sh"
vms_load common normalize classify

assert_eq "start -> starting"        "$(normalize_event start begin)"     "starting"
assert_eq "started -> started"       "$(normalize_event started begin)"   "started"
assert_eq "stopped/end -> stopped"   "$(normalize_event stopped end)"     "stopped"
assert_eq "stopped/begin -> stopping" "$(normalize_event stopped begin)"  "stopping"
assert_eq "shutdown -> shutdown"     "$(normalize_event shutdown end)"    "shutdown"
assert_eq "crashed -> crashed"       "$(normalize_event crashed -)"       "crashed"
assert_eq "reboot -> rebooted"       "$(normalize_event reboot -)"        "rebooted"
assert_eq "suspend -> suspended"     "$(normalize_event suspend -)"       "suspended"
assert_eq "unknown op -> unknown"    "$(normalize_event frobnicate -)"    "unknown"

assert_eq "state of started"  "$(state_for_event started)"  "running"
assert_eq "state of stopped"  "$(state_for_event stopped)"  "stopped"
assert_eq "state of paused"   "$(state_for_event paused)"   "paused"

# Classification honesty (spec §7)
assert_eq "crash unexpected"      "$(classify_event crashed - 0)"    "unexpected"
assert_eq "bare stop indeterminate" "$(classify_event stopped end 0)" "indeterminate"
assert_eq "graceful shutdown expected" "$(classify_event shutdown end 0)" "expected"
assert_eq "stop during maintenance expected" "$(classify_event stopped end 1)" "expected"
assert_eq "start expected"        "$(classify_event started begin 0)" "expected"

# Severity mapping
assert_eq "crash critical" "$(severity_for_event crashed unexpected)" "critical"
assert_eq "indeterminate stop warning" "$(severity_for_event stopped indeterminate)" "warning"
assert_eq "start info" "$(severity_for_event started expected)" "info"

# Summary wording never over-claims
assert_eq "indeterminate wording" \
  "$(summary_for_event 'Game PC' stopped indeterminate)" \
  "Game PC stopped; the reason could not be determined"
assert_contains "crash wording" "$(summary_for_event 'Game PC' crashed unexpected)" "crashed"
assert_contains "maintenance detail" "$(details_for_event stopped expected 1)" "Unraid or VM Manager restart"

# Notifiable key mapping
assert_eq "crash key" "$(event_is_notifiable_key crashed)" "notify_crash"
assert_eq "starting not notifiable" "$(event_is_notifiable_key starting)" ""

vms_test_summary
