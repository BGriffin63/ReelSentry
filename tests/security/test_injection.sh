#!/usr/bin/env bash
# Security: malicious VM names must never execute, break JSON, or traverse paths
# (spec §18, §27). Drives the REAL hook + processor scripts end to end.
. "$(dirname "$0")/../lib/testlib.sh"
vms_test_env
trap vms_test_cleanup EXIT
export VMS_LIBDIR="$REPO_ROOT/src/lib"
export VMS_NOTIFYDIR="$REPO_ROOT/src/notifications"
export VMS_VIRSH="/nonexistent-virsh"   # force graceful degradation
export VMS_NOTIFY_BIN="/nonexistent-notify"

# Config: monitoring on, notifications effectively off (no providers reachable).
mkdir -p "$VMS_CONFIG_DIR"
printf 'G\tschema\t1\nG\tmonitoring_enabled\t1\nG\tnative_enabled\t0\nG\tdiscord_enabled\t0\n' > "$VMS_CONFIG_SNAPSHOT"

CANARY="$VMS_ROOT_TMP/PWNED"

malicious=(
  '$(touch '"$CANARY"')'
  '`touch '"$CANARY"'`'
  '; touch '"$CANARY"'; #'
  '&& touch '"$CANARY"''
  '| touch '"$CANARY"''
  'name"with"quotes'
  "name'with'apostrophes"
  '<script>alert(1)</script>'
  '../../../../etc/passwd'
  $'name\nwith\nnewlines'
  'name{with}json:chars,"nested"'
  "$(printf 'A%.0s' {1..400})"
)

for name in "${malicious[@]}"; do
    bash "$REPO_ROOT/src/hooks/vm-sentinel-hook" "$name" stopped end - >/dev/null 2>&1
done
# Hook must always succeed (fail-open)
assert_eq "hook exit 0 on last" "$?" "0"

# No command executed by hook
assert_false "canary absent after hooks" "[ -e '$CANARY' ]"

# Drain via the real processor
bash "$REPO_ROOT/src/services/processor.sh" drain >/dev/null 2>&1
assert_false "canary absent after processing" "[ -e '$CANARY' ]"

# Every history line must be valid single-line JSON
hf=$(. "$VMS_LIBDIR/common.sh"; . "$VMS_LIBDIR/config.sh"; . "$VMS_LIBDIR/history.sh"; history_path)
lines=$(wc -l < "$hf" 2>/dev/null || echo 0)
assert_true "history has records" "[ ${lines:-0} -ge 1 ]"

badjson=0
while IFS= read -r line; do
    # Each line must start with { and end with } and contain no raw newline (it can't, it's one line)
    case "$line" in
        '{'*'}') : ;;
        *) badjson=1 ;;
    esac
done < "$hf"
assert_eq "all history lines look like JSON objects" "$badjson" "0"

# Validate JSON strictly with python if available
if command -v python3 >/dev/null 2>&1; then
    if python3 - "$hf" <<'PY'
import json,sys
bad=0
for i,l in enumerate(open(sys.argv[1],encoding='utf-8')):
    l=l.strip()
    if not l: continue
    try: json.loads(l)
    except Exception as e:
        bad+=1; print("bad json line",i,e)
sys.exit(1 if bad else 0)
PY
    then ok "python json.loads accepts every history line"
    else notok "python json.loads accepts every history line"; fi
fi

# No secret ever appears (there is none configured, but assert the marker anyway)
assert_not_contains "no webhook in history" "$(cat "$hf")" "api/webhooks"

vms_test_summary
