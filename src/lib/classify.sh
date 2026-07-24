#!/usr/bin/env bash
# ReelSentry — severity mapping + intent classification (spec §7).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`.
#
# Honesty rule: we only assert "unexpected" when libvirt gives us a genuine
# crash/failure signal. A bare stop with no context is "indeterminate", never
# "crashed". Maintenance context downgrades to "expected".

# severity_for_event <normalized_event> <classification> -> info|warning|critical
severity_for_event() {
    local ev=$1 cls=$2
    case "$ev" in
        crashed) echo "critical"; return ;;
        started|resumed|defined|reconnected) echo "info"; return ;;
        paused|suspended|rebooted|starting|stopping|migrated) echo "info"; return ;;
    esac
    # stop/shutdown/etc depend on classification
    case "$cls" in
        unexpected)    echo "critical" ;;
        indeterminate) echo "warning" ;;
        expected)      echo "info" ;;
        *)             echo "warning" ;;
    esac
}

# classify_event <normalized_event> <raw_sub_action> <maintenance_flag 0|1>
#   -> expected|unexpected|indeterminate
classify_event() {
    local ev=$1 sub=${2,,} maint=${3:-0}

    # Maintenance context (array stop / VM Manager shutdown) makes any stop expected.
    if [ "$maint" = "1" ]; then
        case "$ev" in
            stopped|shutdown|released|crashed|paused|suspended) echo "expected"; return ;;
        esac
    fi

    case "$ev" in
        crashed)                 echo "unexpected" ;;
        shutdown)                echo "expected" ;;      # explicit ACPI/guest shutdown
        started|resumed|starting|paused|suspended|rebooted|defined|reconnected|migrated)
                                 echo "expected" ;;      # normal informational events
        stopped)
            # "stopped end" alone from libvirt lacks intent context.
            case "$sub" in
                end) echo "indeterminate" ;;
                *)   echo "indeterminate" ;;
            esac ;;
        released)                echo "indeterminate" ;;
        *)                       echo "indeterminate" ;;
    esac
}

# summary_for_event <vm_name> <normalized_event> <classification>
# Produces user-facing, non-over-claiming wording (spec §7 example strings).
summary_for_event() {
    local vm=$1 ev=$2 cls=$3
    case "$ev" in
        started)   printf '%s started' "$vm" ;;
        starting)  printf '%s is starting' "$vm" ;;
        stopping)  printf '%s is stopping' "$vm" ;;
        shutdown)  printf '%s shut down normally' "$vm" ;;
        crashed)   printf '%s crashed' "$vm" ;;
        paused)    printf '%s was paused' "$vm" ;;
        suspended) printf '%s was suspended' "$vm" ;;
        resumed)   printf '%s resumed' "$vm" ;;
        rebooted)  printf '%s rebooted' "$vm" ;;
        migrated)  printf '%s migrated' "$vm" ;;
        defined)   printf '%s was defined' "$vm" ;;
        undefined) printf '%s was removed' "$vm" ;;
        stopped|released)
            case "$cls" in
                expected)      printf '%s stopped normally' "$vm" ;;
                unexpected)    printf '%s stopped unexpectedly' "$vm" ;;
                indeterminate) printf '%s stopped; the reason could not be determined' "$vm" ;;
                *)             printf '%s stopped' "$vm" ;;
            esac ;;
        *)         printf '%s changed state' "$vm" ;;
    esac
}

# details_for_event <normalized_event> <classification> <maintenance_flag>
details_for_event() {
    local ev=$1 cls=$2 maint=${3:-0}
    if [ "$maint" = "1" ]; then
        echo "Monitoring was interrupted during an Unraid or VM Manager restart."
        return
    fi
    case "$ev" in
        crashed) echo "Libvirt reported a crash lifecycle event. Health monitoring is suspended until the VM starts again." ;;
        shutdown) echo "The guest performed a normal shutdown." ;;
        stopped|released)
            case "$cls" in
                indeterminate) echo "The VM entered a stopped state, but libvirt did not provide enough context to determine the reason." ;;
                unexpected)    echo "The VM stopped without a corresponding graceful-shutdown signal." ;;
                *)             echo "The VM stopped." ;;
            esac ;;
        *) echo "" ;;
    esac
}
