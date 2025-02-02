import gx
import sync
import ui

const id_main_column = 'main-column'

@[heap]
struct App {
pub mut:
	window                &ui.Window = unsafe { nil }
	settings              Settings
	refresh_session_count int
	timeline_posts        []ui.Widget
	timeline_posts_mutex  &sync.Mutex = sync.new_mutex()
	bg_color              gx.Color    = gx.rgb(0x30, 0x30, 0x30)
	txt_color             gx.Color    = gx.rgb(0xbb, 0xbb, 0xbb)
	txt_color_dim         gx.Color    = gx.rgb(0x80, 0x80, 0x80)
	txt_color_bold        gx.Color    = gx.rgb(0xfe, 0xfe, 0xfe)
	txt_color_link        gx.Color    = gx.rgb(0x64, 0x95, 0xed)
}

fn main() {
	mut app := &App{}
	app.settings = Settings.load_settings()
	valid_settings := app.settings.is_valid()

	if valid_settings {
		refresh_session(mut app)
	}

	view := if valid_settings { create_timeline_view(mut app) } else { create_login_view(mut app) }

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
		on_draw:  fn [mut app] (w &ui.Window) {
			// Updates have to occurr on UI thread
			app.timeline_posts_mutex.unlock()
			if app.timeline_posts.len > 0 {
				if mut stack := w.get[ui.Stack](id_timeline) {
					for stack.children.len > 0 {
						stack.remove()
					}
					stack.add(children: app.timeline_posts)
					app.timeline_posts.clear()
				}
			}
			app.timeline_posts_mutex.unlock()
		}
	)

	ui.run(app.window)
}

fn (app App) change_view(view &ui.Widget) {
	if mut stack := app.window.get[ui.Stack](id_main_column) {
		stack.remove()
		stack.add(children: [view])
	}
}
