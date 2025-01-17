module atprotocol

import json
import net.http

struct RefreshSession {
pub:
	access_jwt  string @[json: 'accessJwt']
	refresh_jwt string @[json: 'refreshJwt']
	active      string
}

pub fn refresh_session(session Session) !RefreshSession {
	response := http.fetch(
		method: .post
		url:    '${pds_host}/com.atproto.server.refreshSession'
		header: http.new_header(
			key:   .authorization
			value: 'Bearer ${session.refresh_jwt}'
		)
	) or { return error('failed to create header') }

	return json.decode(RefreshSession, response.body)!
}
