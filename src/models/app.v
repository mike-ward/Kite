module models

import gx
import ui
import sync

pub const id_main_column = '_main-column_'

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
