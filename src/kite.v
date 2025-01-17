import ui
import gx

const id_main_column = 'main-column'

@[heap]
struct App {
mut:
	window        &ui.Window = unsafe { nil }
	settings      Settings
	refresh_count int
}

fn main() {
	mut app := &App{}
	app.settings = load_settings()

	if app.settings.session.access_jwt.len > 0 {
		refresh_session(mut app)
	}

	login_view := create_login_view(mut app)
	timeline_view := create_timeline_view(mut app)

	app.window = ui.window(
		height:   app.settings.height
		width:    app.settings.width
		title:    'Kite'
		bg_color: gx.rgb(0xd6, 0xea, 0xf8)
		children: [
			ui.column(
				id:       id_main_column
				margin:   ui.Margin{
					top:    1
					left:   3
					bottom: 1
					right:  1
				}
				heights:  [ui.stretch, ui.stretch]
				children: [login_view, timeline_view]
			),
		]
		on_init:  fn [mut app] (window &ui.Window) {
			if mut stack := window.get[ui.Stack](id_main_column) {
				if app.settings.session.access_jwt.len > 0 {
					// remove login_view
					stack.remove(at: 0)
				}
				spawn start_timeline(mut app)
			}
		}
	)

	ui.run(app.window)
}
