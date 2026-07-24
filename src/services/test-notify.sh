#!/usr/bin/env bash
# VM Sentinel — send a test notification through a provider (spec §10, §11).
# SPDX-License-Identifier: MIT
# Invoked by the WebGUI "Send test notification" buttons via a CSRF-guarded POST.
#
# Usage: test-notify.sh {native|discord|all}
# Prints a single JSON result line; NEVER prints the webhook URL.

set -u
VMS_LIBDIR="${VMS_LIBDIR:-/usr/local/emhttp/plugins/vm.sentinel/lib}"
VMS_NOTIFYDIR="${VMS_NOTIFYDIR:-/usr/local/emhttp/plugins/vm.sentinel/notifications}"
# shellcheck source=/dev/null
for f in common validate json redact log config queue inventory classify; do . "${VMS_LIBDIR}/${f}.sh" || exit 1; done
# shellcheck source=/dev/null
for f in provider native discord dispatch; do . "${VMS_NOTIFYDIR}/${f}.sh" || exit 1; done

target=${1:-all}
server=$(vms_server_name); ts=$(vms_now_iso); eid="test_$(vms_epoch_ns)"

export EV_EVENT_ID=$eid EV_SERVER=$server EV_VM_UUID="00000000-0000-0000-0000-000000000000" \
       EV_VM_NAME="Test VM" EV_EVENT_TYPE="test" EV_SEVERITY="info" \
       EV_CLASSIFICATION="expected" EV_TIMESTAMP="$ts" EV_PREVIOUS_STATE="n/a" \
       EV_CURRENT_STATE="n/a" EV_HEALTH_STATE="n/a" \
       EV_SUMMARY="Test notification from VM Sentinel" \
       EV_DETAILS="If you can read this, notifications are working."

run_one() {
    local p=$1 line ok code
    notify_provider_registered "$p" || { printf '{"provider":"%s","ok":false,"error":"not-registered"}' "$p"; return; }
    line=$("provider_${p}_send" 2>/dev/null)
    ok=$(printf '%s' "$line" | sed -n 's/.*ok=\([0-9]\).*/\1/p'); ok=${ok:-1}
    code=$(printf '%s' "$line" | sed -n 's/.*code=\([0-9]\+\).*/\1/p'); code=${code:-0}
    local okb=false; [ "$ok" = "0" ] && okb=true
    printf '{"provider":"%s","ok":%s,"code":%s}' "$p" "$okb" "$code"
}

case "$target" in
    native)  printf '{"results":[%s]}\n' "$(run_one native)" ;;
    discord) printf '{"results":[%s]}\n' "$(run_one discord)" ;;
    all)     printf '{"results":[%s,%s]}\n' "$(run_one native)" "$(run_one discord)" ;;
    *) echo '{"error":"unknown target"}'; exit 2 ;;
esac
