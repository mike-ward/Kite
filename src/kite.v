import atprotocol
import time
import ui

@[heap]
struct App {
mut:
	window  &ui.Window = unsafe { nil }
	session atprotocol.Session
}

fn main() {
	mut app := &App{}
	settings := load_settings()

	view := match settings.is_valid() {
		true { timeline_view(app) }
		else { login_view(mut app) }
	}

	app.window = ui.window(
		height:   1000
		width:    300
		title:    'Kite'
		children: [view]
	)

	ui.run(app.window)
}

fn (mut app App) login(b &ui.Button) {
	if mut label := app.window.get[ui.TextBox]('timeline') {
		app.session = atprotocol.create_session('mike@wardfam.org', 'Tilt-Vendetta-Evident9') or {
			label.set_text(err.str())
			return
		}
		timeline := app.session.get_timeline() or { atprotocol.Timeline{} }

		mut output := ''
		for f in timeline.feed {
			created := time.parse_iso8601(f.post.record.created_at) or { time.utc() }
			output += '\n${f.post.author.display_name} ∙ ${created.utc_to_local().relative()}'
			output += '\n${f.post.record.text}\n'
			output += '.................................\n'
		}
		label.set_text(output)
	}
}
