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
		text_size_small := text_size - 2
		text_width := stack.width - 10
		mut widgets := []ui.Widget{}

		for post in app.timeline.posts {
			mut post_ui := []ui.Widget{cap: 10} // preallocate to avoid resizing

			if mut repost := repost_text(post) {
				post_ui << ui.label(
					text:       format_text(repost, text_width, stack.ui)
					text_size:  text_size_small
					text_color: app.txt_color_dim
				)
			}

			post_ui << ui.label(
				text:       author_timestamp_text(post, text_width, stack.ui)
				text_size:  text_size
				text_color: app.txt_color_bold
			)
			post_ui << ui.label(
				text:       format_text(post.post.record.text, text_width, stack.ui)
				text_size:  text_size
				text_color: app.txt_color
			)

			if link, title := external_link(post) {
				post_ui << hyperlink(
					text:       format_text(title, text_width, stack.ui)
					text_size:  text_size_small
					text_color: app.txt_color_link
					on_click:   fn [link] (h &Hyperlink) {
						os.open_uri(link) or {}
					}
				)
			}

			if image_path, _ := post_image(post) {
				post_ui << ui.column(
					alignment: .center
					children:  [
						v_space(),
						ui.picture(path: image_path),
						v_space(),
					]
				)
				post_ui << v_space()
			}

			post_ui << ui.label(
				text:       post_counts(post)
				text_size:  text_size_small
				text_color: app.txt_color_dim
			)
			post_ui << v_space()
			post_ui << h_line(app)
			widgets << ui.column(children: post_ui)
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

fn author_timestamp_text(post atprotocol.Post, width int, u &ui.UI) string {
	handle := post.post.author.handle
	d_name := post.post.author.display_name
	author := if d_name.len > 0 { d_name } else { handle }

	created_at := time.parse_iso8601(post.post.record.created_at) or { time.utc() }
	time_short := created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	time_stamp := if time_short == '0m' { '<1m' } else { time_short }
	return format_text('${author} • ${time_stamp}', width, u)
}

fn external_link(post atprotocol.Post) !(string, string) {
	return match post.post.record.embed.external.uri.len > 0 {
		true { post.post.record.embed.external.uri, post.post.record.embed.external.title }
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
			os.rm(os.join_path_single(tmp_dir, entry)) or {}
		}
	}
}
