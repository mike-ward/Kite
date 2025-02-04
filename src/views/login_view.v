module views

import models { App, Settings }
import atprotocol
import ui

@[heap]
struct Login {
	name     string
	password string
}

pub fn create_login_view(mut app App) &ui.Widget {
	login := &Login{}

	column := ui.column(
		margin:   ui.Margin{20, 20, 20, 20}
		spacing:  5
		children: [
			ui.label(text: 'Bluesky Login', text_color: app.txt_color),
			ui.textbox(
				max_len:     20
				width:       200
				placeholder: 'email'
				text:        &login.name
			),
			ui.textbox(
				max_len:     50
				width:       200
				placeholder: 'password'
				text:        &login.password
			),
			ui.column(
				margin:   ui.Margin{
					left: 150
				}
				children: [
					ui.button(
						text:     'Login'
						on_click: fn [mut app, login] (_ &ui.Button) {
							do_login(login, mut app)
						}
					),
				]
			),
		]
	)

	return column
}

fn do_login(login Login, mut app App) {
	session := atprotocol.create_session(login.name, login.password) or {
		ui.message_box(err.str())
		return
	}
	app.settings = Settings{
		...app.settings
		session: session
	}
	app.settings.save_settings()
	app.change_view(create_timeline_view())
	app.start_timeline(build_timeline)
}
