import ui
import gx

const id_main_column = 'main-column'

@[heap]
struct App {
mut:
	window                &ui.Window = unsafe { nil }
	settings              Settings
	refresh_session_count int
	bg_color              gx.Color = gx.rgb(0x30, 0x30, 0x30)
	txt_color             gx.Color = gx.rgb(0xcc, 0xcc, 0xcc)
	txt_color_bright      gx.Color = gx.white
	border_color          gx.Color = gx.rgb(0x80, 0x80, 0x80)
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
		bg_color: app.bg_color
		children: [
			ui.column(
				id:       id_main_column
				heights:  [ui.stretch, ui.stretch]
				width:    app.settings.width - 5
				margin:   ui.Margin{
					left: 5
				}
				children: [login_view, timeline_view]
			),
		]
		on_init:  fn [mut app] (mut window ui.Window) {
			if app.settings.is_valid() {
				remove_login_view(mut app)
				start_timeline(mut app)
			}
		}
	)

	ui.run(app.window)
}

fn remove_login_view(mut app App) {
	if mut stack := app.window.get[ui.Stack](id_main_column) {
		if stack.children.len > 1 {
			stack.remove(at: 0)
		}
	}
}
