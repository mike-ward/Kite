module models

import bsky
import extra
import gx
import ui
import sync
import time

pub const id_main_column = '_main-view-column_'

@[heap]
pub struct App {
pub mut:
	window                &ui.Window = unsafe { nil }
	settings              Settings
	refresh_session_count int
	timeline_posts        []ui.Widget
	timeline_posts_mutex  &sync.Mutex = sync.new_mutex()
	bg_color              gx.Color    = gx.rgb(0x30, 0x30, 0x30)
	txt_color             gx.Color    = gx.rgb(0xbb, 0xbb, 0xbb)
	txt_color_dim         gx.Color    = gx.rgb(0x80, 0x80, 0x80)
	txt_color_bold        gx.Color    = gx.rgb(0xfe, 0xfe, 0xfe)
	txt_color_link        gx.Color    = gx.rgb(0x64, 0x95, 0xed)
	hline_color           gx.Color    = gx.rgb(0x50, 0x50, 0x50)
}

pub fn (app App) change_view(view &ui.Widget) {
	if mut stack := app.window.get[ui.Stack](id_main_column) {
		stack.remove()
		stack.add(children: [view])
	} else {
		eprintln('${@METHOD}(): id_main_column not found')
	}
}

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

pub type BuildTimelineFn = fn (timeline bsky.Timeline, mut app App)

pub fn (mut app App) start_timeline(build_timeline BuildTimelineFn) {
	extra.clear_image_cache()
	spawn fn [build_timeline] (mut app App) {
		for {
			app.update_timeline(build_timeline)
			app.refresh_session_count += 1
			if app.refresh_session_count % 10 == 0 { // Refresh every 10 minutes
				app.refresh_session()
			}
			time.sleep(time.minute)
		}
	}(mut app)
}

fn (mut app App) update_timeline(build_timeline BuildTimelineFn) {
	timeline := bsky.get_timeline(app.settings.session) or {
		Settings{}.save_settings()
		bsky.error_timeline(err.msg())
	}
	extra.get_timeline_images(timeline)
	build_timeline(timeline, mut app)
}
