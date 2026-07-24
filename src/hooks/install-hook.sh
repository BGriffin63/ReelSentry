#!/usr/bin/env bash
# VM Sentinel — idempotent, surgical hook install/uninstall (spec §6, §20).
# SPDX-License-Identifier: MIT
#
# We install exactly ONE namespaced file and never touch the shared qemu file:
#     /etc/libvirt/hooks/qemu.d/50-vm-sentinel
#
# The optional cooperative shim (see RESEARCH.md §3.1) is DISABLED by default and
# only relevant if hardware testing proves qemu.d/ is not honored.

set -u

VMS_HOOK_ROOT="${VMS_HOOK_ROOT:-/etc/libvirt/hooks}"
VMS_HOOK_D="${VMS_HOOK_ROOT}/qemu.d"
VMS_HOOK_NAME="50-vm-sentinel"
VMS_HOOK_TARGET="${VMS_HOOK_D}/${VMS_HOOK_NAME}"
VMS_HOOK_SOURCE="${VMS_HOOK_SOURCE:-/usr/local/emhttp/plugins/vm.sentinel/hooks/vm-sentinel-hook}"

# A marker line lets us positively identify OUR file for surgical removal and to
# recognize an existing correct install (idempotency).
VMS_HOOK_MARKER="# VM-SENTINEL-OWNED-HOOK v1"

hook_is_ours() {
    [ -f "$1" ] || return 1
    head -n 20 "$1" 2>/dev/null | grep -qF "$VMS_HOOK_MARKER"
}

# install_hook: copy our hook into qemu.d/, mark it, make it executable.
# Idempotent: re-running updates the payload in place, never duplicates.
install_hook() {
    mkdir -p "$VMS_HOOK_D" 2>/dev/null || { echo "ERROR: cannot create $VMS_HOOK_D" >&2; return 1; }
    if [ ! -f "$VMS_HOOK_SOURCE" ]; then
        echo "ERROR: hook source missing: $VMS_HOOK_SOURCE" >&2; return 1
    fi
    local tmp="${VMS_HOOK_TARGET}.tmp.$$"
    {
        printf '%s\n' "$VMS_HOOK_MARKER"
        cat "$VMS_HOOK_SOURCE"
    } > "$tmp" 2>/dev/null || { echo "ERROR: cannot stage hook" >&2; rm -f "$tmp"; return 1; }
    chmod 755 "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$VMS_HOOK_TARGET" 2>/dev/null || { rm -f "$tmp"; echo "ERROR: cannot install hook" >&2; return 1; }
    echo "Installed hook: $VMS_HOOK_TARGET"
    return 0
}

# uninstall_hook: remove ONLY our file, only if it is ours. Idempotent; succeeds
# even if already gone (spec §20). Never touches the shared qemu file or any
# other qemu.d/* consumer.
uninstall_hook() {
    if [ ! -e "$VMS_HOOK_TARGET" ]; then
        echo "Hook already absent: $VMS_HOOK_TARGET"; return 0
    fi
    if hook_is_ours "$VMS_HOOK_TARGET"; then
        rm -f "$VMS_HOOK_TARGET" 2>/dev/null && echo "Removed hook: $VMS_HOOK_TARGET"
    else
        echo "REFUSING to remove $VMS_HOOK_TARGET: not VM Sentinel-owned" >&2
        return 1
    fi
    # Remove now-empty qemu.d only if WE created it and it is empty; otherwise leave.
    rmdir "$VMS_HOOK_D" 2>/dev/null || true
    return 0
}

# hook_status: report installed / ours / missing for Diagnostics.
hook_status() {
    if [ ! -e "$VMS_HOOK_TARGET" ]; then echo "missing"; return; fi
    if hook_is_ours "$VMS_HOOK_TARGET"; then echo "installed"; else echo "foreign"; fi
}

# Allow direct CLI use: install-hook.sh {install|uninstall|status}
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-status}" in
        install)   install_hook ;;
        uninstall) uninstall_hook ;;
        status)    hook_status ;;
        *) echo "usage: $0 {install|uninstall|status}" >&2; exit 2 ;;
    esac
fi
