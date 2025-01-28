import ui

const line_spacing_default = 4

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
	// DrawTextWidget interface
	text_styles ui.TextStyles
	// Adjustable interface
	justify []f64
	ax      int // offset for adjusted x
	ay      int // offset for adjusted x
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
		justify:      c.justify
		style_params: c.LabelStyleParams
		line_spacing: c.line_spacing
		on_click:     c.on_click
	}
	ll.style_params.style = c.theme
	return ll
}

fn (mut ll LinkLabel) init(parent ui.Layout) {
	ll.parent = parent
	ll.ui = parent.get_ui()
	ll.load_style()
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

fn (mut ll LinkLabel) set_visible(v bool) {
	ll.hidden = !v
}

fn (mut ll LinkLabel) draw() {
	ll.draw_device(mut ll.ui.dd)
}

fn (mut ll LinkLabel) draw_device(mut d ui.DrawDevice) {
	mut dtw := ui.DrawTextWidget(ll)
	adj_pos_x, adj_pos_y := ll.get_adjusted_pos()
	height := ll.ui.dd.text_height('W')
	dtw.draw_device_load_style(d)
	for i, split in ll.text.split('\n') {
		spacing := i * ll.line_spacing
		dtw.draw_device_text(d, adj_pos_x, adj_pos_y + (height * i) + spacing, split)
	}
}

// ---------

fn (mut ll LinkLabel) adj_size() (int, int) {
	if ll.adj_width == 0 || ll.adj_height == 0 {
		mut dtw := ui.DrawTextWidget(ll)
		dtw.load_style()
		mut w, mut h := 0, 0
		if !ll.text.contains('\n') {
			w = dtw.text_width(ll.text)
			h = dtw.current_style().size + ll.line_spacing
		} else {
			for line in ll.text.split('\n') {
				wi, he := dtw.text_size(line)
				if wi > w {
					w = wi
				}
				h += he + ll.line_spacing
			}
		}

		ll.adj_width, ll.adj_height = w, h
	}
	return ll.adj_width, ll.adj_height
}

fn (mut ll LinkLabel) init_size() {
	if ll.width == 0 {
		ll.width, _ = ll.adj_size()
	}
	if ll.height == 0 {
		_, ll.height = ll.adj_size()
	}
}

fn (mut ll LinkLabel) get_adjusted_pos() (int, int) {
	return ll.x, ll.y
}

fn (mut ll LinkLabel) load_style() {
	mut style := if ll.theme_style == '' { ll.ui.window.theme_style } else { ll.theme_style }
	if ll.style_params.style != ui.no_style {
		style = ll.style_params.style
	}
	ll.update_theme_style(style)
	ll.update_style(ll.style_params)
}

fn (mut ll LinkLabel) update_theme_style(theme string) {
	// println("update_style <$p.style>")
	style := if theme == '' { 'default' } else { theme }
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
