module views

import models { App, Post, Timeline }
import extra
import os
import ui
import widgets

const id_timeline = 'timeline'

pub fn create_timeline_view() &ui.Widget {
	return ui.column(id: id_timeline)
}

fn build_timeline_posts(timeline Timeline, mut app App) {
	text_size := app.settings.font_size
	text_size_small := text_size - 2
	line_spacing_small := 3
	mut posts := []ui.Widget{cap: timeline.posts.len + 1}

	for post in timeline.posts {
		mut post_ui := []ui.Widget{cap: 10}

		if post.repost_by.len > 0 {
			post_ui << widgets.link_label(
				text:         extra.sanitize_text(post.repost_by)
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
			on_click:   fn [post] () {
				os.open_uri(post.bsky_link) or { ui.message_box(err.msg()) }
			}
		)

		record_text := extra.sanitize_text(post.text)
		if record_text.len > 0 {
			post_ui << widgets.link_label(
				text:       record_text
				text_size:  text_size
				text_color: app.txt_color
				word_wrap:  true
			)
		}

		if post.link_uri.len > 0 && post.link_title.len > 0 {
			post_ui << widgets.link_label(
				text:         extra.sanitize_text(post.link_title)
				text_size:    text_size_small
				text_color:   app.txt_color_link
				line_spacing: line_spacing_small
				word_wrap:    true
				on_click:     fn [post] () {
					os.open_uri(post.link_uri) or { ui.message_box(err.msg()) }
				}
			)
		}

		if post.image_path.len > 0 {
			post_ui << v_space()
			post_ui << ui.column(
				alignment: .center
				children:  [
					ui.picture(path: post.image_path, use_cache: false),
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

// draw_timeline is used in Window's on_draw() function
// so it can occur on the UI thread or crashes happen.
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

fn author_timestamp_text(post Post) string {
	author := extra.remove_non_ascii(post.author)
	time_short := post.created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	time_stamp := if time_short == '0m' { '<1m' } else { time_short }
	return extra.truncate_long_fields('${author} • ${time_stamp}')
}

fn post_counts(post Post) string {
	return '• replies ${extra.short_size(post.replies)} ' +
		'• reposts ${extra.short_size(post.reposts)} ' +
		'• likes ${extra.short_size(post.likes)}'
}
