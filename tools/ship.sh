#!/usr/bin/env bash
# Prepares the itch.io build: tests, a size-optimised web build, a zip. Pushes ONLY with --push. Never commits,
# never deletes anything but its own zip. Usage: tools/ship.sh [--push]
#
# Page: https://thegrumpygamedev.itch.io/oh-no-thello (created as a draft November 17, 2026, game id 5387353;
# the slug is confirmed, so TARGET is right). butler cannot create a page.
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="thegrumpygamedev/oh-no-thello:html"
ZIP="build/oh-no-thello-html5.zip"

tools/test.sh
tools/build.sh --size
rm -f "$ZIP"
(cd build/web && zip -q -9 -r "../oh-no-thello-html5.zip" .) # index.html at the zip's root
echo "zip: $ZIP ($(du -h "$ZIP" | cut -f1)); wasm $(du -h build/web/game.wasm | cut -f1)"
unzip -l "$ZIP" | tail -8

if [[ "${1:-}" == "--push" ]]; then
	if [[ -z "$TARGET" ]]; then
		echo "refusing to push: TARGET is not set in tools/ship.sh" >&2
		exit 1
	fi
	if [[ -n "$(git status --porcelain)" ]]; then echo "note: the working tree has uncommitted changes; what is pushed is the working tree, not a commit"; fi
	butler push build/web "$TARGET"
	echo "pushed to $TARGET. It goes live after itch.io processes it; check: butler status $TARGET"
else
	echo "not pushed (run tools/ship.sh --push when you want it live; target: ${TARGET:-<not set yet>})"
fi
