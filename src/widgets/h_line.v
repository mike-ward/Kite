module widgets

import ui
import gx

pub struct HLine implements ui.Widget {
	height int = 1
mut:
	ui         &ui.UI = unsafe { nil }
	id         string
	x          int
	y          int
	z_index    int
	offset_x   int
	offset_y   int
	hidden     bool
	parent     ui.Layout = ui.empty_stack
	width      int
	color      gx.Color
	text       string
	text_color gx.Color = gx.white
}

pub struct HLineParams {
pub:
	length     int
	offset_x   int
	offset_y   int
	color      gx.Color
	text       string
	text_color gx.Color = gx.white
}

pub fn h_line(c HLineParams) &HLine {
	h_line := HLine{
		width:      c.length
		offset_x:   c.offset_x
		offset_y:   c.offset_y
		color:      c.color
		text:       c.text
		text_color: c.text_color
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
	return hl.width, hl.height
}

fn (mut hl HLine) set_pos(x int, y int) {
	hl.x = x
	hl.y = y
}

fn (mut hl HLine) size() (int, int) {
	return hl.width + hl.offset_x, hl.height + hl.offset_y
}

fn (mut hl HLine) point_inside(x f64, y f64) bool {
	// vfmt off
        return x >= hl.x + hl.offset_x &&
               y >= hl.y + hl.offset_y &&
               x <= hl.x + hl.offset_x + hl.width &&
               y <= hl.y + hl.offset_y + hl.height
	// vfmt on
}

fn (mut hl HLine) set_visible(visible bool) {
	hl.hidden = !visible
}

fn (mut hl HLine) draw() {
	hl.draw_device(mut hl.ui.dd)
}

fn (mut hl HLine) draw_device(mut dd ui.DrawDevice) {
	x1 := hl.x + hl.offset_x
	y1 := hl.y + hl.offset_y
	x2 := x1 + hl.width
	y2 := y1 + hl.height

	w := dd.text_width(hl.text)
	x3 := x2 - w - 4
	yt := y2 - 8

	if hl.text.len > 0 {
		dd.draw_text(x3, yt, hl.text, gx.TextCfg{
			size:  12
			color: hl.text_color
		})
	}
	dd.draw_line(x1, y1, x3 - 2, y2, hl.color)
}
