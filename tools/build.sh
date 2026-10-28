#!/usr/bin/env bash
# Build the web game into build/web. Pass -o:size via OPT for release builds.
set -euo pipefail
cd "$(dirname "$0")/.."
OPT="${OPT:--o:speed}"
mkdir -p build/web
odin build src -target:js_wasm32 -out:build/web/game.wasm "$OPT"
cp "$(odin root)/core/sys/wasm/js/odin.js" build/web/
cp web/index.html build/web/
[ -d assets/runtime ] && cp -r assets/runtime/. build/web/ || true
echo "built build/web"
