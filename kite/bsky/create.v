module bsky

import json
import net.http

const pds_host = 'https://bsky.social/xrpc'

pub struct BlueskySession {
pub:
	handle          string
	email           string
	email_confirmed bool   @[json: 'emailConfirmed']
	access_jwt      string @[json: 'accessJwt']
	refresh_jwt     string @[json: 'refreshJwt']
}

pub fn create_session(identifier string, password string) !BlueskySession {
	data := '{"identifier": "${identifier}", "password": "${password}"}'
	response := http.post_json('${pds_host}/com.atproto.server.createSession', data)!

	return match response.status() {
		.ok { json.decode(BlueskySession, response.body) }
		else { error(response.status_msg) }
	}
}
