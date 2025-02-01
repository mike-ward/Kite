@[heap]
struct App {
mut:
	window                &ui.Window = unsafe { nil }
	settings              Settings
	refresh_session_count int
	timeline_started      bool
	login_view            &ui.Widget = unsafe { nil }
	timeline_view         &ui.Widget = unsafe { nil }
	bg_color              gx.Color   = gx.rgb(0x30, 0x30, 0x30)
	txt_color             gx.Color   = gx.rgb(0xbb, 0xbb, 0xbb)
	txt_color_dim         gx.Color   = gx.rgb(0x80, 0x80, 0x80)
	txt_color_bold        gx.Color   = gx.rgb(0xfe, 0xfe, 0xfe)
	txt_color_link        gx.Color   = gx.rgb(0x64, 0x95, 0xed)
}
