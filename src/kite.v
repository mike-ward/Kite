import atprotocol
import extra
// ---
import gx
import sync
import time
import ui

const id_main_column = 'main-column'

@[heap]
struct App {
mut:
	window                &ui.Window = unsafe { nil }
	settings              Settings
	timeline              atprotocol.Timeline
	timeline_mutex        &sync.RwMutex = sync.new_rwmutex()
	refresh_session_count int
	timeline_started      bool
	bg_color              gx.Color = gx.rgb(0x30, 0x30, 0x30)
	txt_color             gx.Color = gx.rgb(0xbb, 0xbb, 0xbb)
	txt_color_dim         gx.Color = gx.rgb(0x80, 0x80, 0x80)
	txt_color_bold        gx.Color = gx.rgb(0xfe, 0xfe, 0xfe)
	txt_color_link        gx.Color = gx.rgb(0x64, 0x95, 0xed)
}

fn main() {
	mut app := &App{}
	app.settings = load_settings()

	if app.settings.is_valid() {
		refresh_session(mut app)
	}

	login_view := create_login_view(mut app)
	timeline_view := create_timeline_view(mut app)

	build_timeline_debounced := extra.debounce(fn [mut app] () {
		app.timeline_mutex.rlock()
		build_timeline(app.timeline, mut app)
		app.timeline_mutex.runlock()
	}, time.millisecond * 400)

	app.window = ui.window(
		height:    app.settings.height
		width:     app.settings.width
		title:     'Kite'
		bg_color:  app.bg_color
		children:  [
			ui.column(
				id:         id_main_column
				scrollview: true
				margin:     ui.Margin{0, 0, 0, 10}
				heights:    [ui.stretch, ui.stretch]
				children:   [login_view, timeline_view]
			),
		]
		on_init:   fn [mut app] (_ &ui.Window) {
			if app.settings.is_valid() {
				remove_login_view(mut app)
				start_timeline(mut app)
			}
		}
		on_resize: fn [build_timeline_debounced] (_ &ui.Window, w int, h int) {
			build_timeline_debounced()
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
