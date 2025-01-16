import arrays
import atprotocol
import gx
import time
import ui

fn create_timeline_view(mut app App) &ui.Widget {
	return ui.column(
		id:         'timeline'
		scrollview: true
	)
}

fn update_timeline(mut app App) {
	timeline := app.session.get_timeline() or {
		save_settings(Settings{})
		error_timeline(err.msg())
	}

	mut feed := []ui.Widget{}
	for f in timeline.feed {
		author := f.post.author
		name := if author.display_name.len > 0 { author.display_name } else { author.handle }

		created := time.parse_iso8601(f.post.record.created_at) or { time.utc() }
		relative_time := created.utc_to_local().relative_short().replace(' ago', '')
		short_time := if relative_time == '0m' { '<1m' } else { relative_time }
		content := truncate_long_words(f.post.record.text).wrap(width: 45)

		post := ui.column(
			children: [
				ui.label(
					text:       '• ${name} ∙ ${short_time}'
					text_color: gx.rgb(0x19, 0x19, 0x70)
				),
				ui.label(text: content),
				ui.label(text: ''),
			]
		)
		feed << post
	}
	if mut tl := app.window.get[ui.Stack]('timeline') {
		for tl.children.len > 0 {
			tl.remove()
		}
		tl.add(children: feed)
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

fn start_timeline(mut app App) {
	for {
		update_timeline(mut app)
		time.sleep(time.minute)
	}
}

fn error_timeline(s string) atprotocol.Timeline {
	return atprotocol.Timeline{
		feed: [
			atprotocol.Feed{
				post: atprotocol.Post{
					author: atprotocol.Author{
						handle:       'kite'
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
