import ui

const line_spacing_default = 5

struct LinkLabel {
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
	width    int
	height   int
	z_index  int
	offset_x int
	offset_y int
	hidden   bool
	clipping bool
	parent   ui.Layout = ui.empty_stack
}

struct LinkLabelParams {
	ui.LabelStyleParams
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

fn link_label(c LinkLabelParams) &LinkLabel {
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
	if ll.word_wrap {
		mut dtw := ui.DrawTextWidget(ll)
		mut w, _ := parent.size()
		ll.text = wrap_text(ll.text, w - 10, mut dtw)
	}
	ll.init_size()
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
		if ll.on_click != unsafe { nil } {
			ll.on_click()
		}
	}
}

fn (mut ll LinkLabel) set_pos(x int, y int) {
	ll.x = x
	ll.y = y
}

fn (mut ll LinkLabel) propose_size(w int, h int) (int, int) {
	ll.width = w
	ll.height = h
	return w, h
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
		spacing := i * ll.line_spacing
		dtw.draw_device_text(d, ll.x, ll.y + (height * i) + spacing, split)
	}
}

// ---------

fn (mut ll LinkLabel) adj_size() (int, int) {
	if ll.adj_width == 0 || ll.adj_height == 0 {
		mut dtw := ui.DrawTextWidget(ll)
		dtw.load_style()
		mut w := 0
		mut h := 0
		if !ll.text.contains('\n') {
			w = dtw.text_width(ll.text)
			h = dtw.text_height('W') + ll.line_spacing
		} else {
			for line in ll.text.split('\n') {
				wi := dtw.text_width(line)
				if wi > w {
					w = wi
				}
				h += dtw.text_height('W') + ll.line_spacing
			}
		}
		ll.adj_width = w
		ll.adj_height = h
	}
	return ll.adj_width, ll.adj_height
}

fn (mut ll LinkLabel) init_size() {
	w, h := ll.adj_size()
	if ll.width == 0 {
		ll.width = w
	}
	if ll.height == 0 {
		ll.height = h
	}
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
