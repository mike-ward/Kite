module views

import arrays
import models { App, Post, Timeline }
import extra
import os
import ui
import widgets

const r_chevron = '»'
const l_chevron = '«'
const post_spacing = 4
const v_scrollbar_width = 10
const id_up_button = '_up_button_'
pub const id_timeline_scrollview = 'timeline_scrollview'

pub fn create_timeline_view(mut app App) &ui.Widget {
	return ui.column(
		id:         id_timeline_scrollview
		scrollview: true
		margin:     ui.Margin{0, 0, 0, v_scrollbar_width}
		children:   [
			// ui.Stack does not like an empty child list. Removing
			// and adding widgets can cause it to crash over time.
			// Keeping a couple of widgets around can help prevent this.
			// See draw_timeline()
			widgets.link_label(text: ''),
			widgets.link_label(text: ''),
		]
	)
}

fn build_timeline_posts(timeline Timeline, mut app App) {
	text_size := app.settings.font_size
	text_size_small := text_size - 2
	line_spacing_small := 3
	mut posts := []ui.Widget{cap: timeline.posts.len + 1}

	first_post_id := timeline.posts[0].id
	if app.first_post_id != first_post_id {
		app.old_post_id = match app.first_post_id.len == 0 {
			true { first_post_id }
			else { app.first_post_id }
		}
		app.first_post_id = first_post_id
	}
	mut first_post_idx := arrays.index_of_first(timeline.posts, fn [app] (_ int, post Post) bool {
		return post.id == app.old_post_id
	})
	first_post_idx -= 1

	for idx, post in timeline.posts {
		mut post_ui := []ui.Widget{cap: 10}

		if post.repost_by.len > 0 {
			post_ui << widgets.link_label(
				text:         extra.sanitize_text('reposted by ${post.repost_by}')
				word_wrap:    true
				text_size:    text_size_small
				text_color:   app.txt_color_dim
				wrap_shrink:  v_scrollbar_width
				line_spacing: line_spacing_small
				offset_y:     -2
			)
		}

		mut author := author_timestamp_text(post)
		if idx <= first_post_idx {
			author = '${r_chevron} ${author}'
		}
		post_ui << widgets.link_label(
			text:        author
			text_size:   text_size
			text_color:  app.txt_color_bold
			word_wrap:   true
			wrap_shrink: v_scrollbar_width
			on_click:    fn [post, mut app] () {
				if !app.is_click_handled() {
					app.set_click_handled()
					os.open_uri(post.bsky_link_uri) or { ui.message_box(err.msg()) }
				}
			}
		)

		record_text := extra.sanitize_text(post.text)
		if record_text.len > 0 {
			post_ui << widgets.link_label(
				text:        record_text
				word_wrap:   true
				text_size:   text_size
				text_color:  app.txt_color
				wrap_shrink: v_scrollbar_width
			)
		}

		embed_text := extra.sanitize_text(post.embed_post_text)
		if post.embed_post_author.len > 0 && embed_text.len > 0 {
			post_ui << ui.row(
				widths:   [ui.compact, ui.stretch]
				spacing:  v_scrollbar_width
				children: [
					ui.rectangle(
						width: 1
						color: app.hline_color
					),
					ui.column(
						spacing:  post_spacing
						clipping: true
						children: [
							widgets.link_label(
								text:        author_timestamp_text_embed(post)
								word_wrap:   true
								text_size:   text_size_small
								text_color:  app.txt_color_bold
								wrap_shrink: v_scrollbar_width + 5
							),
							widgets.link_label(
								text:        embed_text
								word_wrap:   true
								text_size:   text_size_small
								text_color:  app.txt_color
								wrap_shrink: v_scrollbar_width + 5
							),
							widgets.link_label(
								text:        extra.sanitize_text(post.embed_post_link_title)
								word_wrap:   true
								text_size:   text_size_small
								text_color:  app.txt_color_link
								wrap_shrink: v_scrollbar_width + 5
								on_click:    embed_post_link_click_handler(post, mut app)
							),
						]
					),
				]
			)
		}

		if post.link_uri.len > 0 && post.link_title.len > 0 {
			post_ui << widgets.link_label(
				text:         extra.sanitize_text(post.link_title)
				word_wrap:    true
				text_size:    text_size_small
				text_color:   app.txt_color_link
				wrap_shrink:  v_scrollbar_width
				line_spacing: line_spacing_small
				on_click:     fn [post, mut app] () {
					if !app.is_click_handled() {
						app.set_click_handled()
						os.open_uri(post.link_uri) or { ui.message_box(err.msg()) }
					}
				}
			)
		}

		if post.image_path.len > 0 {
			app.picture_cache[post.image_path] = 0
			mut pic := ui.picture(
				path:     post.image_path
				on_click: fn [post, mut app] (_ &ui.Picture) {
					if !app.is_click_handled() {
						app.set_click_handled()
						os.open_uri(post.bsky_link_uri) or { ui.message_box(err.msg()) }
					}
				}
			)
			pic.offset_y = 3
			post_ui << pic
		}

		post_ui << widgets.link_label(
			text:       post_counts(post)
			text_size:  text_size_small
			text_color: app.txt_color_dim
			offset_y:   if post.image_path.len > 0 { 4 } else { 0 }
		)

		post_ui << widgets.h_line(
			color:    app.hline_color
			offset_y: 2
		)
		posts << ui.column(
			id:       post.id
			spacing:  post_spacing
			children: post_ui
		)
	}

	// app.timeline_posts shared with UI thread
	app.timeline_posts_mutex.lock()
	app.timeline_posts = posts
	app.timeline_posts_mutex.unlock()
}

// draw_timeline is used in Window's on_draw()
// function so it can occur on the UI thread
pub fn draw_timeline(mut w ui.Window, mut app App) {
	mut notice := false
	mut sv_stack := w.get[ui.Stack](id_timeline_scrollview) or { return }

	app.timeline_posts_mutex.lock()
	defer { app.timeline_posts_mutex.unlock() }

	if app.timeline_posts.len > 0 {
		notice = app.timeline_posts[0].id != app.old_post_id
		if sv_stack.scrollview.offset_y == 0 {
			sv_stack.remove()
			mut tl := ui.column()
			sv_stack.add(children: [tl])
			tl.add(children: app.timeline_posts)
			app.timeline_posts = []
			notice = false
		}
	}

	l_new := if notice { r_chevron } else { '' }
	r_new := if notice { l_chevron } else { '' }
	app.window.set_title('${l_new} Kite ${r_new}')
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

fn embed_post_link_click_handler(post Post, mut app App) widgets.LinkLabelClickFn {
	if post.embed_post_link_uri.len == 0 {
		return widgets.LinkLabelClickFn(0)
	}

	return fn [post, mut app] () {
		if !app.is_click_handled() {
			app.set_click_handled()
			os.open_uri(post.embed_post_link_uri) or { ui.message_box(err.msg()) }
		}
	}
}
