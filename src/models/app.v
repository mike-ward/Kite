module models

import bsky
import extra
import gx
import ui
import sync
import time

pub const id_main_column = '_main-view-column_'

pub type BuildTimelineFn = fn (timeline Timeline, mut app App)

@[heap]
pub struct App {
pub mut:
	window               &ui.Window = unsafe { nil }
	settings             Settings
	timeline_posts       []ui.Widget
	timeline_posts_mutex &sync.Mutex = sync.new_mutex()
	bg_color             gx.Color    = gx.rgb(0x30, 0x30, 0x30)
	txt_color            gx.Color    = gx.rgb(0xbb, 0xbb, 0xbb)
	txt_color_dim        gx.Color    = gx.rgb(0x80, 0x80, 0x80)
	txt_color_bold       gx.Color    = gx.rgb(0xfe, 0xfe, 0xfe)
	txt_color_link       gx.Color    = gx.rgb(0x64, 0x95, 0xed)
	hline_color          gx.Color    = gx.rgb(0x50, 0x50, 0x50)
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

pub fn (app App) change_view(view &ui.Widget) {
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
	clear_image_cache()
	spawn app.timeline_loop(build_timeline_fn)
}

fn (mut app App) timeline_loop(build_timeline_fn BuildTimelineFn) {
	ten_minutes := 10 * time.minute
	mut refresh_time := time.now()
	for {
		bluesky_timeline := bsky.get_timeline(app.settings.session) or {
			Settings{}.save_settings()
			bsky.error_timeline(err.msg())
		}

		get_timeline_images(bluesky_timeline)
		timeline := from_bluesky_timeline(bluesky_timeline)
		build_timeline_fn(timeline, mut app)

		if time.since(refresh_time) > ten_minutes {
			extra.trace('refresh_session')
			app.refresh_session()
			refresh_time = time.now()
		}

		time.sleep(time.minute)
	}
}
