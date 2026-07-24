#!/usr/bin/env bash
# Integration: hook -> spool -> processor -> history + notification dispatch,
# plus corrupt-record handling, missing args, and fail-open guarantees (spec §27).
. "$(dirname "$0")/../lib/testlib.sh"
vms_test_env
trap vms_test_cleanup EXIT
export VMS_LIBDIR="$REPO_ROOT/src/lib"
export VMS_NOTIFYDIR="$REPO_ROOT/src/notifications"
export VMS_VIRSH="/nonexistent-virsh"

# Mock the native Unraid notify CLI so we can observe dispatch without a real host.
NOTIFY_LOG="$VMS_ROOT_TMP/notify.log"
cat > "$VMS_ROOT_TMP/notify" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$NOTIFY_LOG"
exit 0
EOF
chmod +x "$VMS_ROOT_TMP/notify"
export VMS_NOTIFY_BIN="$VMS_ROOT_TMP/notify"

# Config: monitoring on, native on, discord off, crash notifications on.
{
  printf 'G\tschema\t1\nG\tmonitoring_enabled\t1\nG\tnative_enabled\t1\nG\tdiscord_enabled\t0\n'
  printf 'G\tnotify_crash\t1\nG\tnotify_stop\t1\n'
} > "$VMS_CONFIG_SNAPSHOT"

# 1) Hook writes a spool record quickly and exits 0.
t0=$(date +%s%N)
bash "$REPO_ROOT/src/hooks/reelsentry-hook" "Game PC" crashed - -
rc=$?
t1=$(date +%s%N)
assert_eq "hook exit 0" "$rc" "0"
ms=$(( (t1 - t0) / 1000000 ))
assert_true "hook returns fast (<1500ms)" "[ $ms -lt 1500 ]"
assert_eq "one spool file" "$(find "$VMS_SPOOL_DIR" -maxdepth 1 -name '*.ev' | wc -l | tr -d ' ')" "1"

# 2) 'prepare'/'reconnect' phases are ignored (no spool churn).
bash "$REPO_ROOT/src/hooks/reelsentry-hook" "Game PC" prepare begin - >/dev/null 2>&1
assert_eq "prepare ignored" "$(find "$VMS_SPOOL_DIR" -maxdepth 1 -name '*.ev' | wc -l | tr -d ' ')" "1"

# 3) Missing args must not crash the hook.
bash "$REPO_ROOT/src/hooks/reelsentry-hook" >/dev/null 2>&1
assert_eq "hook no-args exit 0" "$?" "0"

# 4) Corrupt spool record is quarantined, not fatal.
printf 'garbage-not-a-record\n' > "$VMS_SPOOL_DIR/999.bad.ev"

# 5) Drain and verify.
bash "$REPO_ROOT/src/services/processor.sh" drain
hf=$(. "$VMS_LIBDIR/common.sh"; . "$VMS_LIBDIR/config.sh"; . "$VMS_LIBDIR/history.sh"; history_path)

assert_true "history has crash event" "grep -q '\"event_type\":\"crashed\"' '$hf'"
assert_true "crash classified unexpected" "grep -q '\"classification\":\"unexpected\"' '$hf'"
assert_true "native notify invoked" "[ -s '$NOTIFY_LOG' ]"
assert_true "notify subject mentions crash" "grep -qi 'crashed' '$NOTIFY_LOG'"
assert_true "corrupt record quarantined" "[ -e '$VMS_SPOOL_BAD_DIR' ] && ls '$VMS_SPOOL_BAD_DIR' | grep -q ."
assert_eq "spool drained" "$(find "$VMS_SPOOL_DIR" -maxdepth 1 -name '*.ev' | wc -l | tr -d ' ')" "0"

# 6) Fail-open: a broken notify binary must not stop history recording.
: > "$NOTIFY_LOG"
cat > "$VMS_NOTIFY_BIN" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
chmod +x "$VMS_NOTIFY_BIN"
bash "$REPO_ROOT/src/hooks/reelsentry-hook" "Game PC" stopped end - >/dev/null 2>&1
bash "$REPO_ROOT/src/services/processor.sh" drain
assert_true "history recorded despite notify failure" "grep -q '\"event_type\":\"stopped\"' '$hf'"

# 7) Single-flight: simulate a live lock holder and confirm a second drain no-ops.
mkdir -p "$VMS_LOCK_DIR/processor.lockd"
sleep 30 & holder=$!; echo "$holder" > "$VMS_LOCK_DIR/processor.lockd/pid"
bash "$REPO_ROOT/src/hooks/reelsentry-hook" "Game PC" started begin - >/dev/null 2>&1
before=$(find "$VMS_SPOOL_DIR" -maxdepth 1 -name '*.ev' | wc -l | tr -d ' ')
bash "$REPO_ROOT/src/services/processor.sh" drain   # must not acquire the held lock
after=$(find "$VMS_SPOOL_DIR" -maxdepth 1 -name '*.ev' | wc -l | tr -d ' ')
kill "$holder" 2>/dev/null; rm -rf "$VMS_LOCK_DIR/processor.lockd"
assert_eq "single-flight lock prevents concurrent drain" "$before" "$after"

vms_test_summary
