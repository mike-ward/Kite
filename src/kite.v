module main

import gx
import ui

const id_main_column = 'main-column'

fn main() {
	mut app := &App{}
	app.settings = load_settings()
	valid_settings := app.settings.is_valid()

	if valid_settings {
		refresh_session(mut app)
	}

	app.login_view = create_login_view(mut app)
	app.timeline_view = create_timeline_view(mut app)
	view := if valid_settings { app.timeline_view } else { app.login_view }

	app.window = ui.window(
		height:   app.settings.height
		width:    app.settings.width
		title:    'Kite'
		bg_color: app.bg_color
		children: [
			ui.column(
				id:         id_main_column
				scrollview: true
				margin:     ui.Margin{0, 0, 0, 10}
				heights:    [ui.stretch]
				children:   [view]
			),
		]
		on_init:  fn [mut app] (_ &ui.Window) {
			if app.settings.is_valid() {
				start_timeline(mut app)
			}
		}
	)

	ui.run(app.window)
}

fn change_view(view &ui.Widget, app App) {
	if mut stack := app.window.get[ui.Stack](id_main_column) {
		stack.children = []
		stack.add(children: [view])
	}
}
