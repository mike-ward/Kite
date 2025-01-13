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
		author := f.post.author
		name := if author.display_name.len > 0 { author.display_name } else { author.handle }

		created := time.parse_iso8601(f.post.record.created_at) or { time.utc() }
		relative := created.utc_to_local().relative()

		header := ui.label(text: '${name} ∙ ${relative}')
		content := ui.label(text: '${f.post.record.text.wrap(width: 45)}')
		divider := ui.label(text: ' ')

		post := ui.column(
			children: [
				header,
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
