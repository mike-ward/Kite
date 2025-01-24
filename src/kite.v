import atprotocol
import ui
import gx

const id_main_column = 'main-column'

@[heap]
struct App {
mut:
	window                &ui.Window = unsafe { nil }
	settings              Settings
	timeline              atprotocol.Timeline
	refresh_session_count int
	bg_color              gx.Color = gx.rgb(0x30, 0x30, 0x30)
	txt_color             gx.Color = gx.rgb(0xbb, 0xbb, 0xbb)
	txt_color_dim         gx.Color = gx.rgb(0x80, 0x80, 0x80)
	txt_color_bold        gx.Color = gx.rgb(0xfe, 0xfe, 0xfe)
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
		height:    app.settings.height
		width:     app.settings.width
		title:     'Kite'
		bg_color:  app.bg_color
		children:  [
			ui.column(
				id:         id_main_column
				heights:    [ui.stretch, ui.stretch]
				margin:     ui.Margin{
					left:  5
					right: 5
				}
				scrollview: true
				children:   [login_view, timeline_view]
			),
		]
		on_init:   fn [mut app] (_ &ui.Window) {
			if app.settings.is_valid() {
				remove_login_view(mut app)
				start_timeline(mut app)
			}
		}
		on_resize: fn [mut app] (_ &ui.Window, w int, h int) {
			build_timeline(mut app)
		}
	)

	ui.run(app.window)
}

fn remove_login_view(mut app App) {
	if mut stack := app.window.get[ui.Stack](id_main_column) {
		for stack.children.len > 1 {
			stack.remove(at: 0)
		}
	}
}
