#!/usr/bin/env bash
# VM Sentinel — run the full automated test suite (spec §27).
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$ROOT/tests/run.sh"
