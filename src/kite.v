import gx
import ui

const id_main_column = 'main-column'

@[heap]
struct App {
mut:
	window                &ui.Window = unsafe { nil }
	settings              Settings
	refresh_session_count int
	timeline_started      bool
	login_view            &ui.Widget = unsafe { nil }
	timeline_view         &ui.Widget = unsafe { nil }
	bg_color              gx.Color   = gx.rgb(0x30, 0x30, 0x30)
	txt_color             gx.Color   = gx.rgb(0xbb, 0xbb, 0xbb)
	txt_color_dim         gx.Color   = gx.rgb(0x80, 0x80, 0x80)
	txt_color_bold        gx.Color   = gx.rgb(0xfe, 0xfe, 0xfe)
	txt_color_link        gx.Color   = gx.rgb(0x64, 0x95, 0xed)
}

fn main() {
	mut app := &App{}
	app.settings = Settings.load_settings()
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
