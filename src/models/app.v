module models

import arrays
import bsky
import gx
import sync
import time
import ui

const max_timeline_posts = 25
pub const id_main_column = '_main-view-column_'

pub type BuildTimelineFn = fn (timeline Timeline, mut app App)

@[heap]
pub struct App {
mut:
	click_handled bool
pub mut:
	window               &ui.Window = unsafe { nil }
	settings             Settings
	timeline_posts_ui    []ui.Widget
	timeline_posts_mutex &sync.Mutex = sync.new_mutex()
	first_post_id        string
	old_post_id          string
	picture_cache        map[string]int
	bg_color             gx.Color = gx.rgb(0x30, 0x30, 0x30)
	txt_color            gx.Color = gx.rgb(0xbb, 0xbb, 0xbb)
	txt_color_dim        gx.Color = gx.rgb(0x80, 0x80, 0x80)
	txt_color_bold       gx.Color = gx.rgb(0xfe, 0xfe, 0xfe)
	txt_color_link       gx.Color = gx.rgb(0x64, 0x95, 0xed)
	hline_color          gx.Color = gx.rgb(0x50, 0x50, 0x50)
	hline_color_first    gx.Color = gx.rgb(0x34, 0x65, 0xad)
}

pub fn (mut app App) login(name string, password string, on_login fn (mut app App)) {
	session := bsky.create_session(name, password) or {
		ui.message_box(err.str())
		return
	}
	app.settings = Settings{
		...app.settings
		session: session
	}
	app.settings.save_settings()
	on_login(mut app)
}

pub fn (mut app App) change_view(view &ui.Widget) {
	if mut stack := app.window.get[ui.Stack](id_main_column) {
		stack.remove()
		stack.add(children: [view])
	} else {
		eprintln('${@METHOD}(): id_main_column not found')
	}
}

// refresh_session gets a new bluesky session token
pub fn (mut app App) refresh_session() {
	if mut refresh := bsky.refresh_bluesky_session(app.settings.session) {
		app.settings = Settings{
			...app.settings
			session: bsky.BlueskySession{
				...app.settings.session
				access_jwt:  refresh.access_jwt
				refresh_jwt: refresh.refresh_jwt
			}
		}
		app.settings.save_settings()
	} else {
		eprintln(err.msg())
	}
}

pub fn (mut app App) start_timeline(build_timeline_fn BuildTimelineFn) {
	prune_disk_image_cache()
	go app.timeline_loop(build_timeline_fn)
}

fn (mut app App) timeline_loop(build_timeline_fn BuildTimelineFn) {
	ten_minutes := 10 * time.minute
	mut refresh_time := time.now()

	for {
		if time.since(refresh_time) > ten_minutes {
			app.refresh_session()
			refresh_time = time.now()
		}

		bluesky_timeline := bsky.get_timeline(app.settings.session) or {
			Settings{}.save_settings()
			bsky.error_timeline(err.msg())
		}

		get_timeline_images(bluesky_timeline)
		timeline := from_bluesky_timeline(bluesky_timeline, max_timeline_posts)

		build_timeline_fn(timeline, mut app)
		app.prune_picture_cache(timeline.posts)
		time.sleep(time.minute)
	}
}

// As a rule, once a click is handled, I don't want other click handlers to run.
// There is not a way currently to stop a click event from propagating to other
// click handlers so this hack will have to do for now.
pub fn (mut app App) set_click_handled() {
	app.click_handled = true
	go app.unset_click_handled()
}

fn (mut app App) unset_click_handled() {
	time.sleep(250 * time.millisecond)
	app.click_handled = false
}

pub fn (mut app App) is_click_handled() bool {
	return app.click_handled
}

pub fn (mut app App) prune_picture_cache(posts []Post) {
	if mut pic := find_pic_widget(app.window) {
		paths := posts.map(it.image_path).filter(it.len > 0)
		for path in app.picture_cache.keys() {
			if path !in paths {
				pic.remove_from_cache(path)
				app.picture_cache.delete(path)
			}
		}
	}
}

fn find_pic_widget(window ui.Window) ?&ui.Picture {
	for _, w in window.widgets {
		if w is ui.Picture {
			return w
		}
	}
	return none
}

pub fn (mut app App) update_first_post(timeline Timeline) int {
	first_post_id := timeline.posts[0].id
	if app.first_post_id != first_post_id {
		app.old_post_id = match app.first_post_id.len == 0 {
			true { first_post_id }
			else { app.first_post_id }
		}
		app.first_post_id = first_post_id
	}
	first_post_idx := arrays.index_of_first(timeline.posts, fn [app] (_ int, post Post) bool {
		return post.id == app.old_post_id
	})
	return first_post_idx - 1
}
