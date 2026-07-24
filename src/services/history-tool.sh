#!/usr/bin/env bash
# VM Sentinel — history utilities for the WebGUI (spec §13.4).
# SPDX-License-Identifier: MIT
# Usage:
#   history-tool.sh clear
#   history-tool.sh tail <n>         # last n JSONL lines (already secret-free)
#   history-tool.sh export-csv       # sanitized CSV to stdout
set -u
VMS_LIBDIR="${VMS_LIBDIR:-/usr/local/emhttp/plugins/vm.sentinel/lib}"
# shellcheck source=/dev/null
for f in common validate json redact log config history; do . "${VMS_LIBDIR}/${f}.sh" || exit 1; done

cmd=${1:-tail}
case "$cmd" in
    clear) history_clear && echo ok ;;
    tail)
        n=${2:-200}; case "$n" in ''|*[!0-9]*) n=200 ;; esac
        f=$(history_path 2>/dev/null) || exit 0
        [ -f "$f" ] && tail -n "$n" "$f" | redact_stream || true
        ;;
    export-csv)
        f=$(history_path 2>/dev/null) || exit 0
        echo "timestamp,server,vm_name,event_type,classification,previous_state,current_state,severity,notify_attempted"
        [ -f "$f" ] || exit 0
        # Extract fields with a strict per-line parser; redaction applied first.
        redact_stream < "$f" | while IFS= read -r line; do
            get(){ printf '%s' "$line" | sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p"; }
            getb(){ printf '%s' "$line" | sed -n "s/.*\"$1\":\(true\|false\).*/\1/p"; }
            csv(){ printf '"%s"' "$(printf '%s' "$1" | sed 's/"/""/g')"; }
            printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
                "$(csv "$(get timestamp)")" "$(csv "$(get server)")" \
                "$(csv "$(get vm_name)")" "$(csv "$(get event_type)")" \
                "$(csv "$(get classification)")" "$(csv "$(get previous_state)")" \
                "$(csv "$(get current_state)")" "$(csv "$(get severity)")" \
                "$(csv "$(getb notify_attempted)")"
        done
        ;;
    *) echo "usage: $0 {clear|tail <n>|export-csv}" >&2; exit 2 ;;
esac
