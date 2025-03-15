module views

import models { App, Post, Timeline }
import xtra
import os
import time
import ui
import widgets

const r_chevron = '»'
const l_chevron = '«'
const post_spacing = 4
const id_up_button = '_up_button_'
pub const id_timeline_scrollview = 'timeline_scrollview'

pub fn create_timeline_view(mut app App) &ui.Widget {
	return ui.column(
		id:         id_timeline_scrollview
		scrollview: true
		margin:     ui.Margin{0, 0, 0, models.v_scrollbar_width}
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

	first_post_idx := app.update_first_post(timeline)
	mut posts_ui := []ui.Widget{cap: timeline.posts.len + 1}

	for idx, post in timeline.posts {
		mut post_ui := []ui.Widget{cap: 10}

		if post.repost_by.len > 0 {
			post_ui << widgets.link_label(
				text:        xtra.sanitize_text('reposted by ${post.repost_by}')
				word_wrap:   true
				text_size:   text_size_small
				text_color:  app.txt_color_dim
				wrap_shrink: models.v_scrollbar_width
				offset_y:    -2
			)
		}

		mut author := author_timestamp_text(post.author, post.created_at)
		if idx <= first_post_idx {
			author = '${r_chevron} ${author} ${l_chevron}'
		}
		post_ui << widgets.link_label(
			text:        author
			text_size:   text_size
			text_color:  app.txt_color_bold
			word_wrap:   true
			wrap_shrink: models.v_scrollbar_width
			on_click:    fn [post, mut app] () {
				if !app.is_click_handled() {
					app.set_click_handled()
					os.open_uri(post.bsky_link_uri) or { ui.message_box(err.msg()) }
				}
			}
		)

		record_text := xtra.sanitize_text(post.text)
		if record_text.len > 0 {
			post_ui << widgets.link_label(
				text:        record_text
				word_wrap:   true
				text_size:   text_size
				text_color:  app.txt_color
				wrap_shrink: models.v_scrollbar_width
			)
		}

		quote_text := xtra.sanitize_text(post.quote_post_text)
		if post.quote_post_author.len > 0 && quote_text.len > 0 {
			quote_author := author_timestamp_text(post.quote_post_author, post.quote_post_created_at)
			shrink := models.v_scrollbar_width * 2
			post_ui << ui.row(
				widths:   [ui.compact, ui.stretch]
				children: [
					ui.rectangle(
						width: 1
						color: app.hline_color
					),
					ui.column(
						spacing:  post_spacing
						children: [
							widgets.link_label(
								text:        quote_author
								word_wrap:   true
								text_size:   text_size_small
								text_color:  app.txt_color_bold
								wrap_shrink: shrink
								offset_x:    models.v_scrollbar_width
							),
							widgets.link_label(
								text:        quote_text
								word_wrap:   true
								text_size:   text_size_small
								text_color:  app.txt_color
								wrap_shrink: shrink
								offset_x:    models.v_scrollbar_width
							),
							widgets.link_label(
								text:        xtra.sanitize_text(post.quote_post_link_title)
								word_wrap:   true
								text_size:   text_size_small
								text_color:  app.txt_color_link
								wrap_shrink: shrink
								offset_x:    models.v_scrollbar_width
								on_click:    quote_post_link_click_handler(post, mut app)
							),
						]
					),
				]
			)
		}

		if post.link_uri.len > 0 && post.link_title.len > 0 {
			post_ui << widgets.link_label(
				text:        xtra.sanitize_text(post.link_title)
				word_wrap:   true
				text_size:   text_size_small
				text_color:  app.txt_color_link
				wrap_shrink: models.v_scrollbar_width
				on_click:    fn [post, mut app] () {
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
		posts_ui << ui.column(
			id:       post.id
			spacing:  post_spacing
			children: post_ui
		)
	}

	app.timeline_posts_ui = posts_ui
}

// draw_timeline is used in Window's on_draw()
// function so it can occur on the UI thread
pub fn draw_timeline(mut w ui.Window, mut app App) {
	app.timeline_posts_mutex.lock()
	defer { app.timeline_posts_mutex.unlock() }

	if app.timeline_posts_ui.len == 0 {
		return
	}

	mut notice := app.timeline_posts_ui[0].id != app.old_post_id
	if mut sv_stack := w.get[ui.Stack](id_timeline_scrollview) {
		if sv_stack.scrollview.offset_y == 0 {
			sv_stack.remove()
			mut tl := ui.column()
			sv_stack.add(child: tl)
			tl.add(children: app.timeline_posts_ui)
			app.timeline_posts_ui = []
			notice = false
		}
	}

	title := if notice { '${l_chevron} Kite ${r_chevron}' } else { 'Kite' }
	app.window.set_title(title)
}

fn author_timestamp_text(author string, created_at time.Time) string {
	auth := xtra.remove_non_ascii(author)
	time_short := created_at
		.utc_to_local()
		.relative_short()
		.fields()[0]
	timestamp := if time_short == '0m' { 'now' } else { time_short }
	return xtra.truncate_long_fields('${auth} • ${timestamp}')
}

fn post_counts(post Post) string {
	return '• replies ${xtra.short_size(post.replies)} ' +
		'• reposts ${xtra.short_size(post.reposts)} ' + '• likes ${xtra.short_size(post.likes)}'
}

fn quote_post_link_click_handler(post Post, mut app App) ?widgets.LinkLabelClickFn {
	if post.quote_post_link_uri.len == 0 {
		return none
	}
	return fn [post, mut app] () {
		if !app.is_click_handled() {
			app.set_click_handled()
			os.open_uri(post.quote_post_link_uri) or { ui.message_box(err.msg()) }
		}
	}
}
