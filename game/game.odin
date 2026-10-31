// Game state and rules glue. No drawing and no JS: the web layer reads this and draws it.
package game

import "ont:board"

LOGICAL_W :: 144
LOGICAL_H :: 176
TILE :: 16
BOARD_X :: 8
BOARD_Y :: 24

// Title screen buttons (logical pixels): Random game, then Daily puzzle.
BTN_X :: 12
BTN_W :: 120
BTN_H :: 16
BTN_Y0 :: 108
BTN_Y1 :: 128

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

// Keyboard and gamepad commands; the page maps keys and buttons to these.
Action :: enum i32 {
	Up,
	Down,
	Left,
	Right,
	Confirm,
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
	rng:      board.Rng, // the AI's tie-breaks; seeded like the mines, so a daily game replays exactly
	daily:    bool, // this game is the daily puzzle
	seed:     u64, // the seed this game was dealt from
	menu:     int, // title selection: 0 random game, 1 daily puzzle
	today:    u64, // today's date as YYYYMMDD; set by the platform
	best:     int, // best score (your discs at the end) on today's daily puzzle; 0 = not played; set by the platform
	new_best: bool, // this game beat `best`
	save_best: bool, // the platform should store `best` for `today`, then clear this
	clock:    u64, // any changing number (a timestamp); set by the platform, seeds random games
	cursor:   [2]int, // board cell for keyboard and gamepad play
	cursor_on: bool, // drawn only after a key or button press; a mouse click hides it
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

// Deal a game. The same seed always gives the same mines, and the AI breaks its
// ties from the same stream, so the daily puzzle plays out the same way each time.
start :: proc(g: ^Game, seed: u64, daily: bool) {
	menu, today, clock, best := g.menu, g.today, g.clock, g.best
	g^ = {}
	g.menu, g.today, g.clock, g.best = menu, today, clock, best
	g.phase = .Playing
	g.daily = daily
	g.seed = seed
	g.rng = board.rng_seed(seed)
	g.b = board.new_board()
	board.place_mines(&g.b, MINES, &g.rng)
	g.ai_wait = AI_DELAY
	g.cursor = {3, 2} // one of Black's four opening moves
}

// Back to the title with a clean board, so the finished game does not show through it.
to_title :: proc(g: ^Game) {
	g.phase = .Title
	g.b = board.new_board()
	g.booms = {}
}

// Start whatever the title menu has selected.
start_selected :: proc(g: ^Game) {
	if g.menu == 1 {
		start(g, g.today, true)
	} else {
		start(g, g.clock, false)
	}
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
		if g.daily && me > g.best {
			g.best, g.new_best, g.save_best = me, true, true
		}
	}
	return true
}

// Greedy: most flips, with a bonus for corners. It cannot see mines.
ai_choose :: proc(b: ^board.Board, r: ^board.Rng) -> (x, y: int, ok: bool) {
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
				if board.rng_int(r, ties) == 0 {x, y = cx, cy}
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
			if x, y, ok := ai_choose(&g.b, &g.rng); ok {make_move(g, x, y)}
		}
	}
}

// A key or gamepad command. Moving the cursor never plays; Confirm does.
input :: proc(g: ^Game, a: Action) {
	g.cursor_on = true
	switch g.phase {
	case .Title:
		switch a {
		case .Up, .Left:     g.menu = 0
		case .Down, .Right:  g.menu = 1
		case .Confirm:       start_selected(g)
		}
		return
	case .Over:
		if a == .Confirm {to_title(g)}
		return
	case .Playing:
	}
	switch a {
	case .Up:    g.cursor.y = max(g.cursor.y - 1, 0)
	case .Down:  g.cursor.y = min(g.cursor.y + 1, board.SIZE - 1)
	case .Left:  g.cursor.x = max(g.cursor.x - 1, 0)
	case .Right: g.cursor.x = min(g.cursor.x + 1, board.SIZE - 1)
	case .Confirm:
		if g.b.turn == HUMAN {make_move(g, g.cursor.x, g.cursor.y)}
	}
}

// A tap or click at logical pixel (px, py).
click :: proc(g: ^Game, px, py: int) {
	g.cursor_on = false
	switch g.phase {
	case .Title:
		if px < BTN_X || px >= BTN_X + BTN_W {return}
		switch {
		case py >= BTN_Y0 && py < BTN_Y0 + BTN_H: g.menu = 0
		case py >= BTN_Y1 && py < BTN_Y1 + BTN_H: g.menu = 1
		case: return
		}
		start_selected(g)
	case .Over:
		to_title(g)
	case .Playing:
		if g.b.turn != HUMAN {return}
		x := (px - BOARD_X) / TILE
		y := (py - BOARD_Y) / TILE
		if px < BOARD_X || py < BOARD_Y {return}
		make_move(g, x, y)
	}
}
