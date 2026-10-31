#+build !js
package board

import "core:testing"

@(test)
start_position :: proc(t: ^testing.T) {
	b := new_board()
	testing.expect_value(t, count_discs(&b, .Black), 2)
	testing.expect_value(t, count_discs(&b, .White), 2)
	testing.expect_value(t, b.turn, Disc.Black)
	// Black's four opening moves.
	n := 0
	for y in 0 ..< SIZE {
		for x in 0 ..< SIZE {
			if is_legal(&b, x, y, .Black) {n += 1}
		}
	}
	testing.expect_value(t, n, 4)
}

@(test)
play_flips_and_passes_turn :: proc(t: ^testing.T) {
	b := new_board()
	// Black at (2,3)? cells[3][3] is White, [3][4] is Black: row 3 is W at x=3, B at x=4.
	res := play(&b, 2, 3)
	testing.expect(t, res.ok)
	testing.expect_value(t, res.flipped, 1)
	testing.expect_value(t, b.cells[3][3].disc, Disc.Black)
	testing.expect_value(t, b.turn, Disc.White)
}

@(test)
illegal_move_is_rejected :: proc(t: ^testing.T) {
	b := new_board()
	res := play(&b, 0, 0)
	testing.expect(t, !res.ok)
	testing.expect_value(t, b.turn, Disc.Black)
	testing.expect_value(t, b.cells[0][0].disc, Disc.None)
}

@(test)
mine_explodes_three_by_three :: proc(t: ^testing.T) {
	b := new_board()
	b.cells[3][2].mine = true // x=2, y=3
	res := play(&b, 2, 3)
	testing.expect(t, res.ok)
	testing.expect(t, res.exploded)
	testing.expect_value(t, res.flipped, 1) // the flip still happened before the blast
	testing.expect(t, !b.cells[3][2].mine)
	// 3x3 around (2,3) covers x 1..3, y 2..4: the flipped disc at (3,3) is gone.
	testing.expect_value(t, b.cells[3][3].disc, Disc.None)
	testing.expect_value(t, b.cells[3][2].disc, Disc.None)
	// Discs outside the blast survive.
	testing.expect_value(t, b.cells[3][4].disc, Disc.Black)
	testing.expect_value(t, b.cells[4][4].disc, Disc.White)
}

@(test)
game_over_when_no_one_can_move :: proc(t: ^testing.T) {
	b := new_board()
	b.cells[3][2].mine = true
	// Remove everything but one disc each side far apart, then blast.
	for y in 0 ..< SIZE {
		for x in 0 ..< SIZE {
			b.cells[y][x].disc = .None
		}
	}
	b.cells[0][0].disc = .Black
	b.cells[0][1].disc = .White
	// Black can play (2,0), flipping (1,0); nobody can move afterwards.
	res := play(&b, 2, 0)
	testing.expect(t, res.ok)
	testing.expect_value(t, b.status, Status.Over)
}

@(test)
pass_keeps_turn :: proc(t: ^testing.T) {
	b: Board
	b.turn = .Black
	// Row 0: B W _ _ ... ; row 1: B W _ ... Black plays (2,0); White then has no move
	// (no Black disc lies between White discs and an empty square), Black has (2,1).
	b.cells[0][0].disc = .Black
	b.cells[0][1].disc = .White
	b.cells[1][0].disc = .Black
	b.cells[1][1].disc = .White
	res := play(&b, 2, 0)
	testing.expect(t, res.ok)
	testing.expect(t, res.passed)
	testing.expect_value(t, b.turn, Disc.Black)
	testing.expect_value(t, b.status, Status.Playing)
}

@(test)
mines_avoid_central_block :: proc(t: ^testing.T) {
	for seed in 0 ..< u64(200) {
		b := new_board()
		r := rng_seed(seed)
		placed := place_mines(&b, 8, &r)
		testing.expect_value(t, placed, 8)
		for y in 2 ..= 5 {
			for x in 2 ..= 5 {
				testing.expect(t, !b.cells[y][x].mine)
			}
		}
	}
}

@(test)
place_mines_caps_when_full :: proc(t: ^testing.T) {
	b := new_board()
	r := rng_seed(1)
	placed := place_mines(&b, 100, &r) // only 48 squares are eligible
	testing.expect_value(t, placed, 48)
}

// One bit per square, bit y*SIZE+x set when it holds a mine.
mine_mask :: proc(seed: u64) -> (mask: u64) {
	b := new_board()
	r := rng_seed(seed)
	place_mines(&b, 8, &r)
	for y in 0 ..< SIZE {
		for x in 0 ..< SIZE {
			if b.cells[y][x].mine {mask |= u64(1) << uint(y * SIZE + x)}
		}
	}
	return
}

@(test)
same_seed_same_board :: proc(t: ^testing.T) {
	testing.expect_value(t, mine_mask(20261029), mine_mask(20261029))
	testing.expect(t, mine_mask(20261029) != mine_mask(20261030))
}

// Pins the daily puzzle for 20261029: if this changes, every player's board for
// that day changes too, so only edit it on purpose.
@(test)
daily_board_is_pinned :: proc(t: ^testing.T) {
	testing.expect_value(t, mine_mask(20261029), u64(6756498952716856))
}

@(test)
rng_known_values :: proc(t: ^testing.T) {
	r := rng_seed(0)
	testing.expect_value(t, rng_next(&r), u64(0xE220A8397B1DCDAF)) // splitmix64 reference, seed 0
	testing.expect_value(t, rng_next(&r), u64(0x6E789E6AA1B965F4))
}

@(test)
neighbour_count :: proc(t: ^testing.T) {
	b := new_board()
	b.cells[2][2].mine = true
	b.cells[4][2].mine = true
	b.cells[3][3].mine = true // not neighbour-counted for itself
	testing.expect_value(t, neighbour_mines(&b, 3, 3), 2)
	testing.expect_value(t, neighbour_mines(&b, 0, 0), 0)
}
