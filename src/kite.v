import models { App, Settings }
import extra
import time
import ui

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
				id:         models.id_main_column
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
