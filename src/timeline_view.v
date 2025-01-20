import arrays
import atprotocol
import hash
import net.http
import os
import time
import ui
import math

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
	widgets << spacer()

	for f in timeline.feed {
		mut post := []ui.Widget{cap: 10} // preallocate to avoid resizing

		if mut repost := repost_text(f) {
			post << ui.label(text: repost, text_size: 13)
		}

		post << ui.label(text: head_text(f))
		post << ui.label(text: body_text(f))

		if image_path := post_image_path(f, mut app) {
			post << ui.column(
				alignment: .center
				widths:    [ui.compact, ui.compact, ui.compact]
				children:  [
					spacer(),
					ui.picture(
						path:   image_path
						width:  200
						height: 125
					),
					spacer(),
				]
			)
		}

		post << counts(f)
		post << spacer()
		post << border()
		widgets << ui.column(children: post)
	}

	if mut tl := app.window.get[ui.Stack](id_timeline) {
		for tl.children.len > 0 {
			tl.remove()
		}
		tl.add(children: widgets)
	}
}

fn spacer() ui.Widget {
	return ui.rectangle(height: 5)
}

fn border() ui.Widget {
	return ui.rectangle(border: true)
}

fn repost_text(f atprotocol.Feed) !string {
	if f.reason.rtype.contains('Repost') {
		by := if f.reason.by.display_name.len > 0 {
			f.reason.by.display_name
		} else {
			f.reason.by.handle
		}
		return remove_non_printable('> reposted by ${by}')
	}
	return error('no repost')
}

fn head_text(f atprotocol.Feed) string {
	handle := f.post.author.handle
	d_name := f.post.author.display_name
	author := remove_non_printable(if d_name.len > 0 { d_name } else { handle })

	created_at := time.parse_iso8601(f.post.record.created_at) or { time.utc() }
	time_short := created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	time_stamp := if time_short == '0m' { '<1m' } else { time_short }
	return '•${author} • ${time_stamp}'
}

fn body_text(f atprotocol.Feed) string {
	return remove_non_printable(truncate_long_fields(f.post.record.text))
		.wrap(width: 45)
		.trim_space()
}

fn post_image_path(f atprotocol.Feed, mut app App) !string {
	if f.post.embed.etype.contains('#view') {
		if f.post.embed.external.thumb.len > 0 {
			hash_name := hash.sum64_string(f.post.embed.external.thumb, 0).str()
			tmp_file := os.join_path_single(os.temp_dir(), '${temp_prefix}_${hash_name}')
			if !os.exists(tmp_file) {
				http.download_file(f.post.embed.external.thumb, tmp_file) or {}
			}
			return tmp_file
		}
	}
	return error('no image')
}

fn counts(f atprotocol.Feed) ui.Widget {
	return ui.row(
		spacing:  5
		children: [
			ui.label(text: '• replies: ${short_size(f.post.reply_count)}'),
			ui.label(text: '• reposts: ${short_size(f.post.repost_count + f.post.quote_count)}'),
			ui.label(text: '• likes: ${short_size(f.post.like_count)}'),
		]
	)
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

fn remove_non_printable(s string) string {
	return arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return match true {
			elem.is_ascii() { elem }
			else { '' }
		}
	})
}

fn short_size(size int) string {
	kb := 1000
	mut sz := size
	for unit in ['', 'k', 'm', 'g', 't', 'p', 'e', 'z'] {
		if sz < kb {
			return '${sz}${unit}'
		}
		sz /= kb
	}
	return size.str()
}
