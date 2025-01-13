import atprotocol
import time
import ui

fn create_timeline_view(mut app App) &ui.Widget {
	return ui.column(
		id:         'timeline'
		margin:     ui.Margin{
			left: 5
		}
		scrollview: true
	)
}

fn update_timeline(mut app App) {
	timeline := app.session.get_timeline() or { atprotocol.Timeline{} }

	mut feed := []ui.Widget{}
	for f in timeline.feed {
		created := time.parse_iso8601(f.post.record.created_at) or { time.utc() }
		local := created.utc_to_local().relative()

		author := ui.label(text: '${f.post.author.display_name} ∙ ${local}')
		content := ui.label(text: '${f.post.record.text.wrap(width: 45)}')
		divider := ui.label(text: ' ')

		post := ui.column(
			children: [
				author,
				content,
				divider,
			]
		)
		feed << post
	}
	if mut tl := app.window.get[ui.Stack]('timeline') {
		for tl.children.len > 0 {
			tl.remove()
		}
		tl.add(children: feed)
	}
}

fn start_timeline(mut app App) {
	for {
		update_timeline(mut app)
		time.sleep(time.minute)
	}
}
