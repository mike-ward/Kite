import atprotocol
import ui

@[heap]
struct Login {
	name     string
	password string
}

fn create_login_view(mut app App) &ui.Widget {
	login := &Login{}

	return ui.column(
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
				margin:   ui.Margin{0, 0, 0, 150}
				children: [
					ui.button(
						text:     'Login'
						on_click: fn [mut app, login] (_ &ui.Button) {
							app.login(login)
						}
					),
				]
			),
		]
	)
}

fn (mut app App) login(login Login) {
	session := atprotocol.create_session(login.name, login.password) or {
		ui.message_box(err.str())
		return
	}
	app.settings = Settings{
		...app.settings
		session: session
	}
	save_settings(app.settings)
	remove_login_view(mut app)
	start_timeline(mut app)
}

fn refresh_session(mut app App) {
	if mut refresh := atprotocol.refresh_session(app.settings.session) {
		app.settings = Settings{
			...app.settings
			session: atprotocol.Session{
				...app.settings.session
				access_jwt:  refresh.access_jwt
				refresh_jwt: refresh.refresh_jwt
			}
		}
		save_settings(app.settings)
		println('refresh session succeeded')
	} else {
		save_settings(Settings{})
		eprintln(err.msg())
	}
}
