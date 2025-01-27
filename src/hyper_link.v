import ui

struct Hyperlink {
	id       string
	on_click fn (&Hyperlink) = unsafe { nil }
	layout   &ui.Stack       = unsafe { nil } // required
}

struct HyperlinkParams {
	ui.LabelParams
	on_click fn (&Hyperlink) = unsafe { nil }
}

pub fn hyperlink(c HyperlinkParams) &ui.Stack {
	label := ui.label(c.LabelParams)
	mut stack := &ui.Stack{
		id:       ui.component_id(c.id, 'stack')
		width:    c.width
		height:   c.height
		children: [label]
	}

	hyperlink := &Hyperlink{
		id:       ui.component_id(c.id, 'hyperlink')
		on_click: c.on_click
		layout:   stack
	}
	ui.component_connect(hyperlink, stack, label)
	stack.on_init = init
	return stack
}

fn hyperlink_component(w ui.ComponentChild) &Hyperlink {
	return unsafe { &Hyperlink(w.component) }
}

fn init(layout &ui.Stack) {
	h := hyperlink_component(layout)
	mut subscriber := h.layout.parent.get_subscriber()
	subscriber.subscribe_method(ui.events.on_click, btn_click, h)
}

fn btn_click(h &Hyperlink, e &ui.MouseEvent, w &ui.Window) {
	if h.point_inside(e.x, e.y) {
		if h.on_click != unsafe { nil } {
			h.on_click(h)
		} else {
			println('click')
		}
	}
}

fn (h &Hyperlink) point_inside(x f64, y f64) bool {
	l := h.layout
	return x >= l.x && x <= l.x + l.width && y >= l.y && y <= l.y + l.height
}
