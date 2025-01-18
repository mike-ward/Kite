import arrays
import atprotocol
import time
import ui

const id_timeline = 'timeline'

fn create_timeline_view(mut app App) &ui.Widget {
	return ui.column(
		id:         id_timeline
		width:      100
		scrollview: true
	)
}

fn start_timeline(mut app App) {
	for {
		update_timeline(mut app)
		app.refresh_session_count += 1
		if app.refresh_session_count % 10 == 0 { // Refresh the session every 10 minutes
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
	widgets << ui.rectangle(height: 1) // spacer

	for f in timeline.feed {
		handle := f.post.author.handle
		d_name := f.post.author.display_name
		author := if d_name.len > 0 { d_name } else { handle }

		created_at := time.parse_iso8601(f.post.record.created_at) or { time.utc() }
		time_short := created_at
			.utc_to_local()
			.relative_short()
			.fields()[0]
		time_stamp := if time_short == '0m' { '<1m' } else { time_short }

		repost := if f.reason.rtype.contains('Repost') {
			match f.reason.by.display_name.len > 0 {
				true { '> reposted by ${f.reason.by.display_name}' }
				else { '> reposted by ${f.reason.by.handle}' }
			}
		} else {
			''
		}

		head := '• ${author} ∙ ${time_stamp}'
		body := truncate_long_fields(f.post.record.text)
			.wrap(width: 45)
			.trim_space()

		mut post := match repost.len > 0 {
			true {
				ui.column(
					children: [
						ui.label(text: repost, text_size: 13),
						ui.label(text: head),
						ui.label(text: body),
						ui.rectangle(height: 5), // spacer
						ui.rectangle(border: true),
					]
				)
			}
			else {
				ui.column(
					children: [
						ui.label(text: head),
						ui.label(text: body),
						ui.rectangle(height: 5), // spacer
						ui.rectangle(border: true),
					]
				)
			}
		}

		widgets << post
	}

	if mut tl := app.window.get[ui.Stack](id_timeline) {
		for tl.children.len > 0 {
			tl.remove()
		}
		tl.add(children: widgets)
	}
}

// fn post_chunk(text string) &ui.ChunkView {
// 	mut text_chunks := []ui.ChunkContent{}
// 	mut line := ''
// 	for field in text.fields() {
// 		if line.len + field.len > 45 {
// 			text_chunks << ui.textchunk(text: line)
// 			line = field
// 		}
// 		line += field + ' '
// 	}
// 	return ui.chunkview(
// 		chunks: [
// 			ui.rowchunk(chunks: text_chunks),
// 		]
// 	)
// }

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

fn truncate_long_fields(s string) string {
	return arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return match true {
			elem.len > 35 { elem[..20] + '...' }
			else { elem }
		}
	})
}
