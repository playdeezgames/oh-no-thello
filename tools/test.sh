#!/usr/bin/env bash
# Native tests: the pure board logic and the game glue.
set -euo pipefail
cd "$(dirname "$0")/.."
odin test board -define:ODIN_TEST_THREADS=1
odin test game -collection:ont=. -define:ODIN_TEST_THREADS=1
