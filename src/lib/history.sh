#!/usr/bin/env bash
# VM Sentinel — event history storage as rotated JSON Lines (spec §15).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`. Depends on common.sh, json.sh, redact.sh.
#
# History is high-churn, so it lives in appdata (fallback tmpfs) and NEVER on the
# boot flash. Bounded by retention days and max event count. One JSON object per
# line makes append cheap and filtering easy.

# history_dir: resolve a writable history directory, preferring appdata.
history_dir() {
    local d="$VMS_HISTORY_DIR"
    if mkdir -p "$d" 2>/dev/null && [ -w "$d" ]; then printf '%s' "$d"; return 0; fi
    d="$VMS_HISTORY_FALLBACK_DIR"
    if mkdir -p "$d" 2>/dev/null && [ -w "$d" ]; then printf '%s' "$d"; return 0; fi
    return 1
}

history_path() {
    local d; d=$(history_dir) || return 1
    printf '%s/%s' "$d" "$VMS_HISTORY_FILE"
}

# history_append: append a pre-built JSON object (single line) atomically-ish.
# Appends are already atomic for small writes on local fs; we also take a
# dependency-free lock to keep concurrent processors honest.
history_append() {
    local json=$1 file
    file=$(history_path) || { vms_log_warning queue "no writable history dir"; return 1; }
    vms_mkrundirs 2>/dev/null
    vms_lock_acquire history 5 || return 1
    # Redaction guard: history must never contain secrets even if a bug leaked one.
    printf '%s\n' "$json" | redact_stream >> "$file" 2>/dev/null
    local rc=$?
    vms_lock_release history
    history_rotate_if_needed
    return $rc
}

# history_rotate_if_needed: enforce max event count + retention days.
history_rotate_if_needed() {
    local file; file=$(history_path) 2>/dev/null || return 0
    [ -f "$file" ] || return 0
    local max_count max_days
    max_count=$(config_get history_max_events 5000)
    max_days=$(config_get history_retention_days 30)
    case "$max_count" in ''|*[!0-9]*) max_count=5000 ;; esac
    case "$max_days" in ''|*[!0-9]*) max_days=30 ;; esac

    # Count bound: keep only the most recent max_count lines.
    local lines
    lines=$(wc -l < "$file" 2>/dev/null || echo 0)
    if [ "${lines:-0}" -gt "$max_count" ]; then
        local tmp; tmp="${file}.rot.$(vms_rand_token)"
        tail -n "$max_count" "$file" > "$tmp" 2>/dev/null && mv -f "$tmp" "$file" 2>/dev/null
    fi

    # Age bound: drop lines whose "timestamp" is older than max_days. Timestamps
    # are ISO-8601; we compare by date prefix converted to epoch.
    if [ "$max_days" -gt 0 ]; then
        local cutoff tmp
        cutoff=$(date -d "-${max_days} days" +%s 2>/dev/null || echo "")
        if [ -n "$cutoff" ]; then
            tmp="${file}.age.$(vms_rand_token)"
            awk -v cutoff="$cutoff" '
                match($0, /"timestamp":"([^"]+)"/, m) {
                    cmd="date -d \"" m[1] "\" +%s 2>/dev/null"
                    cmd | getline ts; close(cmd)
                    if (ts=="" || ts+0 >= cutoff) print
                    next
                }
                { print }
            ' "$file" > "$tmp" 2>/dev/null && mv -f "$tmp" "$file" 2>/dev/null || rm -f "$tmp" 2>/dev/null
        fi
    fi
    return 0
}

# history_clear: truncate history (used by GUI "Clear" with confirmation).
history_clear() {
    local file; file=$(history_path) 2>/dev/null || return 1
    : > "$file" 2>/dev/null
}

# history_count
history_count() {
    local file; file=$(history_path) 2>/dev/null || { echo 0; return; }
    [ -f "$file" ] && wc -l < "$file" 2>/dev/null || echo 0
}
