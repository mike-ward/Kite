module widgets

import ui
import gx

pub struct HLine implements ui.Widget {
mut:
	ui       &ui.UI = unsafe { nil }
	id       string
	x        int
	y        int
	z_index  int
	offset_x int
	offset_y int
	hidden   bool
	parent   ui.Layout = ui.empty_stack
	width    int
	height   int = 1
	color    gx.Color
}

pub struct HLineParams {
pub:
	width  int
	height int = 1
	color  gx.Color
}

pub fn h_line(c HLineParams) &HLine {
	h_line := HLine{
		width:  c.width
		height: c.height
		color:  c.color
	}
	return &h_line
}

fn (mut hl HLine) init(parent ui.Layout) {
	hl.parent = parent
	hl.ui = parent.get_ui()
}

fn (mut hl HLine) cleanup() {
}

fn (mut hl HLine) propose_size(w int, h int) (int, int) {
	hl.width = w
	hl.height = h
	return hl.width, hl.height
}

fn (mut hl HLine) set_pos(x int, y int) {
	hl.x = x
	hl.y = y
}

fn (mut hl HLine) size() (int, int) {
	return hl.width, hl.height
}

fn (mut hl HLine) point_inside(x f64, y f64) bool {
	// vfmt off
        return x >= hl.x &&
               y >= hl.y &&
               x <= hl.x + hl.width &&
               y <= hl.y + hl.height
	// vfmt on
}

fn (mut hl HLine) set_visible(visible bool) {
	hl.hidden = !visible
}

fn (mut hl HLine) draw() {
	hl.draw_device(mut hl.ui.dd)
}

fn (mut hl HLine) draw_device(mut d ui.DrawDevice) {
	width := hl.x + hl.width
	height := hl.y + hl.height
	d.draw_line(hl.x, hl.y, width, height, hl.color)
}
