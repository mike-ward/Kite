module bsky

import json
import net.http
import time

const error_title = 'kite error'

pub struct BlueskyTimeline {
pub:
	posts []BlueskyPost @[json: 'feed']
}

pub struct BlueskyPost {
pub:
	post   struct {
	pub:
		uri     string
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
			reply      struct {
			pub:
				parent struct {
				pub:
					cid string
				}
				root   struct {
				pub:
					cid string
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

pub fn get_timeline(session BlueskySession) !BlueskyTimeline {
	response := http.fetch(
		method: .get
		url:    '${pds_host}/app.bsky.feed.getTimeline?limit=50'
		header: http.new_header(
			key:   .authorization
			value: 'Bearer ${session.access_jwt}'
		)
	)!

	// println(response.body)
	return match response.status() {
		// vfmt off
		.ok          { json.decode(BlueskyTimeline, response.body) }
		.bad_request { error_timeline('${response.status_msg})') }
		else         { error(response.status_msg) }
		// vfmt on
	}
}

pub fn error_timeline(s string) BlueskyTimeline {
	return BlueskyTimeline{
		posts: [
			struct {
				post: struct {
					author: struct {
						handle:       error_title
						display_name: error_title
					}
					record: struct {
						text:       s
						created_at: time.now().format_rfc3339()
					}
				}
			},
		]
	}
}
