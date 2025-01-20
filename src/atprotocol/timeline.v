module atprotocol

import json
import net.http

pub struct Timeline {
pub:
	feeds []Feed @[json: 'feed']
}

pub struct Feed {
pub:
	post   struct {
	pub:
		author  struct {
		pub:
			handle       string
			display_name string @[json: 'displayName']
		}
		record  struct {
		pub:
			type       string @[json: '\$type']
			text       string @[json: 'text']
			created_at string @[json: 'createdAt']
		}
		embed   struct {
		pub:
			type     string @[json: '\$type']
			external struct {
			pub:
				uri         string
				title       string
				description string
				thumb       string
			}
		}
		replys  int @[json: 'replyCount']
		likes   int @[json: 'likeCount']
		reposts int @[json: 'repostCount']
		quotes  int @[json: 'quoteCount']
	}
	reason struct {
	pub:
		type string @[json: '\$type']
		by   struct {
		pub:
			handle       string
			display_name string @[json: 'displayName']
		}
	}
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
