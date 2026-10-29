package board

SIZE :: 8

Disc :: enum u8 {
	None,
	Black,
	White,
}

Cell :: struct {
	disc: Disc,
	mine: bool,
}

Status :: enum {
	Playing,
	Over,
}

Board :: struct {
	cells:  [SIZE][SIZE]Cell,
	turn:   Disc,
	status: Status,
}

Play_Result :: struct {
	ok:        bool,
	flipped:   int,
	exploded:  bool,
	passed:    bool, // the opponent had no move, so the same player moves again
}

opponent :: proc(d: Disc) -> Disc {
	return d == .Black ? .White : .Black
}

in_bounds :: proc(x, y: int) -> bool {
	return x >= 0 && x < SIZE && y >= 0 && y < SIZE
}

is_start_square :: proc(x, y: int) -> bool {
	return (x == 3 || x == 4) && (y == 3 || y == 4)
}

// Empty board with the four starting discs and Black to move. No mines.
new_board :: proc() -> Board {
	b: Board
	b.turn = .Black
	b.cells[3][3].disc = .White
	b.cells[4][4].disc = .White
	b.cells[3][4].disc = .Black
	b.cells[4][3].disc = .Black
	return b
}

// A small seeded generator (splitmix64). It is defined here, not taken from
// core:math/rand, so a seed gives the same sequence on every platform and every
// Odin version: the daily puzzle depends on that.
Rng :: struct {
	state: u64,
}

rng_seed :: proc(seed: u64) -> Rng {
	return Rng{state = seed}
}

rng_next :: proc(r: ^Rng) -> u64 {
	r.state += 0x9E3779B97F4A7C15
	z := r.state
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

// A number in [0, n).
rng_int :: proc(r: ^Rng, n: int) -> int {
	return int(rng_next(r) % u64(n))
}

// Scatter exactly `count` mines (fewer only if the board has no room), never on
// the four starting squares. Same generator state, same mines. Returns how many.
place_mines :: proc(b: ^Board, count: int, r: ^Rng) -> int {
	spots: [SIZE * SIZE][2]int
	n := 0
	for y in 0 ..< SIZE {
		for x in 0 ..< SIZE {
			if !is_start_square(x, y) {
				spots[n] = {x, y}
				n += 1
			}
		}
	}
	placed := min(count, n)
	// Partial Fisher-Yates: the first `placed` entries are a uniform random pick.
	for i in 0 ..< placed {
		j := i + rng_int(r, n - i)
		spots[i], spots[j] = spots[j], spots[i]
		b.cells[spots[i].y][spots[i].x].mine = true
	}
	return placed
}

// Mines in the 8 squares around (x, y); the square itself is not counted.
neighbour_mines :: proc(b: ^Board, x, y: int) -> int {
	n := 0
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			if dx == 0 && dy == 0 {continue}
			if in_bounds(x + dx, y + dy) && b.cells[y + dy][x + dx].mine {n += 1}
		}
	}
	return n
}

// Discs that would flip along one direction, or 0 if the line is not bracketed.
@(private)
line_flips :: proc(b: ^Board, x, y, dx, dy: int, player: Disc) -> int {
	n := 0
	cx, cy := x + dx, y + dy
	for in_bounds(cx, cy) {
		d := b.cells[cy][cx].disc
		if d == .None {return 0}
		if d == player {return n}
		n += 1
		cx += dx
		cy += dy
	}
	return 0
}

flip_count :: proc(b: ^Board, x, y: int, player: Disc) -> int {
	if !in_bounds(x, y) || b.cells[y][x].disc != .None {return 0}
	total := 0
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			if dx == 0 && dy == 0 {continue}
			total += line_flips(b, x, y, dx, dy, player)
		}
	}
	return total
}

is_legal :: proc(b: ^Board, x, y: int, player: Disc) -> bool {
	return flip_count(b, x, y, player) > 0
}

has_move :: proc(b: ^Board, player: Disc) -> bool {
	for y in 0 ..< SIZE {
		for x in 0 ..< SIZE {
			if is_legal(b, x, y, player) {return true}
		}
	}
	return false
}

count_discs :: proc(b: ^Board, player: Disc) -> int {
	n := 0
	for row in b.cells {
		for c in row {
			if c.disc == player {n += 1}
		}
	}
	return n
}

// Plays the current player's disc at (x, y). A placed disc on a mine completes
// the normal move, then that square and its 8 neighbours explode (discs gone,
// mine removed). Turn passes to the opponent, or stays if the opponent has no
// move; the game is over if neither can move.
play :: proc(b: ^Board, x, y: int) -> Play_Result {
	res: Play_Result
	if b.status != .Playing || !is_legal(b, x, y, b.turn) {return res}
	player := b.turn
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			if dx == 0 && dy == 0 {continue}
			n := line_flips(b, x, y, dx, dy, player)
			for i in 1 ..= n {
				b.cells[y + dy * i][x + dx * i].disc = player
			}
			res.flipped += n
		}
	}
	b.cells[y][x].disc = player
	res.ok = true

	if b.cells[y][x].mine {
		res.exploded = true
		for dy in -1 ..= 1 {
			for dx in -1 ..= 1 {
				if in_bounds(x + dx, y + dy) {b.cells[y + dy][x + dx].disc = .None}
			}
		}
		b.cells[y][x].mine = false
	}

	other := opponent(player)
	if has_move(b, other) {
		b.turn = other
	} else if has_move(b, player) {
		res.passed = true
	} else {
		b.status = .Over
	}
	return res
}
