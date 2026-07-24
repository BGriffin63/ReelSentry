#!/usr/bin/env bash
# Integration/regression: the INSTALLED libvirt hook must be a valid executable
# with its shebang on line 1, and the 'prepare' phase must exit 0 with no deps.
# This guards against the 0.1.0 bug where a marker comment displaced the shebang,
# causing libvirt "Exec format error" (exit 126) that BLOCKED VM start (spec §6).
. "$(dirname "$0")/../lib/testlib.sh"
vms_test_env
trap vms_test_cleanup EXIT

export VMS_HOOK_ROOT="$VMS_ROOT_TMP/etc-libvirt-hooks"
export VMS_HOOK_SOURCE="$REPO_ROOT/src/hooks/vm-sentinel-hook"
# shellcheck source=/dev/null
. "$REPO_ROOT/src/hooks/install-hook.sh"

target="$VMS_HOOK_ROOT/qemu.d/50-vm-sentinel"

# Install.
install_hook >/dev/null
assert_true  "hook installed" "[ -f '$target' ]"
assert_true  "hook is executable" "[ -x '$target' ]"

# THE key assertion: shebang on line 1 (first two bytes are '#!').
first2=$(head -c 2 "$target")
assert_eq    "first two bytes are a shebang" "$first2" "#!"

# It must be valid bash syntax.
assert_true  "installed hook passes bash -n" "bash -n '$target'"

# Ownership marker must be present (for surgical uninstall) but NOT on line 1.
assert_true  "hook recognized as ours" "hook_is_ours '$target'"
line1=$(head -n1 "$target")
assert_ne    "marker is not on line 1" "$line1" "# VM-SENTINEL-OWNED-HOOK v1"

# Fail-open: the 'prepare' phase must exit 0 with ZERO dependencies. Run the file
# via bash directly (portable) with a bogus libdir so any sourcing would fail —
# it must still exit 0 because prepare returns before sourcing.
VMS_LIBDIR="/nonexistent" bash "$target" "Umbriel" prepare begin - ; rc=$?
assert_eq    "prepare exits 0 even with no libs" "$rc" "0"
VMS_LIBDIR="/nonexistent" bash "$target" "Umbriel" reconnect begin - ; rc=$?
assert_eq    "reconnect exits 0 even with no libs" "$rc" "0"

# If the shebang interpreter exists here, executing the file directly must work
# (this is what libvirt does; exit 126 = the bug we are guarding against).
interp=$(sed -n '1s/^#!//p' "$target" | awk '{print $1}')
if [ -x "$interp" ]; then
    VMS_LIBDIR="/nonexistent" "$target" "Umbriel" prepare begin - ; rc=$?
    assert_eq "direct exec via shebang works (no Exec format error)" "$rc" "0"
else
    ok "shebang interpreter $interp absent on test host; skipped direct-exec (CI covers it)"
fi

# Uninstall is surgical + idempotent.
uninstall_hook >/dev/null
assert_true  "hook removed" "[ ! -e '$target' ]"
uninstall_hook >/dev/null; rc=$?
assert_eq    "uninstall idempotent (ok when already gone)" "$rc" "0"

# Must refuse to remove a foreign (non-ours) file at that path.
mkdir -p "$(dirname "$target")"
printf '#!/bin/bash\n# someone elses hook\n' > "$target"
uninstall_hook >/dev/null 2>&1
assert_true  "foreign hook preserved" "[ -f '$target' ]"

vms_test_summary
