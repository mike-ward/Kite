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
			ui.label(text: 'Bluesky Login'),
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
	app.session = atprotocol.create_session(login.name, login.password) or {
		ui.message_box(err.str())
		return
	}

	if mut stack := app.window.get[ui.Stack]('kite') {
		stack.remove(at: 0)
	}

	settings := Settings{
		session: app.session
	}

	save_settings(settings)
	spawn start_timeline(mut app)
}
