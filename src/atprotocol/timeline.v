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
			did          string
			handle       string
			display_name string @[json: 'displayName']
		}
		record  struct {
		pub:
			type       string @[json: '\$type']
			text       string
			created_at string @[json: 'createdAt']
			embed      struct {
			pub:
				type     string @[json: '\$type']
				images   []struct {
				pub:
					alt          string
					aspect_ratio struct {
					pub:
						width  int
						height int
					} @[json: 'aspectRatio']
					image        struct {
					pub:
						type      string @[json: '\$type']
						mime_type string @[json: 'mimeType']
						size      int
						ref       struct {
						pub:
							link string @[json: '\$link']
						}
					}
				}
				external struct {
				pub:
					title string
					uri   string
				}
			}
		}
		replies int @[json: 'replyCount']
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
		url:    '${pds_host}/app.bsky.feed.getTimeline?limit=25'
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
