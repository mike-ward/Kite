module widgets

import extra
import ui
import math
import sokol.sapp
import gx

const line_spacing_default = 5

pub type LinkLabelClickFn = fn ()

pub struct LinkLabel implements ui.Widget, ui.DrawTextWidget, ui.EnterLeaveWidget {
mut:
	text         string
	theme_style  string
	style        ui.LabelStyle
	style_params ui.LabelStyleParams
	line_height  int
	line_spacing int              = line_spacing_default
	on_click     LinkLabelClickFn = LinkLabelClickFn(0)
	word_wrap    bool
	is_over      bool
	// DrawTextWidget interface
	text_styles ui.TextStyles
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

pub struct LinkLabelParams {
	ui.LabelStyleParams
pub:
	id           string
	text         string
	theme        string           = ui.no_style
	line_spacing int              = line_spacing_default
	on_click     LinkLabelClickFn = LinkLabelClickFn(0)
	word_wrap    bool
}

pub fn link_label(c LinkLabelParams) &LinkLabel {
	mut ll := &LinkLabel{
		id:           c.id
		text:         c.text
		ui:           unsafe { nil }
		style_params: c.LabelStyleParams
		line_spacing: c.line_spacing
		on_click:     c.on_click
		word_wrap:    c.word_wrap
	}
	ll.style_params.style = c.theme
	return ll
}

fn (mut ll LinkLabel) init(parent ui.Layout) {
	ll.parent = parent
	ll.ui = parent.get_ui()
	ll.load_style()
	ll.set_size()
	if ll.on_click != LinkLabelClickFn(0) {
		mut subscriber := parent.get_subscriber()
		subscriber.subscribe_method(ui.events.on_click, ll_click, ll)
		subscriber.subscribe_method(ui.events.on_mouse_move, ll_mouse_move, ll)
	}
}

fn (mut ll LinkLabel) cleanup() {
	if ll.on_click != LinkLabelClickFn(0) {
		mut subscriber := ll.parent.get_subscriber()
		subscriber.unsubscribe_method(ui.events.on_click, ll)
		subscriber.unsubscribe_method(ui.events.on_mouse_move, ll)
	}
}

fn ll_mouse_move(mut ll LinkLabel, e &ui.MouseMoveEvent, window &ui.Window) {
	ll.is_over = ll.point_inside(e.x, e.y)
}

fn ll_click(mut ll LinkLabel, e &ui.MouseEvent, w &ui.Window) {
	if ll.point_inside(e.x, e.y) {
		ll.on_click()
	}
}

fn (mut ll LinkLabel) mouse_enter(e &ui.MouseMoveEvent) {
	if ll.on_click != LinkLabelClickFn(0) {
		sapp.set_mouse_cursor(sapp.MouseCursor.pointing_hand)
	}
}

fn (mut ll LinkLabel) mouse_leave(e &ui.MouseMoveEvent) {
	if ll.on_click != LinkLabelClickFn(0) {
		sapp.set_mouse_cursor(sapp.MouseCursor.default)
	}
}

fn (mut ll LinkLabel) set_pos(x int, y int) {
	ll.x = x
	ll.y = y
}

fn (mut ll LinkLabel) propose_size(w int, h int) (int, int) {
	ll.set_size()
	ll.ax, ll.ay = ll.width, ll.height
	return ll.width, ll.height
}

fn (mut ll LinkLabel) size() (int, int) {
	return ll.width, ll.height
}

fn (mut ll LinkLabel) point_inside(x f64, y f64) bool {
	// vfmt off
        return x >= ll.x &&
               y >= ll.y &&
               x <= ll.x + ll.width &&
               y <= ll.y + ll.height
	// vfmt on
}

fn (mut ll LinkLabel) set_visible(visible bool) {
	ll.hidden = !visible
}

fn (mut ll LinkLabel) draw() {
	ll.draw_device(mut ll.ui.dd)
}

fn (mut ll LinkLabel) draw_device(mut d ui.DrawDevice) {
	mut dtw := ui.DrawTextWidget(ll)
	dtw.draw_device_load_style(d)
	if ll.on_click != LinkLabelClickFn(0) {
		text_color := ll.style_params.text_color
		dtw.text_styles.current.color = match ll.is_over {
			true { dim_color(text_color) }
			else { text_color }
		}
	}
	for i, line in ll.text.split('\n') {
		dtw.draw_device_text(d, ll.x, ll.y + ll.line_height * i, line)
	}
}

// --- non-interface stuff

fn dim_color(color gx.Color) gx.Color {
	dim := 0.85
	return gx.rgb(u8(f64(color.r) * dim), u8(f64(color.g) * dim), u8(f64(color.b) * dim))
}

fn (mut ll LinkLabel) set_size() {
	if ll.word_wrap {
		mut dtw := ui.DrawTextWidget(ll)
		mut wp, _ := ll.parent.size()
		ll.text = extra.wrap_text(ll.text, wp - 10, mut dtw)
	}
	ll.width, ll.height = ll.adj_size()
}

fn (mut ll LinkLabel) adj_size() (int, int) {
	mut dtw := ui.DrawTextWidget(ll)
	dtw.load_style()
	mut w := 0
	mut h := 0
	ll.line_height = dtw.text_height('W') + ll.line_spacing
	for line in ll.text.split('\n') {
		w = if line.len > 0 { math.max(dtw.text_width(line), w) } else { w }
		h += ll.line_height
	}
	return w, h
}

fn (mut ll LinkLabel) load_style() {
	mut style := if ll.theme_style.len == 0 { ll.ui.window.theme_style } else { ll.theme_style }
	if ll.style_params.style != ui.no_style {
		style = ll.style_params.style
	}
	ll.update_theme_style(style)
	ll.update_style(ll.style_params)
}

fn (mut ll LinkLabel) update_theme_style(theme string) {
	// println("update_style <$p.style>")
	style := if theme.len == 0 { 'default' } else { theme }
	if style != ui.no_style && style in ll.ui.styles {
		ls := ll.ui.styles[style].label
		ll.theme_style = theme
		mut dtw := ui.DrawTextWidget(ll)
		dtw.update_theme_style(ls)
	}
}

fn (mut ll LinkLabel) update_style(p ui.LabelStyleParams) {
	mut dtw := ui.DrawTextWidget(ll)
	dtw.update_theme_style_params(p)
}
