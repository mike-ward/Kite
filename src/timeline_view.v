import arrays
import atprotocol
import hash
import math
import net.http
import os
import regex
import time
import ui

const id_timeline = 'timeline'
const error_title = 'kite error'
const temp_prefix = 'kite_image'

fn create_timeline_view(mut app App) &ui.Widget {
	return ui.column(
		id: id_timeline
	)
}

fn start_timeline(mut app App) {
	spawn fn [mut app] () {
		for {
			update_timeline(mut app)
			app.refresh_session_count += 1
			if app.refresh_session_count % 10 == 0 { // Refresh every 10 minutes
				refresh_session(mut app)
			}
			time.sleep(time.minute)
		}
	}()
}

fn update_timeline(mut app App) {
	app.timeline = app.settings.session.get_timeline() or {
		save_settings(Settings{})
		error_timeline(err.msg())
	}
	build_timeline(mut app)
}

fn build_timeline(mut app App) {
	if mut stack := app.window.get[ui.Stack](id_timeline) {
		text_size := 16
		text_width := stack.width - 5
		mut widgets := []ui.Widget{}

		for feed in app.timeline.feeds {
			mut post := []ui.Widget{cap: 10} // preallocate to avoid resizing

			if mut repost := repost_text(feed) {
				post << ui.label(
					text:       wrap_text(repost, text_width, stack.ui)
					text_size:  text_size - 2
					text_color: app.txt_color_dim
				)
			}

			post << ui.label(
				text:       head_text(feed, text_width, stack.ui)
				text_size:  text_size
				text_color: app.txt_color_bold
			)
			post << ui.label(
				text:       body_text(feed, text_width, stack.ui)
				text_size:  text_size
				text_color: app.txt_color
			)

			// images cause the app to crash in gg after a time
			// if image_path := post_image_path(feed) {
			// 	post << ui.column(
			// 		id:        'pic_col'
			// 		alignment: .center
			// 		children:  [
			// 			v_space(),
			// 			ui.picture(
			// 				path:   image_path
			// 				width:  200
			// 				height: 125
			// 			),
			// 			v_space(),
			// 		]
			// 	)
			// 	post << v_space()
			// }

			post << ui.label(
				text:       post_counts(feed)
				text_size:  text_size - 2
				text_color: app.txt_color_dim
			)
			post << v_space()
			post << h_line(app)
			widgets << ui.column(children: post)
		}

		for stack.children.len > 0 {
			stack.remove()
		}
		stack.add(children: widgets)
	}
}

fn v_space() ui.Widget {
	return ui.rectangle(height: 5)
}

fn h_line(app App) ui.Widget {
	return ui.rectangle(border: true, border_color: app.txt_color_dim)
}

fn repost_text(feed atprotocol.Feed) !string {
	if feed.reason.type.contains('Repost') {
		by := if feed.reason.by.display_name.len > 0 {
			feed.reason.by.display_name
		} else {
			feed.reason.by.handle
		}
		return remove_non_ascii('reposted by ${by}')
	}
	return error('no repost')
}

fn head_text(feed atprotocol.Feed, width int, u &ui.UI) string {
	handle := feed.post.author.handle
	d_name := feed.post.author.display_name
	author := remove_non_ascii(if d_name.len > 0 { d_name } else { handle })

	created_at := time.parse_iso8601(feed.post.record.created_at) or { time.utc() }
	time_short := created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	time_stamp := if time_short == '0m' { '<1m' } else { time_short }
	return wrap_text('${author} • ${time_stamp}', width, u)
}

fn body_text(feed atprotocol.Feed, width int, u &ui.UI) string {
	ascii := remove_non_ascii(truncate_long_fields(feed.post.record.text))
	return wrap_text(ascii, width, u).trim_space()
}

fn post_image_path(feed atprotocol.Feed) !string {
	if feed.post.embed.type.contains('#view') {
		if feed.post.embed.external.thumb.len > 0 {
			hash_name := hash.sum64_string(feed.post.embed.external.thumb, 0).str()
			tmp_file := os.join_path_single(os.temp_dir(), '${temp_prefix}_${hash_name}')
			if !os.exists(tmp_file) {
				http.download_file(feed.post.embed.external.thumb, tmp_file)!
				// image := app.window.ui.gg.create_image_with_size(tmp_file, 200, 125)
			}
			return tmp_file
		}
	}
	return error('no image')
}

fn post_counts(feed atprotocol.Feed) string {
	return '• replies ${short_size(feed.post.replies)} ' +
		'• reposts ${short_size(feed.post.reposts + feed.post.quotes)} ' +
		'• likes ${short_size(feed.post.likes)}'
}

fn error_timeline(s string) atprotocol.Timeline {
	return atprotocol.Timeline{
		feeds: [
			struct {
				post: struct {
					author: struct {
						handle:       error_title
						display_name: error_title
					}
					record: struct {
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

fn remove_non_ascii(s string) string {
	// convert smart quotes to regular quotes
	s1 := arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return elem
			.replace('“', '"')
			.replace('”', '"')
			.replace('’', "'")
			.replace('‘', "'")
	})
	// strip out non-ascii characters
	if mut query := regex.regex_opt(r"[^' ',!-~]") {
		return query.replace(s1, '')
	}
	return s1
}

fn short_size(size int) string {
	kb := 1000
	mut sz := f64(size)
	for unit in ['', 'K', 'M', 'G', 'T', 'P', 'E', 'Z'] {
		if sz < kb {
			short := match unit == '' {
				true { size.str() }
				else { math.round_sig(sz + .049999, 1).str() }
			}
			return '${short}${unit}'
		}
		sz /= kb
	}
	return size.str()
}

fn wrap_text(s string, width int, u &ui.UI) string {
	mut wrap := ''
	mut line := ''
	for field in s.fields() {
		tw, _ := u.dd.text_size(line + ' ' + field)
		if tw > width {
			wrap += '${line}\n'
			line = field
		} else {
			if line.len > 0 {
				line += ' '
			}
			line += field
		}
	}
	if line.len > 0 {
		wrap += '${line}'
	}
	return wrap
}
