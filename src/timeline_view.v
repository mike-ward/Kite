import arrays
import atprotocol
import gg
import hash
import net.http
import os
import time
import ui

const id_timeline = 'timeline'
const error_title = 'kite error'
const temp_prefix = 'kite_image_'

fn create_timeline_view(mut app App) &ui.Widget {
	return ui.column(
		id:         id_timeline
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
	ui_timeline(timeline, mut app)
}

fn ui_timeline(timeline atprotocol.Timeline, mut app App) {
	mut widgets := []ui.Widget{}
	widgets << ui.rectangle(height: 1) // spacer

	for f in timeline.feed {
		mut post := []ui.Widget{cap: 10} // preallocate to avoid resizing

		if mut repost := repost_text(f) {
			post << ui.label(text: repost, text_size: 13)
		}

		post << ui.label(text: head_text(f))
		post << ui.label(text: body_text(f))

		if image := post_image(f, mut app) {
			post << ui.column(
				alignment: .center
				children:  [ui.picture(image: image, width: 200, height: 125)]
			)
		}

		post << ui.rectangle(height: 5)
		post << ui.rectangle(border: true)
		widgets << ui.column(children: post)
	}

	if mut tl := app.window.get[ui.Stack](id_timeline) {
		for tl.children.len > 0 {
			tl.remove()
		}
		tl.add(children: widgets)
	}
}

fn repost_text(f atprotocol.Feed) !string {
	if f.reason.rtype.contains('Repost') {
		by := if f.reason.by.display_name.len > 0 {
			f.reason.by.display_name
		} else {
			f.reason.by.handle
		}
		return '> reposted by ${by}'
	}
	return error('no repost')
}

fn post_image(f atprotocol.Feed, mut app App) !gg.Image {
	if f.post.embed.etype.contains('#view') {
		if f.post.embed.external.thumb.len > 0 {
			hash_name := hash.sum64_string(f.post.embed.external.thumb, 0).str()
			tmp_file := os.join_path_single(os.temp_dir(), '${temp_prefix}_${hash_name}')
			if !os.exists(tmp_file) {
				http.download_file(f.post.embed.external.thumb, tmp_file) or {}
			}
			if mut app.window.ui.dd is ui.DrawDeviceContext {
				return app.window.ui.dd.create_image(tmp_file) or { app.window.ui.img('v-logo') }
			}
		}
	}
	return error('no image')
}

fn head_text(f atprotocol.Feed) string {
	handle := f.post.author.handle
	d_name := f.post.author.display_name
	author := if d_name.len > 0 { d_name } else { handle }

	created_at := time.parse_iso8601(f.post.record.created_at) or { time.utc() }
	time_short := created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	time_stamp := if time_short == '0m' { '<1m' } else { time_short }
	return '${author} @ ${time_stamp}'
}

fn body_text(f atprotocol.Feed) string {
	return truncate_long_fields(f.post.record.text)
		.wrap(width: 45)
		.trim_space()
}

fn error_timeline(s string) atprotocol.Timeline {
	return atprotocol.Timeline{
		feed: [
			atprotocol.Feed{
				post: atprotocol.Post{
					author: atprotocol.Author{
						handle:       error_title
						display_name: error_title
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
