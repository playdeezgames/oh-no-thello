package main

import "base:runtime"
import "core:math/rand"
import "core:time"

foreign import canvas "canvas"

@(default_calling_convention = "contextless")
foreign canvas {
	clear_canvas :: proc(r, g, b: f32) ---
	fill_rect :: proc(x, y, w, h: f32, r, g, b, a: f32) ---
}

ctx: runtime.Context

main :: proc() {
	ctx = context
	rand.reset(u64(time.now()._nsec))
}

@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	context = ctx
	clear_canvas(0.1, 0.4, 0.2)
	fill_rect(10, 10, 100, 100, 1, 1, 1, 1)
	return true
}
