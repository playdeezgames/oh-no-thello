# Oh No, Thello! Design

Reversi (Othello) on an 8x8 board with hidden mines. Decisions below marked **(user)** were given by the user; the rest are defaults to confirm or change.

## Rules

- Standard Reversi: black and white, four starting discs in the centre, a move must flip at least one line of opposing discs, a player with no move passes, the game ends when neither player has a move. Most discs wins.
- Hidden mines are scattered on the board at the start. **(user)** Mines are never placed in the central 4x4, which includes the four starting squares. (Playtest, October 31, 2026: with mines allowed next to the centre, about 40% of games had a side wiped out within the first few moves and 35% ended with 6 discs or fewer. Keeping the centre clear gives 5% and 1%, and 94% of games reach 51+ discs. Win rate for a greedy player against the AI stays about 52/45.)
- **Placing on a mine (user):** the normal Reversi move is completed first (flips happen). Then that square and its 8 neighbours explode: all discs there are removed, those squares become empty, and the mine is eliminated. Play continues with the next player, or the game ends if neither player has a move.
- **Hints (user):** every cell holding a disc shows how many mines are adjacent to it. Empty cells show nothing. Counts reflect mines still in play, so they drop after an explosion.
- Opponent: simple AI. **(user)** One human vs computer; hotseat is a possible later addition.

## Daily puzzle

The title offers **Random game** and **Daily puzzle**. The daily seed is the player's local date as a number (`YYYYMMDD`, for example 20261029 on October 29, 2026). The seed alone decides the mines: `board.place_mines` shuffles the 48 squares outside the central 4x4 with a built-in splitmix64 generator (`board.Rng`, not `core:math/rand`) and takes the first 8, so it is identical on every platform and Odin version. The AI breaks ties from the same seeded stream, so the whole game replays the same way. `daily_board_is_pinned` in `board/board_test.odin` pins the 20261029 layout (re-pinned on October 31, 2026 when the mine-free centre was widened; the new value was cross-checked with an independent Python implementation); changing the algorithm changes every past puzzle, so only do it on purpose. The score is your disc count when the game ends. The best score per date is kept in `localStorage` (key `oh-no-thello:daily-best`) and only the newest 30 dates are kept, so the record is bounded. The title and the daily HUD show the best (`HI`, or `NEW HI!` when beaten).

## Defaults to confirm

- Board 8x8, about 8 mines (tune by playtesting).
- Human plays black and moves first.
- Mines hit by a flipped (not placed) disc do nothing; only the placed square triggers. (Flips never land on empty cells, so a mine can only be triggered by placement.)
- Legal-move set ignores mines: a mine is never visible, so legality must not leak it.
- Explosions can remove discs and open up empty squares in the centre, so a board can end with fewer than 4 discs; the pass/end rules handle this.
- AI is greedy (most flips) with a small preference for corners; it does not see mines.
- Explosion edge case: if an explosion empties the board of one colour's discs and neither side can move, the game ends and discs are counted as usual.

## Architecture notes

Pure board logic lives in its own Odin package (no `core:os`, no JS imports) so it can be tested with `odin test`; the browser layer only renders and routes input. See `CLAUDE.md`.
