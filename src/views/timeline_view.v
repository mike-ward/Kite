module views

import models { App }
import atprotocol
import extra
import os
import time
import ui
import widgets

const id_timeline = 'timeline'

pub fn create_timeline_view() &ui.Widget {
	return ui.column(id: id_timeline)
}

pub fn build_timeline(timeline atprotocol.Timeline, mut app App) {
	text_size := app.settings.font_size
	text_size_small := text_size - 2
	line_spacing_small := 3
	mut posts := []ui.Widget{cap: timeline.posts.len + 1}

	for post in timeline.posts {
		// don't display stand alone replies, no context'
		if post.post.record.reply.parent.cid.len > 0 || post.post.record.reply.root.cid.len > 0 {
			continue
		}

		mut post_ui := []ui.Widget{cap: 10}

		if mut repost := repost_text(post) {
			post_ui << widgets.link_label(
				text:         extra.sanitize_text(repost)
				text_size:    text_size_small
				text_color:   app.txt_color_dim
				line_spacing: line_spacing_small
				word_wrap:    true
			)
		}

		post_ui << widgets.link_label(
			text:       author_timestamp_text(post)
			text_size:  text_size
			text_color: app.txt_color_bold
			word_wrap:  true
		)

		record_text := extra.sanitize_text(post.post.record.text)
		if record_text.len > 0 {
			post_ui << widgets.link_label(
				text:       record_text
				text_size:  text_size
				text_color: app.txt_color
				word_wrap:  true
			)
		}

		if lnk, title := external_link(post) {
			post_ui << widgets.link_label(
				text:         extra.sanitize_text(title)
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
					ui.picture(path: image_path, use_cache: false),
				]
			)
		}

		post_ui << widgets.link_label(
			text:         post_counts(post)
			text_size:    text_size_small
			text_color:   app.txt_color_dim
			line_spacing: line_spacing_small
		)

		post_ui << v_space()
		post_ui << widgets.h_line(color: app.hline_color)
		posts << ui.column(
			spacing:  5
			children: post_ui
		)
	}

	app.timeline_posts_mutex.lock()
	app.timeline_posts = posts
	app.timeline_posts_mutex.unlock()
}

// Call this on the Window's on_draw() function.
// It must occur on the UI thread or crashes happen.
pub fn draw_timeline(w &ui.Window, mut app App) {
	app.timeline_posts_mutex.lock()
	defer { app.timeline_posts_mutex.unlock() }
	if app.timeline_posts.len > 0 {
		if mut stack := w.get[ui.Stack](id_timeline) {
			for stack.children.len > 0 {
				stack.remove()
			}
			stack.add(children: app.timeline_posts)
		}
		app.timeline_posts.clear()
	}
}

fn v_space() ui.Widget {
	return ui.rectangle(height: 0)
}

fn repost_text(post atprotocol.Post) !string {
	if post.reason.type.contains('Repost') {
		by := match post.reason.by.display_name.len > 0 {
			true { post.reason.by.display_name }
			else { post.reason.by.handle }
		}
		return 'reposted by ${by}'
	}
	return error('no repost')
}

fn author_timestamp_text(post atprotocol.Post) string {
	handle := post.post.author.handle
	d_name := post.post.author.display_name
	author := extra.remove_non_ascii(if d_name.len > 0 { d_name } else { handle })

	created_at := time.parse_iso8601(post.post.record.created_at) or { time.utc() }
	time_short := created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	time_stamp := if time_short == '0m' { '<1m' } else { time_short }
	return extra.truncate_long_fields('${author} • ${time_stamp}')
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
		cid := image.image.ref.link
		tmp_file := os.join_path_single(os.temp_dir(), '${extra.image_prefix}_${cid}')
		if os.exists(tmp_file) {
			return tmp_file, image.alt
		}
	}
	return error('no image found')
}

fn post_counts(post atprotocol.Post) string {
	return '• replies ${extra.short_size(post.post.replies)} ' +
		'• reposts ${extra.short_size(post.post.reposts + post.post.quotes)} ' +
		'• likes ${extra.short_size(post.post.likes)}'
}
