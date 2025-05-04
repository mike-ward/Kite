module views

import models { App }
import ui

@[heap]
struct Crendentials {
	name     string
	password string
}

pub fn create_login_view(mut app App) &ui.Widget {
	credentials := &Crendentials{}

	column := ui.column(
		margin:   ui.Margin{20, 20, 20, 20}
		spacing:  5
		children: [
			ui.label(text: 'Bluesky Login', text_color: app.txt_color),
			ui.textbox(
				max_len:     20
				width:       200
				placeholder: 'email'
				text:        &credentials.name
			),
			ui.textbox(
				max_len:     50
				width:       200
				placeholder: 'password'
				text:        &credentials.password
			),
			ui.column(
				margin:   ui.Margin{
					left: 150
				}
				children: [
					ui.button(
						text:     'Login'
						on_click: fn [mut app, credentials] (_ &ui.Button) {
							app.login(credentials.name, credentials.password, on_login)
						}
					),
				]
			),
		]
	)

	return column
}

fn on_login(mut app App) {
	timeline_view := create_timeline_view(mut app)
	app.change_view(timeline_view)
	app.start_timeline(build_timeline_posts)
}
