#+build !js
package game

import "core:testing"
import "ont:board"

@(test)
click_on_title_buttons_starts :: proc(t: ^testing.T) {
	g := title()
	click(&g, 0, 0) // not on a button
	testing.expect_value(t, g.phase, Phase.Title)
	click(&g, BTN_X + 5, BTN_Y0 + 5)
	testing.expect_value(t, g.phase, Phase.Playing)
	testing.expect(t, !g.daily)
	g = title()
	g.today = 20261029
	click(&g, BTN_X + 5, BTN_Y1 + 5)
	testing.expect_value(t, g.phase, Phase.Playing)
	testing.expect(t, g.daily)
	testing.expect_value(t, g.seed, u64(20261029))
}

mines_of :: proc(g: ^Game) -> (mask: u64) {
	for y in 0 ..< board.SIZE {
		for x in 0 ..< board.SIZE {
			if g.b.cells[y][x].mine {mask |= u64(1) << uint(y * board.SIZE + x)}
		}
	}
	return
}

@(test)
daily_puzzle_is_the_same_every_time :: proc(t: ^testing.T) {
	a := title()
	a.today = 20261029
	a.clock = 111
	a.menu = 1
	start_selected(&a)
	b := title()
	b.today = 20261029
	b.clock = 999 // the clock must not matter for the daily
	b.menu = 1
	start_selected(&b)
	testing.expect_value(t, mines_of(&a), mines_of(&b))
	testing.expect_value(t, mines_of(&a), u64(562960691888962))
	b.today = 20261030
	start_selected(&b)
	testing.expect(t, mines_of(&a) != mines_of(&b))
}

@(test)
daily_games_replay_identically :: proc(t: ^testing.T) {
	// The same moves against the same seed give the same discs (the AI is seeded too).
	play_out :: proc() -> (black, white: int) {
		g := title()
		start(&g, 20261029, true)
		for _ in 0 ..< 200 {
			if g.phase != .Playing {break}
			if g.b.turn == HUMAN {
				// First legal square in reading order.
				moved := false
				for y in 0 ..< board.SIZE {
					for x in 0 ..< board.SIZE {
						if !moved && board.is_legal(&g.b, x, y, HUMAN) {moved = make_move(&g, x, y)}
					}
				}
			} else {
				update(&g, AI_DELAY + 0.01)
			}
		}
		return board.count_discs(&g.b, .Black), board.count_discs(&g.b, .White)
	}
	b1, w1 := play_out()
	b2, w2 := play_out()
	testing.expect_value(t, b1, b2)
	testing.expect_value(t, w1, w2)
}

@(test)
title_menu_by_keys :: proc(t: ^testing.T) {
	g := title()
	g.today = 20261029
	input(&g, .Down)
	testing.expect_value(t, g.menu, 1)
	input(&g, .Up)
	testing.expect_value(t, g.menu, 0)
	input(&g, .Down)
	input(&g, .Confirm)
	testing.expect_value(t, g.phase, Phase.Playing)
	testing.expect(t, g.daily)
}

@(test)
game_over_returns_to_title :: proc(t: ^testing.T) {
	g := title()
	start(&g, 1, false)
	g.phase = .Over
	click(&g, 70, 90)
	testing.expect_value(t, g.phase, Phase.Title)
}

@(test)
human_move_then_ai_replies :: proc(t: ^testing.T) {
	g := title()
	start(&g, 1, false)
	// Clear mines so the opening is deterministic.
	for &row in g.b.cells {
		for &c in row {c.mine = false}
	}
	// Black's opening move at (2,3): tile column 2, row 3.
	click(&g, BOARD_X + 2 * TILE + 1, BOARD_Y + 3 * TILE + 1)
	testing.expect_value(t, g.b.turn, board.Disc.White)
	update(&g, AI_DELAY + 0.01)
	testing.expect_value(t, g.b.turn, board.Disc.Black)
	testing.expect(t, board.count_discs(&g.b, .White) >= 1)
}

@(test)
click_outside_board_is_ignored :: proc(t: ^testing.T) {
	g := title()
	start(&g, 1, false)
	click(&g, 2, 2)
	click(&g, BOARD_X + 9 * TILE, BOARD_Y)
	testing.expect_value(t, g.b.turn, board.Disc.Black)
	testing.expect_value(t, board.count_discs(&g.b, .Black), 2)
}

@(test)
sounds_queue_in_order :: proc(t: ^testing.T) {
	g := title()
	queue_sound(&g, .Place)
	queue_sound(&g, .Boom)
	s, ok := take_sound(&g)
	testing.expect(t, ok)
	testing.expect_value(t, s, Sound.Place)
	s, ok = take_sound(&g)
	testing.expect_value(t, s, Sound.Boom)
	_, ok = take_sound(&g)
	testing.expect(t, !ok)
}

@(test)
cursor_moves_clamps_and_confirm_plays :: proc(t: ^testing.T) {
	g := title()
	start(&g, 1, false)
	testing.expect_value(t, g.phase, Phase.Playing)
	for &row in g.b.cells {
		for &c in row {c.mine = false}
	}
	testing.expect_value(t, g.cursor, [2]int{3, 2})
	input(&g, .Left)
	testing.expect_value(t, g.cursor, [2]int{2, 2})
	input(&g, .Down) // (2,3) is a legal opening move
	input(&g, .Confirm)
	testing.expect_value(t, g.b.turn, board.Disc.White)
	for _ in 0 ..< 20 {input(&g, .Up)}
	for _ in 0 ..< 20 {input(&g, .Left)}
	testing.expect_value(t, g.cursor, [2]int{0, 0})
	for _ in 0 ..< 20 {input(&g, .Down)}
	for _ in 0 ..< 20 {input(&g, .Right)}
	testing.expect_value(t, g.cursor, [2]int{7, 7})
}

@(test)
confirm_on_illegal_cell_does_nothing :: proc(t: ^testing.T) {
	g := title()
	start(&g, 1, false)
	g.cursor = {0, 0}
	input(&g, .Confirm)
	testing.expect_value(t, g.b.turn, board.Disc.Black)
	testing.expect_value(t, board.count_discs(&g.b, .Black), 2)
}
