# Oh No, Thello! Design

Reversi (Othello) on an 8x8 board with hidden mines. Decisions below marked **(user)** were given by the user; the rest are defaults to confirm or change.

## Rules

- Standard Reversi: black and white, four starting discs in the centre, a move must flip at least one line of opposing discs, a player with no move passes, the game ends when neither player has a move. Most discs wins.
- Hidden mines are scattered on the board at the start. **(user)** Mines are never placed on the four starting squares (an explosion there would wreck the opening).
- **Placing on a mine (user):** the normal Reversi move is completed first (flips happen). Then that square and its 8 neighbours explode: all discs there are removed, those squares become empty, and the mine is eliminated. Play continues with the next player, or the game ends if neither player has a move.
- **Hints (user):** every cell holding a disc shows how many mines are adjacent to it. Empty cells show nothing. Counts reflect mines still in play, so they drop after an explosion.
- Opponent: simple AI. **(user)** One human vs computer; hotseat is a possible later addition.

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
