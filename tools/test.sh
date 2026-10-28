#!/usr/bin/env bash
# Native tests for the pure board logic.
set -euo pipefail
cd "$(dirname "$0")/.."
odin test board -define:ODIN_TEST_THREADS=1
