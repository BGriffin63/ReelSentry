#!/usr/bin/env bash
# ReelSentry — diagnostics + sanitized support bundle (spec §13.5, §18).
# SPDX-License-Identifier: MIT
# Usage:
#   diagnostics.sh status     # prints a JSON status object for the GUI
#   diagnostics.sh bundle     # writes a redacted .tar.gz, prints its path
set -u
VMS_LIBDIR="${VMS_LIBDIR:-/usr/local/emhttp/plugins/reelsentry/lib}"
VMS_PLUGIN_ROOT="${VMS_PLUGIN_ROOT:-/usr/local/emhttp/plugins/reelsentry}"
# shellcheck source=/dev/null
for f in common validate json redact log config queue history inventory; do . "${VMS_LIBDIR}/${f}.sh" || exit 1; done
# shellcheck source=/dev/null
. "${VMS_PLUGIN_ROOT}/hooks/install-hook.sh" >/dev/null 2>&1 || true

version() { cat "${VMS_PLUGIN_ROOT}/VERSION" 2>/dev/null || cat "${VMS_PLUGIN_ROOT}/../../../../../VERSION" 2>/dev/null || echo "unknown"; }
unraid_version() { sed -n 's/^version="\?\([^"]*\)"\?/\1/p' /etc/unraid-version 2>/dev/null | head -n1; }

status_json() {
    local hook proc health libv perms qcount dropped hist
    hook=$(hook_status 2>/dev/null || echo unknown)
    proc=$(_svc processor); health=$(_svc healthcheck)
    virsh_available && libv=true || libv=false
    perms=$(perm_of "$VMS_SECRETS_FILE")
    qcount=$(spool_count 2>/dev/null || echo 0)
    dropped=$(spool_dropped_count 2>/dev/null || echo 0)
    hist=$(history_count 2>/dev/null || echo 0)
    printf '{%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s}\n' \
        "$(json_kv_str plugin_version "$(version)")" \
        "$(json_kv_str unraid_version "$(unraid_version)")" \
        "$(json_kv_str min_unraid "7.2.0")" \
        "$(json_kv_str hook_status "$hook")" \
        "$(json_kv_str processor "$proc")" \
        "$(json_kv_str healthcheck "$health")" \
        "$(json_kv libvirt_available "$libv")" \
        "$(json_kv_str secrets_perms "$perms")" \
        "$(json_kv queue_depth "$(json_num "$qcount")")" \
        "$(json_kv dropped_events "$(json_num "$dropped")")" \
        "$(json_kv history_events "$(json_num "$hist")")"
}

_svc() {
    local pidf="${VMS_RUN_DIR}/$1.pid" p
    p=$(cat "$pidf" 2>/dev/null) && [ -n "$p" ] && kill -0 "$p" 2>/dev/null && echo running || echo stopped
}
perm_of() { [ -e "$1" ] && stat -c '%a' "$1" 2>/dev/null || echo "n/a"; }

bundle() {
    local dir; dir=$(mktemp -d) || { echo "mktemp failed" >&2; exit 1; }
    chmod 700 "$dir"
    status_json > "$dir/status.json"
    # Config: copy but redact (belt-and-suspenders; config should hold no secrets).
    [ -f "$VMS_CONFIG_FILE" ] && redact_stream < "$VMS_CONFIG_FILE" > "$dir/config.json"
    [ -f "$VMS_CONFIG_SNAPSHOT" ] && redact_stream < "$VMS_CONFIG_SNAPSHOT" > "$dir/config.snapshot"
    # NEVER include secrets.json.
    # Logs (already redacted at write time, redacted again defensively).
    [ -f "$VMS_LOG_FILE" ] && redact_stream < "$VMS_LOG_FILE" > "$dir/reelsentry.log"
    # Recent history (already secret-free).
    local hf; hf=$(history_path 2>/dev/null) && [ -f "$hf" ] && tail -n 500 "$hf" | redact_stream > "$dir/history.tail.jsonl"
    # Environment facts.
    { echo "plugin_version=$(version)"; echo "unraid_version=$(unraid_version)";
      echo "date=$(vms_now_iso)"; hook_status; _svc processor; _svc healthcheck; } > "$dir/env.txt"

    local out; out="/tmp/reelsentry-diagnostics-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -C "$dir" -czf "$out" . 2>/dev/null
    rm -rf "$dir"
    echo "$out"
}

case "${1:-status}" in
    status) status_json ;;
    bundle) bundle ;;
    *) echo "usage: $0 {status|bundle}" >&2; exit 2 ;;
esac
