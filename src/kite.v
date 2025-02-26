import models { App, Settings }
import views
import extra
import time
import ui

fn main() {
	extra.install_kite_segmentation_fault_handler()

	mut app := &App{}
	app.settings = Settings.load_settings()

	if app.settings.is_valid() {
		app.refresh_session()
	}

	save_settings_debounced := extra.debounce(fn [mut app] () {
		app.settings.save_settings()
	}, time.second)

	view := match app.settings.is_valid() {
		true { views.create_timeline_view(mut app) }
		else { views.create_login_view(mut app) }
	}

	app.window = ui.window(
		height:        app.settings.height
		width:         app.settings.width
		title:         'Kite'
		bg_color:      app.bg_color
		min_width:     300
		children:      [
			ui.column(
				id:       models.id_main_column
				heights:  [ui.stretch]
				children: [view]
			),
		]
		on_init:       fn [mut app] (_ &ui.Window) {
			if app.settings.is_valid() {
				app.start_timeline(views.build_timeline_posts)
			}
		}
		on_resize:     fn [mut app, save_settings_debounced] (win &ui.Window, w int, h int) {
			app.settings = Settings{
				...app.settings
				width:  w
				height: h
			}
			save_settings_debounced()

			// Timeline view draws at scroll pos zero instead of the current
			// scroll pos on resizes. Likely a bug in VUI. For now, setting
			// the scroll pos manually forces Timeline view to draw at the
			// desired scroll pos
			if mut sv_stack := win.get[ui.Stack](views.id_timeline_scrollview) {
				sv_stack.scrollview.set(sv_stack.scrollview.offset_y, .btn_y)
			}
		}
		on_draw:       fn [mut app] (mut w ui.Window) {
			// Updates need to occur on UI thread
			views.draw_timeline(mut w, mut app)
		}
		on_focus:      fn (mut w ui.Window) {
			// cheap, hacky way to know if window has focus
			// until framework gets something better
			w.locked_focus = 'y'
		}
		on_unfocus:    fn (mut w ui.Window) {
			w.locked_focus = ''
		}
		on_mouse_down: fn [mut app] (mut w ui.Window, e ui.MouseEvent) {
			if e.button == ui.MouseButton.right {
				if !app.is_click_handled() {
					app.set_click_handled()
					if mut sv_stack := w.get[ui.Stack](views.id_timeline_scrollview) {
						sv_stack.scrollview.set(0, .btn_y)
					}
				}
			}
		}
	)

	app.window.locked_focus = 'y'
	ui.run(app.window)
}
