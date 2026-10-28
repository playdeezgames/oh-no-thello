// Thin browser layer: input, drawing and the frame loop. Rules and state live in package game.
#+build js
package main

import "base:runtime"
import "ont:board"
import "ont:game"

foreign import canvas "canvas"
@(default_calling_convention = "contextless")
foreign canvas {
	// rgb is 0xRRGGBB; coordinates are logical pixels, y down.
	fill_rect :: proc(x, y, w, h: f32, rgb: u32, alpha: f32) ---
	// A sprite from the atlas (build/web/art.png) with its top-left at x, y.
	blit :: proc(sprite: i32, x, y: f32, alpha: f32) ---
	play_sound :: proc(sound: i32) ---
	// Bitmap text (m5x7). y is the baseline; scale is a whole number; x is the centre when centered.
	draw_text :: proc(x, y: f32, text: string, rgb: u32, scale: i32, centered: bool) ---
}

WHITE :: 0xf2f2f2
DIM :: 0x9ab8a2
GOLD :: 0xf5d33f
BACKDROP :: 0x0d2a18
STAR :: 0x0a1f12

ctx: runtime.Context
state: game.Game

main :: proc() {
	ctx = context
	state = game.title()
}

@(export)
click :: proc "c" (x, y: i32) {
	context = ctx
	game.click(&state, int(x), int(y))
}

@(export)
input :: proc "c" (action: i32) {
	context = ctx
	game.input(&state, game.Action(action))
}

@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	context = ctx
	game.update(&state, f32(dt))
	for {
		s, ok := game.take_sound(&state)
		if !ok {break}
		play_sound(i32(s))
	}
	draw()
	return true
}

sprite_at :: proc(s: game.Sprite, x, y: int, alpha: f32 = 1) {
	blit(i32(s), f32(x), f32(y), alpha)
}

draw :: proc() {
	g := &state
	fill_rect(0, 0, game.LOGICAL_W, game.LOGICAL_H, BACKDROP, 1)
	b := &g.b
	human_turn := g.phase == .Playing && b.turn == game.HUMAN

	for y in 0 ..< board.SIZE {
		for x in 0 ..< board.SIZE {
			px := game.BOARD_X + x * game.TILE
			py := game.BOARD_Y + y * game.TILE
			sprite_at(.Felt, px, py)
			cell := b.cells[y][x]
			switch cell.disc {
			case .Black:
				sprite_at(.Disc_Black, px, py)
			case .White:
				sprite_at(.Disc_White, px, py)
			case .None:
				if human_turn && board.is_legal(b, x, y, game.HUMAN) {
					sprite_at(.Hint, px, py, 0.7)
				}
				if game.show_mines(g) && cell.mine {sprite_at(.Mine, px, py)}
			}
			if cell.disc != .None {
				if n := board.neighbour_mines(b, x, y); n > 0 {
					sprite_at(game.Sprite(int(game.Sprite.N1) + n - 1), px, py)
				}
			}
			if t := g.booms[y][x]; t > 0 {
				sprite_at(.Boom, px, py, min(1, t / game.BOOM_TIME * 1.5))
			}
		}
	}

	// The four star points of a Reversi board, where grid lines cross (3x3 dots).
	for k in ([2]int{2, 6}) {
		for m in ([2]int{2, 6}) {
			cx := game.BOARD_X + k * game.TILE - 1
			cy := game.BOARD_Y + m * game.TILE - 1
			fill_rect(f32(cx - 1), f32(cy - 1), 3, 3, STAR, 1)
		}
	}

	if g.cursor_on && g.phase == .Playing {
		cx := f32(game.BOARD_X + g.cursor.x * game.TILE)
		cy := f32(game.BOARD_Y + g.cursor.y * game.TILE)
		fill_rect(cx, cy, game.TILE - 1, 1, GOLD, 1)
		fill_rect(cx, cy + game.TILE - 2, game.TILE - 1, 1, GOLD, 1)
		fill_rect(cx, cy, 1, game.TILE - 1, GOLD, 1)
		fill_rect(cx + game.TILE - 2, cy, 1, game.TILE - 1, GOLD, 1)
	}

	switch g.phase {
	case .Title:
		fill_rect(0, 0, game.LOGICAL_W, game.LOGICAL_H, 0x000000, 0.62)
		draw_text(72, 52, "OH NO,", GOLD, 3, true)
		draw_text(72, 80, "THELLO!", GOLD, 3, true)
		draw_text(72, 100, "reversi + minesweeper", WHITE, 1, true)
		draw_text(72, 120, "8 mines hide in the board.", DIM, 1, true)
		draw_text(72, 130, "A disc shows how many are", DIM, 1, true)
		draw_text(72, 140, "next to it. Place one on a", DIM, 1, true)
		draw_text(72, 150, "mine and 3x3 blows up!", DIM, 1, true)
		draw_text(72, 168, "tap, click or press Enter", WHITE, 1, true)
	case .Playing, .Over:
		me := board.count_discs(b, game.HUMAN)
		ai := board.count_discs(b, board.opponent(game.HUMAN))
		draw_text(8, 12, "YOU", WHITE, 1, false)
		sprite_at(.Disc_Black, 30, 0)
		draw_num(me, 48, 12)
		sprite_at(.Disc_White, 100, 0)
		draw_num(ai, 118, 12)
		msg: string
		colour: u32 = WHITE
		if g.phase == .Over {
			colour = GOLD
			switch {
			case me > ai: msg = "YOU WIN! tap to replay"
			case me < ai: msg = "WHITE WINS. tap to replay"
			case: msg = "A DRAW. tap to replay"
			}
		} else if g.note != "" {
			msg = g.note
			colour = GOLD
		} else if human_turn {
			msg = state.cursor_on ? "your move (Enter places)" : "your move"
		} else {
			msg = "white is thinking..."
			colour = DIM
		}
		draw_text(72, 168, msg, colour, 1, true)
	}
}

// Small decimal number, left-aligned at x.
draw_num :: proc(n: int, x, y: f32) {
	buf: [8]u8
	i := len(buf)
	v := n
	if v == 0 {
		i -= 1
		buf[i] = '0'
	}
	for v > 0 && i > 0 {
		i -= 1
		buf[i] = u8('0' + v % 10)
		v /= 10
	}
	draw_text(x, y, string(buf[i:]), WHITE, 1, false)
}
