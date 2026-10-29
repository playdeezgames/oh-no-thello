# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Oh No, Thello!** is a browser game, a mashup of Reversi (Othello) and Minesweeper, written in Odin, compiled to `js_wasm32`, and published on itch.io. Rules are in `DESIGN.md` (user decisions are marked there). Tasks are in Coxswain project `oh-no-thello`.

## Layout

- `board/`: pure Reversi + mine logic (`play`, `place_mines`, explosions). No JS, no `core:os`.
- `game/`: game state, AI, turn flow, sound queue; imports `ont:board`. Still no drawing or JS.
- `src/web/`: the wasm entry point (`#+build js`): drawing and input only, calls `game`. Packages are imported through the `ont` collection (`-collection:ont=.`).
- `web/index.html`: canvas shim (sprites from `art.png`, m5x7 bitmap text, WebAudio sfx, tap to `click`).
- `assets/art/world.json` is the Anvil export (source copy `~/anvil-worlds/oh-no-thello.json`); `tools/gen_atlas.py` packs its sprites into `build/web/art.png` in sprite-set order, which must match `Sprite` in `game/game.odin`. `assets/sfx/*.wav` are Anvil PLAY-text sounds; the order must match `Sound` and `SOUND_FILES` in `web/index.html`. To change art or sound: edit in Anvil, re-export, rebuild.

## External resources (outside this repo)

- **Vault of notes:** `/home/yermom/git/bok-of-splorr/splorr` (Obsidian vault, Markdown with `[[wikilinks]]`). Read `Home.md` first (standing rules), then `Tech/Odin wasm recipe.md`, `Tech/Release standard.md`, `Tech/Shipping to itch.io.md`, `Gotchas.md`. Games it describes live under `/home/yermom/git/` (each game note's `repo:` field). Add new lessons to `Gotchas.md`; add a `Games/` note for this game and link it from `Home.md` when the game takes shape.
- **Anvil** (MCP server `mcp__anvil-prod__*`): use it to create assets (sprites, tilesets, maps, palettes, sounds).
- **Coxswain** (MCP server `mcp__coxswain__*`): task management and ship scheduling. Register as agent **`oh-no-thello`** (`agent_register`) and claim/complete tasks through it.

## Build and run

Odin is at `/home/yermom/.local/bin/odin` (`dev-2026-07`).

```bash
tools/build.sh          # builds build/web (use --size for the shipping build)
tools/test.sh           # native tests for board/ and game/
python3 -m http.server -d build/web 8000   # wasm must be served over http, not file://
```

GitHub Pages: the repo is public and Pages serves `main` `/docs`. `tools/pages.sh` rebuilds `docs/` (shipping build); commit it and push to update https://playdeezgames.github.io/oh-no-thello/ (see the bok's `Tech/GitHub Pages.md`).

Daily puzzle: the page supplies today's local date as `YYYYMMDD` (`today_seed` import); `game.start(g, seed, daily)` deals from it. All randomness in board setup and the AI goes through `board.Rng` (splitmix64), never `core:math/rand`, so a seed always replays identically; do not change it without updating the pinned test.

Daily best score: `game` sets `best`/`save_best`; the page stores it via `load_best`/`save_best` in `localStorage` (`oh-no-thello:daily-best`), pruned to the newest 30 dates (`BEST_DAYS` in `web/index.html`).

Input: the page maps mouse/touch to `click`, and keys and gamepad to `input` (`game.Action`; order must match `ACTION` in `web/index.html`).

Test files carry `#+build !js` (`core:testing` pulls in `core:os`, which panics on wasm). Always run the wasm build as well as the tests.

## Architecture conventions to follow

- Runtime is Odin's own `core/sys/wasm/js/odin.js` (no emscripten). Odin exports `step :: proc(dt: f64, c: runtime.Context) -> bool` (called each animation frame; save `ctx` in `main` and set `context = ctx` in `step` and every event callback).
- Draw with a **2D canvas through a small JS shim**, not WebGL (WebGL fails in the user's Chrome and in the in-app browser). Odin imports the shim via `foreign import canvas "canvas"`; the name must match the key passed as the third argument to `odin.runWasm`. Disable image smoothing for pixel art.
- Split game logic from platform code. `core:os` panics at start-up on `js_wasm32`, so keep it out of shared code; put platform-specific code in files marked `#+build js` / `#+build !js`, and mark native test files `#+build !js`.
- Board logic (flip rules, mine placement, reveal/flood) should be pure and testable natively, with the browser layer only rendering and routing input.

## Odin on wasm: pitfalls that already bit other games

- `int` is 32 bits on `js_wasm32` (64 natively). Use `i64`/`f64` for timestamps and large values, and range-check before narrowing.
- Seed the RNG in `main` (`rand.reset(u64(time.now()._nsec))`) and cap every "find a random free cell" retry loop; an unbounded loop freezes the whole tab. Mine placement is exactly this kind of loop.
- `DIRS :: [N][2]int{...}` constant arrays cannot take a runtime index; use a variable (`dirs := ...`). Direction tables for Reversi will hit this.
- `where` and `cast` are keywords; they cannot be field or identifier names.
- If saving state to `localStorage`, use a game-specific key; a generic key is shared with every itch.io game.
- `core:encoding/json` is JSON5 by default; pass `.JSON` for save files and validate every enum.

## Release and safety rules (from the vault's `Home.md`)

- Never `git push` or ship unless the user says so explicitly. **"Push" means `git push`; "ship" means itch.io** (`shippit.sh --push` / `butler push`). Do not confuse them or ask which is meant.
- One ship per day, scheduled in Coxswain: call `ship_today` first and do not ship when `may_ship_now` is false; `ship_schedule` to plan, `ship_complete` after a successful push. Scheduling is not permission to ship.
- Anything posted on itch.io by an AI agent (devlogs, page copy, comments) must clearly say an AI agent posted it, and publishing needs a yes each time.
- Follow `Tech/Release standard.md` layout: `ITCH_DESCRIPTION.md` (short description at most 120 characters), `assets/cover.png` (630x500), `assets/screenshots/01-title.png`, ... , `devlog/YYYYMMDD/devlog.md`, `tools/ship.sh` (template: `/home/yermom/git/FortuneHunter/tools/ship.sh`; pushes only with `--push`, never runs `git add`/`commit`), `tools/build.sh`, `tools/test.sh`, and a root `shippit.sh` that is exactly `exec "$(dirname "$0")/tools/ship.sh" "$@"`. Web builds use `-o:size`; zip `build/web` with `index.html` at the zip root. New pages use itch channel `html`. Commit before shipping.
- Do not describe or "fix" a deliberate design choice as a problem. Steam: free games only, no demos or marketing.
- If a ROM font 8x8 (`Font8x8.png`) is involved, ask before replacing it.
