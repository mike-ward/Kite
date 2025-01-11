module atprotocol

import json
import net.http

pub struct Timeline {
pub:
	feed []Feed
}

pub struct Feed {
pub:
	post Post
}

pub struct Post {
pub:
	author Author
	record Record
}

pub struct Author {
pub:
	display_name string @[json: 'displayName']
}

pub struct Record {
pub:
	text       string @[json: 'text']
	created_at string @[json: 'createdAt']
}

pub fn (session Session) get_timeline() !Timeline {
	response := http.fetch(
		method: .get
		url:    '${pds_host}/app.bsky.feed.getTimeline'
		header: http.new_header(
			key:   .authorization
			value: 'Bearer ${session.access_jwt}'
		)
	)!
	return json.decode(Timeline, response.body)
}
