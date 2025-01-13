import atprotocol
import ui

@[heap]
struct App {
mut:
	window        &ui.Window = unsafe { nil }
	session       atprotocol.Session
	login_view    &ui.Widget = unsafe { nil }
	timeline_view &ui.Widget = unsafe { nil }
	timeline_text string
}

fn main() {
	mut app := &App{}
	// settings := load_settings()

	app.login_view = create_login_view(mut app)
	app.timeline_view = create_timeline_view(mut app)

	app.window = ui.window(
		height:   900
		width:    300
		title:    'Kite'
		children: [
			ui.column(
				id:       'kite'
				heights:  [ui.compact, ui.stretch]
				children: [app.login_view, app.timeline_view]
			),
		]
	)

	ui.run(app.window)
}
