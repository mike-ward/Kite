module widgets

import extra
import ui
import math

const line_spacing_default = 5

pub struct LinkLabel implements ui.Widget, ui.DrawTextWidget {
mut:
	text         string
	adj_width    int
	adj_height   int
	theme_style  string
	style        ui.LabelStyle
	style_params ui.LabelStyleParams
	line_spacing int   = line_spacing_default
	on_click     fn () = unsafe { nil }
	word_wrap    bool
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
	width        int
	height       int
	z_index      int
	clipping     bool
	justify      []f64 = [0.0, 0.0]
	text         string
	theme        string = ui.no_style
	line_spacing int    = line_spacing_default
	on_click     fn ()  = unsafe { nil }
	word_wrap    bool
}

pub fn link_label(c LinkLabelParams) &LinkLabel {
	mut ll := &LinkLabel{
		id:           c.id
		text:         c.text
		width:        c.width
		height:       c.height
		ui:           unsafe { nil }
		z_index:      c.z_index
		clipping:     c.clipping
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
	if ll.on_click != unsafe { nil } {
		mut subscriber := parent.get_subscriber()
		subscriber.subscribe_method(ui.events.on_click, btn_click, ll)
	}
}

fn (mut ll LinkLabel) cleanup() {
	if ll.on_click != unsafe { nil } {
		mut subscriber := ll.parent.get_subscriber()
		subscriber.unsubscribe_method(ui.events.on_click, ll)
	}
}

fn btn_click(mut ll LinkLabel, e &ui.MouseEvent, w &ui.Window) {
	if ll.point_inside(e.x, e.y) {
		ll.on_click()
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
	return x >= ll.x && x <= ll.x + ll.width && y >= ll.y && y <= ll.y + ll.height
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
	height := dtw.text_height('W')
	for i, split in ll.text.split('\n') {
		if split.len > 0 {
			spacing := i * ll.line_spacing
			dtw.draw_device_text(d, ll.x, ll.y + (height * i) + spacing, split)
		}
	}
}

// ---------

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
	line_height := dtw.text_height('W') + ll.line_spacing
	mut w := 0
	mut h := 0
	if ll.text.contains('\n') {
		for line in ll.text.split('\n') {
			w = if line.len > 0 { math.max(dtw.text_width(line), w) } else { w }
			h += line_height
		}
	} else {
		w = dtw.text_width(if ll.text.len > 0 { ll.text } else { ' ' })
		h = line_height
	}
	ll.adj_width = w
	ll.adj_height = h
	return ll.adj_width, ll.adj_height
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
