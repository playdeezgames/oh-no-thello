#!/usr/bin/env bash
# Build the shipping wasm and copy it to docs/ for GitHub Pages (served from main, /docs).
# Does not commit or push.
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build.sh --size
rm -rf docs
mkdir docs
cp -r build/web/. docs/
touch docs/.nojekyll
echo "docs/ ready: $(du -sh docs | cut -f1)"
