import arrays
import atprotocol
import gx
import time
import ui

const id_timeline = 'timeline'

fn create_timeline_view(mut app App) &ui.Widget {
	return ui.column(
		id:         id_timeline
		scrollview: true
	)
}

fn start_timeline(mut app App) {
	for {
		update_timeline(mut app)
		app.refresh_count += 1
		if app.refresh_count % 10 == 0 { // Refresh the session every 10 minutes
			refresh_session(mut app)
		}
		time.sleep(time.minute)
	}
}

fn update_timeline(mut app App) {
	timeline := app.settings.session.get_timeline() or {
		save_settings(Settings{})
		error_timeline(err.msg())
	}

	mut widgets := []ui.Widget{}
	for f in timeline.feed {
		handle := f.post.author.handle
		name := f.post.author.display_name
		author := if name.len > 0 { name } else { handle }

		created := time.parse_iso8601(f.post.record.created_at) or { time.utc() }
		short_time := created.utc_to_local().relative_short().replace(' ago', '')
		post_time := if short_time == '0m' { '<1m' } else { short_time }

		header := '• ${author} ∙ ${post_time}'
		content := truncate_long_words(f.post.record.text).wrap(width: 45)

		widgets << ui.column(
			children: [
				ui.label(
					text:       header
					text_color: gx.rgb(0x19, 0x19, 0x70)
				),
				ui.label(text: content),
				ui.label(text: ''),
			]
		)
	}

	if mut tl := app.window.get[ui.Stack](id_timeline) {
		for tl.children.len > 0 {
			tl.remove()
		}
		tl.add(children: widgets)
	}
}

fn error_timeline(s string) atprotocol.Timeline {
	return atprotocol.Timeline{
		feed: [
			atprotocol.Feed{
				post: atprotocol.Post{
					author: atprotocol.Author{
						handle:       'kite error'
						display_name: 'kite error message'
					}
					record: atprotocol.Record{
						text:       s
						created_at: time.now().format_rfc3339()
					}
				}
			},
		]
	}
}

fn truncate_long_words(s string) string {
	return arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return match true {
			elem.len > 35 { elem[..20] + '...' }
			else { elem }
		}
	})
}
