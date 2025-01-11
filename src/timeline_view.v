import ui

fn timeline_view(app App) ui.Widget {
	return ui.column(
		widths:   ui.stretch
		heights:  [ui.compact, ui.stretch]
		children: [ui.button(
			text:     'Log In'
			on_click: app.login
		),
			ui.textbox(
				id:   'timeline'
				mode: .read_only | .multiline | .word_wrap
			)]
	)
}
