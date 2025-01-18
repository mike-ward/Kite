module atprotocol

import json
import net.http

pub struct Timeline {
pub:
	feed []Feed
}

pub struct Feed {
pub:
	post   Post
	reason Reason
}

pub struct Post {
pub:
	author Author
	record Record
}

pub struct Author {
pub:
	handle       string
	display_name string @[json: 'displayName']
}

pub struct Record {
pub:
	text       string @[json: 'text']
	created_at string @[json: 'createdAt']
}

pub struct Reason {
pub:
	rtype string @[json: '\$type']
	by    By
}

pub struct By {
pub:
	handle       string
	display_name string @[json: 'displayName']
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
	return match response.status() {
		.ok { json.decode(Timeline, response.body) }
		else { error(response.body) }
	}
}
