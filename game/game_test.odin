#+build !js
package game

import "core:testing"
import "ont:board"

@(test)
click_on_title_starts :: proc(t: ^testing.T) {
	g := title()
	click(&g, 0, 0)
	testing.expect_value(t, g.phase, Phase.Playing)
}

@(test)
human_move_then_ai_replies :: proc(t: ^testing.T) {
	g := title()
	start(&g)
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
	start(&g)
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
