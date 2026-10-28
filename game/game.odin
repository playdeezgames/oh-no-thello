// Game state and rules glue. No drawing and no JS: the web layer reads this and draws it.
package game

import "core:math/rand"
import "ont:board"

LOGICAL_W :: 144
LOGICAL_H :: 176
TILE :: 16
BOARD_X :: 8
BOARD_Y :: 24

MINES :: 8
AI_DELAY :: 0.6
BOOM_TIME :: 0.5
NOTE_TIME :: 2.0

// Order must match the sprite order in assets/art/world.json (see tools/gen_atlas.py).
Sprite :: enum i32 {
	Felt,
	Disc_Black,
	Disc_White,
	Mine,
	Boom,
	Hint,
	N1,
	N2,
	N3,
	N4,
	N5,
	N6,
	N7,
	N8,
}

// Order must match SOUND_FILES in web/index.html (assets/sfx/<name>.wav).
Sound :: enum i32 {
	Place,
	Flip,
	Win,
	Lose,
	Boom,
}

Phase :: enum {
	Title,
	Playing,
	Over,
}

Game :: struct {
	phase:    Phase,
	b:        board.Board,
	ai_wait:  f32,
	booms:    [board.SIZE][board.SIZE]f32, // seconds of explosion animation left
	note:     string, // a short message such as a forced pass
	note_t:   f32,
	sounds:   [8]Sound,
	n_sounds: int,
}

// The human plays Black and moves first; the computer plays White.
HUMAN :: board.Disc.Black

title :: proc() -> Game {
	g: Game
	g.b = board.new_board()
	return g
}

start :: proc(g: ^Game) {
	g^ = {}
	g.phase = .Playing
	g.b = board.new_board()
	board.place_mines(&g.b, MINES)
	g.ai_wait = AI_DELAY
}

queue_sound :: proc(g: ^Game, s: Sound) {
	if g.n_sounds < len(g.sounds) {
		g.sounds[g.n_sounds] = s
		g.n_sounds += 1
	}
}

take_sound :: proc(g: ^Game) -> (s: Sound, ok: bool) {
	if g.n_sounds == 0 {return}
	s = g.sounds[0]
	for i in 1 ..< g.n_sounds {
		g.sounds[i - 1] = g.sounds[i]
	}
	g.n_sounds -= 1
	return s, true
}

// Mines are secret until the game ends or they go off, so a hint never leaks one.
show_mines :: proc(g: ^Game) -> bool {
	return g.phase == .Over
}

make_move :: proc(g: ^Game, x, y: int) -> bool {
	mover := g.b.turn
	res := board.play(&g.b, x, y)
	if !res.ok {return false}
	queue_sound(g, .Place)
	if res.flipped > 0 {queue_sound(g, .Flip)}
	if res.exploded {
		queue_sound(g, .Boom)
		for dy in -1 ..= 1 {
			for dx in -1 ..= 1 {
				if board.in_bounds(x + dx, y + dy) {g.booms[y + dy][x + dx] = BOOM_TIME}
			}
		}
	}
	g.ai_wait = AI_DELAY
	if res.passed {
		g.note = mover == HUMAN ? "WHITE MUST PASS" : "YOU MUST PASS"
		g.note_t = NOTE_TIME
	}
	if g.b.status == .Over {
		g.phase = .Over
		me := board.count_discs(&g.b, HUMAN)
		ai := board.count_discs(&g.b, board.opponent(HUMAN))
		queue_sound(g, me >= ai ? .Win : .Lose)
	}
	return true
}

// Greedy: most flips, with a bonus for corners. It cannot see mines.
ai_choose :: proc(b: ^board.Board) -> (x, y: int, ok: bool) {
	best := -1
	ties := 0
	for cy in 0 ..< board.SIZE {
		for cx in 0 ..< board.SIZE {
			n := board.flip_count(b, cx, cy, b.turn)
			if n == 0 {continue}
			corner := (cx == 0 || cx == board.SIZE - 1) && (cy == 0 || cy == board.SIZE - 1)
			score := n + (corner ? 10 : 0)
			if score > best {
				best = score
				ties = 1
				x, y, ok = cx, cy, true
			} else if score == best {
				ties += 1
				if rand.int_max(ties) == 0 {x, y = cx, cy}
			}
		}
	}
	return
}

update :: proc(g: ^Game, dt: f32) {
	for &row in g.booms {
		for &t in row {
			if t > 0 {t -= dt}
		}
	}
	if g.note_t > 0 {
		g.note_t -= dt
		if g.note_t <= 0 {g.note = ""}
	}
	if g.phase == .Playing && g.b.turn != HUMAN {
		g.ai_wait -= dt
		if g.ai_wait <= 0 {
			if x, y, ok := ai_choose(&g.b); ok {make_move(g, x, y)}
		}
	}
}

// A tap or click at logical pixel (px, py).
click :: proc(g: ^Game, px, py: int) {
	switch g.phase {
	case .Title, .Over:
		start(g)
	case .Playing:
		if g.b.turn != HUMAN {return}
		x := (px - BOARD_X) / TILE
		y := (py - BOARD_Y) / TILE
		if px < BOARD_X || py < BOARD_Y {return}
		make_move(g, x, y)
	}
}
