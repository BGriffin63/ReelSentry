#!/usr/bin/env bash
# ReelSentry — notification provider interface (spec §12).
# SPDX-License-Identifier: MIT
# Sourced, never executed. No `exit`.
#
# A provider is a function  provider_<name>_send  that receives the normalized
# event as EXPORTED environment fields (never as an interpolated shell command)
# and prints exactly one structured result line:
#
#     ok=<0|1> code=<int> msg=<short redacted message>
#
# The dispatcher (notify_dispatch) sets the EV_* environment and calls each
# enabled provider, collecting results. Providers must:
#   * never block indefinitely (hard network timeouts),
#   * never leak secrets into stdout/logs,
#   * never fail the caller (always print a result line and return 0).
#
# Normalized fields exported to providers:
#   EV_EVENT_ID EV_SERVER EV_VM_UUID EV_VM_NAME EV_EVENT_TYPE EV_SEVERITY
#   EV_CLASSIFICATION EV_TIMESTAMP EV_PREVIOUS_STATE EV_CURRENT_STATE
#   EV_HEALTH_STATE EV_SUMMARY EV_DETAILS

# notify_result <ok> <code> <msg>
notify_result() { printf 'ok=%s code=%s msg=%s\n' "$1" "$2" "${3//$'\n'/ }"; }

# notify_provider_registered <name> -> 0 if the provider function exists.
notify_provider_registered() { declare -F "provider_${1}_send" >/dev/null 2>&1; }
