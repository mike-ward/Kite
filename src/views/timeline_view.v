module views

import models { App, Post, Timeline }
import extra
import os
import ui
import widgets

const v_scrollbar_width = 10
const id_timeline = 'timeline'
const id_up_button = '_up_button_'
pub const id_timeline_scrollview = 'timeline_scrollview'

pub fn create_timeline_view(mut app App) &ui.Widget {
	// Extra column layout required to work around some
	// rendering issues with VUI. Early alpha issues
	// that will likely go away at some point.
	tl := ui.column(
		id:         id_timeline_scrollview
		scrollview: true
		margin:     ui.Margin{0, 0, 0, v_scrollbar_width}
		children:   [
			ui.column(
				id:     id_timeline
				margin: ui.Margin{3, 0, 0, 0}
			),
		]
	)

	has, mut sv := ui.get_scrollview(tl)
	if has {
		sv.is_focused = true
	}

	return tl
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
				text:         extra.sanitize_text('reposted by ${post.repost_by}')
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
			on_click:   fn [post, mut app] () {
				if !app.is_click_handled() {
					os.open_uri(post.bsky_link) or { ui.message_box(err.msg()) }
					app.set_click_handled()
				}
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

		if post.embed_post_author.len > 0 && post.embed_post_text.len > 0 {
			post_ui << ui.row(
				heights:  [ui.stretch, ui.stretch]
				widths:   [ui.compact, ui.stretch]
				children: [
					ui.rectangle(
						width: 1
						color: app.hline_color
					),
					ui.column(
						spacing:  5
						margin:   ui.Margin{0, 0, 0, v_scrollbar_width}
						children: [
							widgets.link_label(
								text:       author_timestamp_text_embed(post)
								text_size:  text_size_small
								text_color: app.txt_color_bold
								word_wrap:  true
							),
							widgets.link_label(
								text:       extra.sanitize_text(post.embed_post_text)
								text_size:  text_size_small
								text_color: app.txt_color
								word_wrap:  true
							),
						]
					),
				]
			)
		}

		if post.link_uri.len > 0 && post.link_title.len > 0 {
			post_ui << widgets.link_label(
				text:         extra.sanitize_text(post.link_title)
				text_size:    text_size_small
				text_color:   app.txt_color_link
				line_spacing: line_spacing_small
				word_wrap:    true
				on_click:     fn [post, mut app] () {
					if !app.is_click_handled() {
						os.open_uri(post.link_uri) or { ui.message_box(err.msg()) }
						app.set_click_handled()
					}
				}
			)
		}

		if post.image_path.len > 0 {
			mut pic := ui.picture(path: post.image_path, use_cache: false)
			// These hardcoded offsets look good to my eye.
			pic.offset_x = 7
			pic.offset_y = 3
			post_ui << pic
		}

		post_ui << widgets.link_label(
			text:         post_counts(post)
			text_size:    text_size_small
			text_color:   app.txt_color_dim
			line_spacing: line_spacing_small
			offset_y:     if post.image_path.len > 0 { 4 } else { 0 }
		)

		post_ui << widgets.h_line(color: app.hline_color, offset_y: 2)
		posts << ui.column(
			id:       post.id
			spacing:  5
			children: post_ui
		)
	}

	// app.timeline_posts shared with UI thread
	app.timeline_posts_mutex.lock()
	app.timeline_posts = posts
	app.timeline_posts_mutex.unlock()
}

// draw_timeline is used in Window's on_draw() function
// so it can occur on the UI thread or crashes happen.
pub fn draw_timeline(mut w ui.Window, mut app App) {
	mut up_button_notice := false
	mut sv_stack := w.get[ui.Stack](id_timeline_scrollview) or { return }
	mut tl_stack := w.get[ui.Stack](id_timeline) or { return }

	app.timeline_posts_mutex.lock()

	if app.timeline_posts.len > 0 {
		app.timeline_up_button.notice = true
		up_button_notice = app.timeline_posts[0].id != app.first_post_id
		if sv_stack.scrollview.offset_y == 0 {
			for tl_stack.children.len > 0 {
				tl_stack.remove()
			}
			tl_stack.add(children: app.timeline_posts)
			app.first_post_id = app.timeline_posts[0].id
			app.timeline_posts.clear()
			up_button_notice = false
		}
	}

	app.timeline_posts_mutex.unlock()

	// This is a little hacky. Couldn't get canvas to
	// behave with timeline components so use windows's
	// top_layer canvas to host up_button.
	radius := 19
	if app.timeline_up_button == unsafe { nil } {
		mut up_button := widgets.up_button(
			id:           id_up_button
			radius:       radius
			bg_color:     app.bg_color
			fg_color:     app.txt_color_bold
			border_color: app.txt_color_link
			on_click:     fn [mut sv_stack, mut app] (_ &widgets.UpButton) {
				if !app.is_click_handled() {
					sv_stack.scrollview.set(0, .btn_y)
					app.set_click_handled()
				}
			}
		)
		// add_top_layer() does not init and register widgets. Bug?
		app.window.add_top_layer(up_button)
		up_button.init(w.top_layer)
		w.register_child(*up_button)
		app.timeline_up_button = up_button
	}
	offset := radius + v_scrollbar_width
	x := app.window.width - offset
	y := app.window.height - offset
	app.timeline_up_button.set_pos(x, y)
	app.timeline_up_button.notice = up_button_notice
	app.timeline_up_button.set_visible(sv_stack.scrollview.offset_y > 0)
}

fn author_timestamp_text(post Post) string {
	author := extra.remove_non_ascii(post.author)
	time_short := post.created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	time_stamp := if time_short == '0m' { 'now' } else { time_short }
	return extra.truncate_long_fields('${author} • ${time_stamp}')
}

fn author_timestamp_text_embed(post Post) string {
	author := extra.remove_non_ascii(post.embed_post_author)
	time_short := post.embed_post_created_at
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
