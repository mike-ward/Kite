import atprotocol
import ui
import gx

const main_id = 'kite'

@[heap]
struct App {
mut:
	session       atprotocol.Session
	window        &ui.Window = unsafe { nil }
	login_view    &ui.Widget = unsafe { nil }
	timeline_view &ui.Widget = unsafe { nil }
}

fn main() {
	mut app := &App{}
	settings := load_settings()

	app.login_view = create_login_view(mut app)
	app.timeline_view = create_timeline_view(mut app)

	if settings.session.access_jwt.len != 0 {
		app.session = settings.session
	}

	app.window = ui.window(
		height:   settings.height
		width:    settings.width
		title:    'Kite'
		bg_color: gx.rgb(0xee, 0xe9, 0xe9)
		children: [
			ui.column(
				id:       main_id
				margin:   ui.Margin{
					top:    1
					left:   3
					bottom: 1
					right:  1
				}
				heights:  [ui.stretch, ui.stretch]
				children: [app.login_view, app.timeline_view]
			),
		]
		on_init:  fn [mut app] (window &ui.Window) {
			if app.session.access_jwt.len > 0 {
				if mut stack := window.get[ui.Stack](main_id) {
					stack.remove(at: 0)
				}
				spawn start_timeline(mut app)
			}
		}
	)

	ui.run(app.window)
}
