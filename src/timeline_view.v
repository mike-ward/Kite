import atprotocol
import os
import stbi
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
	if !app.timeline_started {
		clear_image_cache()
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
		app.timeline_started = true
	}
}

fn update_timeline(mut app App) {
	timeline := app.settings.session.get_timeline() or {
		save_settings(Settings{})
		error_timeline(err.msg())
	}
	app.timeline_mutex.lock()
	app.timeline = timeline
	app.timeline_mutex.unlock()
	build_timeline(timeline, mut app)
}

fn build_timeline(timeline atprotocol.Timeline, mut app App) {
	if mut stack := app.window.get[ui.Stack](id_timeline) {
		text_size := 17
		text_size_small := text_size - 2
		line_spacing_small := 2
		mut widgets := []ui.Widget{cap: timeline.posts.len + 1}

		for post in timeline.posts {
			mut post_ui := []ui.Widget{cap: 10}

			if mut repost := repost_text(post) {
				post_ui << link_label(
					text:         sanitize_text(repost)
					text_size:    text_size_small
					text_color:   app.txt_color_dim
					line_spacing: line_spacing_small
					word_wrap:    true
				)
			}

			post_ui << link_label(
				text:       author_timestamp_text(post)
				text_size:  text_size
				text_color: app.txt_color_bold
				word_wrap:  true
			)

			record_text := sanitize_text(post.post.record.text)
			if record_text.len > 0 {
				post_ui << link_label(
					text:       record_text
					text_size:  text_size
					text_color: app.txt_color
					word_wrap:  true
				)
			}

			if lnk, title := external_link(post) {
				post_ui << link_label(
					text:         sanitize_text(title)
					text_size:    text_size_small
					text_color:   app.txt_color_link
					line_spacing: line_spacing_small
					word_wrap:    true
					on_click:     fn [lnk] () {
						os.open_uri(lnk) or { ui.message_box(err.msg()) }
					}
				)
			}

			if image_path, _ := post_image(post) {
				post_ui << v_space()
				post_ui << ui.column(
					alignment: .center
					children:  [
						v_space(),
						ui.picture(path: image_path),
						v_space(),
					]
				)
			}

			post_ui << link_label(
				text:         post_counts(post)
				text_size:    text_size_small
				text_color:   app.txt_color_dim
				line_spacing: line_spacing_small
				word_wrap:    true
			)

			post_ui << v_space()
			post_ui << h_line(app)
			widgets << ui.column(
				spacing:  5
				children: post_ui
			)
		}

		for stack.children.len > 0 {
			stack.remove(at: -1)
		}
		stack.add(children: widgets)
	}
}

fn v_space() ui.Widget {
	return ui.rectangle(height: 0)
}

fn h_line(app App) ui.Widget {
	return ui.rectangle(
		border:       true
		border_color: app.txt_color_dim
	)
}

fn repost_text(post atprotocol.Post) !string {
	if post.reason.type.contains('Repost') {
		by := if post.reason.by.display_name.len > 0 {
			post.reason.by.display_name
		} else {
			post.reason.by.handle
		}
		return 'reposted by ${by}'
	}
	return error('no repost')
}

fn author_timestamp_text(post atprotocol.Post) string {
	handle := post.post.author.handle
	d_name := post.post.author.display_name
	author := remove_non_ascii(if d_name.len > 0 { d_name } else { handle })

	created_at := time.parse_iso8601(post.post.record.created_at) or { time.utc() }
	time_short := created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	time_stamp := if time_short == '0m' { '<1m' } else { time_short }
	return truncate_long_fields('${author} • ${time_stamp}')
}

fn external_link(post atprotocol.Post) !(string, string) {
	external := post.post.record.embed.external
	return match external.uri.len > 0 && external.title.trim_space().len > 0 {
		true { external.uri, external.title.trim_space() }
		else { error('') }
	}
}

// get_post_image downloads the first image blob assciated with the post
// and returns the file path where the image is stored and the alt text
// for that image. Images are resized to reduce memory load.
fn post_image(post atprotocol.Post) !(string, string) {
	if post.post.record.embed.images.len > 0 {
		image := post.post.record.embed.images[0]
		if image.image.ref.link.len > 0 {
			cid := image.image.ref.link
			tmp_file := os.join_path_single(os.temp_dir(), '${temp_prefix}_${cid}')
			ratio := match image.aspect_ratio.width != 0 && image.aspect_ratio.height != 0 {
				true { f64(image.aspect_ratio.height) / f64(image.aspect_ratio.width) }
				else { 1.0 }
			}
			if !os.exists(tmp_file) {
				blob := atprotocol.get_blob(post.post.author.did, cid)!
				tmp_file_ := tmp_file + '_'
				os.write_file(tmp_file_, blob)!
				img_ := stbi.load(tmp_file_)!
				os.rm(tmp_file_)!
				width := 200
				img := stbi.resize_uint8(img_, width, int(width * ratio))!
				stbi.stbi_write_png(tmp_file, img.width, img.height, img.nr_channels,
					img.data, img.width * img.nr_channels)!
			}
			return tmp_file, image.alt
		}
	}
	return error('no image found')
}

fn post_counts(post atprotocol.Post) string {
	return '• replies ${short_size(post.post.replies)} ' +
		'• reposts ${short_size(post.post.reposts + post.post.quotes)} ' +
		'• likes ${short_size(post.post.likes)}'
}

fn error_timeline(s string) atprotocol.Timeline {
	return atprotocol.Timeline{
		posts: [
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

fn clear_image_cache() {
	tmp_dir := os.temp_dir()
	entries := os.ls(tmp_dir) or { [] }
	for entry in entries {
		if entry.starts_with(temp_prefix) {
			path := os.join_path_single(tmp_dir, entry)
			stat := os.lstat(path) or { continue }
			date := time.unix(stat.atime)
			if time.since(date) > time.hour {
				os.rm(path) or {}
			}
		}
	}
}
