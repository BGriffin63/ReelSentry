#!/usr/bin/env bash
# VM Sentinel — libvirt raw action -> normalized VM Sentinel event (spec §5).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`.
#
# libvirt invokes the qemu hook as:
#     <vm-name> <operation> <sub-operation> <extra>
# Operations we may see: prepare, start, started, stopped, release, restore,
# migrate, reconnect. Sub-operations: begin, end. QEMU/libvirt do NOT hand us a
# rich reason for every transition, so we normalize conservatively and let
# classify.sh decide expected/unexpected/indeterminate (spec §7).

# normalize_event <operation> <sub_operation>  ->  prints normalized event token.
# Never guesses "crashed" unless libvirt explicitly said so.
normalize_event() {
    local op=${1,,} sub=${2,,}
    case "$op" in
        prepare)   echo "starting" ;;
        start)     echo "starting" ;;
        started)   echo "started" ;;
        stopped)
            case "$sub" in
                end)   echo "stopped" ;;
                begin) echo "stopping" ;;
                *)     echo "stopped" ;;
            esac ;;
        release)   echo "released" ;;      # domain resources freed after stop
        shutdown)  echo "shutdown" ;;
        reboot)    echo "rebooted" ;;
        suspend|suspended|pmsuspend) echo "suspended" ;;
        resume|resumed|pmwakeup)     echo "resumed" ;;
        pause|paused)                echo "paused" ;;
        unpause|unpaused)            echo "resumed" ;;
        crashed|crash|panicked|panic) echo "crashed" ;;
        restore)   echo "resumed" ;;
        migrate|migrated) echo "migrated" ;;
        define|defined)   echo "defined" ;;
        undefine|undefined) echo "undefined" ;;
        reconnect) echo "reconnected" ;;
        "")        echo "unknown" ;;
        *)         echo "unknown" ;;
    esac
}

# state_for_event <normalized_event> -> the "current_state" we record.
state_for_event() {
    case "$1" in
        starting)              echo "starting" ;;
        started|resumed|reconnected) echo "running" ;;
        stopping)              echo "stopping" ;;
        stopped|shutdown|crashed|released|undefined) echo "stopped" ;;
        paused|suspended)      echo "paused" ;;
        rebooted)              echo "running" ;;
        migrated)              echo "migrated" ;;
        defined)               echo "defined" ;;
        *)                     echo "unknown" ;;
    esac
}

# event_is_notifiable_key <normalized_event> -> the per-VM config key that gates
# whether a notification is sent for this event (maps events to toggles §8).
event_is_notifiable_key() {
    case "$1" in
        started)            echo "notify_start" ;;
        stopped|released)   echo "notify_stop" ;;
        shutdown)           echo "notify_shutdown" ;;
        crashed)            echo "notify_crash" ;;
        paused|suspended)   echo "notify_pause" ;;
        resumed)            echo "notify_resume" ;;
        rebooted)           echo "notify_reboot" ;;
        starting|stopping|migrated|defined|undefined|reconnected|unknown) echo "" ;;
        *)                  echo "" ;;
    esac
}
