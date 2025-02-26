module widgets

import gx
import ui
import math
import sokol.sapp

pub type UpButtonClickFn = fn (&UpButton)

@[heap]
pub struct UpButton implements ui.Widget {
pub mut:
	radius   int
	bg_color gx.Color
	fg_color gx.Color
	br_color gx.Color
	is_over  bool
	on_click UpButtonClickFn = UpButtonClickFn(0)
	notice   bool
	// Widget interface
	ui       &ui.UI = unsafe { nil }
	id       string
	x        int
	y        int
	ax       int
	ay       int
	justify  []f64
	width    int
	height   int
	z_index  int
	offset_x int
	offset_y int
	hidden   bool
	clipping bool
	parent   ui.Layout = ui.empty_stack
}

pub struct UpButtonParams {
pub:
	id           string
	x            int
	y            int
	radius       int
	bg_color     gx.Color
	fg_color     gx.Color = gx.white
	border_color gx.Color
	on_click     UpButtonClickFn = UpButtonClickFn(0)
}

pub fn up_button(c UpButtonParams) &UpButton {
	return &UpButton{
		id:       c.id
		x:        c.x
		y:        c.y
		radius:   c.radius
		bg_color: c.bg_color
		fg_color: c.fg_color
		br_color: c.border_color
		on_click: c.on_click
	}
}

pub fn (mut ub UpButton) init(parent ui.Layout) {
	ub.parent = parent
	ub.ui = parent.get_ui()
	if ub.on_click != UpButtonClickFn(0) {
		mut subscriber := parent.get_subscriber()
		subscriber.subscribe_method(ui.events.on_click, ub_click, ub)
		subscriber.subscribe_method(ui.events.on_mouse_move, ub_mouse_move, ub)
	}
}

// ll_mouse_move called only if on_click is set
fn ub_mouse_move(mut ub UpButton, e &ui.MouseMoveEvent, window &ui.Window) {
	if ub.has_focus() && !ub.hidden {
		is_over := ub.point_inside(e.x, e.y)
		if is_over && !ub.is_over {
			sapp.set_mouse_cursor(sapp.MouseCursor.pointing_hand)
			ub.is_over = true
		}
		if !is_over && ub.is_over {
			sapp.set_mouse_cursor(sapp.MouseCursor.default)
			ub.is_over = false
		}
	}
}

fn ub_click(mut ub UpButton, e &ui.MouseEvent, w &ui.Window) {
	if ub.point_inside(e.x, e.y) && !ub.hidden {
		ub.on_click(ub)
	}
}

fn (mut ub UpButton) cleanup() {
	if ub.on_click != UpButtonClickFn(0) {
		mut subscriber := ub.parent.get_subscriber()
		subscriber.unsubscribe_method(ui.events.on_click, ub)
		subscriber.unsubscribe_method(ui.events.on_mouse_move, ub)
	}
}

pub fn (mut ub UpButton) set_pos(x int, y int) {
	if x != 0 && y != 0 {
		ub.x = x
		ub.y = y
	}
}

pub fn (mut ub UpButton) size() (int, int) {
	return ub.width, ub.height
}

fn (mut ub UpButton) propose_size(w int, h int) (int, int) {
	return w, h
}

fn (mut ub UpButton) point_inside(x f64, y f64) bool {
	dx := math.abs(x - ub.x)
	dy := math.abs(y - ub.y)
	return dx * dx + dy * dy <= ub.radius * ub.radius
}

pub fn (mut ub UpButton) set_visible(state bool) {
	ub.hidden = !state
}

fn (mut ub UpButton) draw() {
	ub.draw_device(mut ub.ui.dd)
}

fn (mut ub UpButton) draw_device(mut d ui.DrawDevice) {
	if ub.hidden {
		return
	}
	d.draw_circle_filled(ub.x, ub.y, ub.radius, ub.bg_color)
	for i in 0 .. 3 {
		d.draw_circle_empty(ub.x, ub.y, ub.radius - i, ub.br_color)
	}
	// draw an upside down V in the center of button
	ln := f32(ub.radius) / 3 // length of one size of V
	xc := f32(ub.x)
	yt := f32(ub.y) - ln
	yb := f32(ub.y) + ln
	xl := xc - ln
	xr := xc + ln

	d.draw_line(xc, yt, xl, yb, ub.fg_color)
	d.draw_line(xc, yt, xr, yb, ub.fg_color)
	d.draw_line(xc - 1, yt, xl - 1, yb, ub.fg_color)
	d.draw_line(xc + 1, yt, xr + 1, yb, ub.fg_color)

	// Notice indictor is small dot
	if ub.notice {
		d.draw_circle_filled(ub.x, yt + 4, 6, ub.br_color)
	}
}

fn (ub UpButton) has_focus() bool {
	return ub.ui.window.locked_focus.len > 0
}
