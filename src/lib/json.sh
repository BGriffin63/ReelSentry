#!/usr/bin/env bash
# VM Sentinel — safe JSON construction without jq.
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`.
#
# We build JSON by hand precisely so that untrusted VM names, hostnames, and
# details can never break out of a JSON string context (spec §11, §18).

# json_escape_string: emit a *quoted* JSON string for arbitrary input.
# Handles the seven mandatory escapes plus all control chars < 0x20 as \u00XX.
json_escape_string() {
    local s=$1 out='' i c ord
    local n=${#s}
    for (( i=0; i<n; i++ )); do
        c=${s:i:1}
        case "$c" in
            '"')  out+='\"' ;;
            '\')  out+='\\' ;;
            $'\b') out+='\b' ;;
            $'\f') out+='\f' ;;
            $'\n') out+='\n' ;;
            $'\r') out+='\r' ;;
            $'\t') out+='\t' ;;
            '/')   out+='\/' ;;   # optional but safest inside <script>/HTML
            *)
                # Control characters (0x00-0x1F) -> \u00XX ; others pass through.
                printf -v ord '%d' "'$c" 2>/dev/null || ord=32
                if [ "$ord" -lt 32 ]; then
                    out+=$(printf '\\u%04x' "$ord")
                else
                    out+=$c
                fi
                ;;
        esac
    done
    printf '"%s"' "$out"
}

# json_kv: print  "key":<value>  where value is already a valid JSON token.
json_kv() { printf '%s:%s' "$(json_escape_string "$1")" "$2"; }

# json_kv_str: print  "key":"escaped-string"
json_kv_str() { printf '%s:%s' "$(json_escape_string "$1")" "$(json_escape_string "$2")"; }

# json_bool / json_num: coerce to safe literals.
json_bool() { case "$1" in 1|true|TRUE|yes|on) echo true ;; *) echo false ;; esac; }
json_num()  { case "$1" in ''|*[!0-9-]* ) echo 0 ;; *) printf '%s' "$1" ;; esac; }
