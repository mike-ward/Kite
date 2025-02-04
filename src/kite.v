import extra
import gx
import sync
import time
import ui

const id_main_column = '_main-column_'

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
	hline_color           gx.Color    = gx.rgb(0x50, 0x50, 0x50)
}

fn main() {
	mut app := &App{}
	app.settings = Settings.load_settings()

	if app.settings.is_valid() {
		refresh_session(mut app)
	}

	save_settings_debounced := extra.debounce(fn [mut app] () {
		app.settings.save_settings()
	}, time.second)

	view := match app.settings.is_valid() {
		true { create_timeline_view() }
		else { create_login_view(mut app) }
	}

	app.window = ui.window(
		height:    app.settings.height
		width:     app.settings.width
		title:     'Kite'
		bg_color:  app.bg_color
		min_width: 300
		children:  [
			ui.column(
				id:         id_main_column
				scrollview: true
				margin:     ui.Margin{0, 0, 0, 10}
				heights:    [ui.stretch]
				children:   [view]
			),
		]
		on_init:   fn [mut app] (_ &ui.Window) {
			if app.settings.is_valid() {
				start_timeline(mut app)
			}
		}
		on_resize: fn [mut app, save_settings_debounced] (_ &ui.Window, w int, h int) {
			app.settings = Settings{
				...app.settings
				width:  w
				height: h
			}
			save_settings_debounced()
		}
		on_draw:   fn [mut app] (w &ui.Window) {
			// Updates need to occur on UI thread
			draw_timeline(w, mut app)
		}
	)

	ui.run(app.window)
}

fn (app App) change_view(view &ui.Widget) {
	if mut stack := app.window.get[ui.Stack](id_main_column) {
		stack.remove()
		stack.add(children: [view])
	} else {
		eprintln('${@METHOD}(): id_main_column not found')
	}
}
