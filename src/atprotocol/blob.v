module atprotocol

import net.http

pub fn get_blob(did string, cid string) !string {
	response := http.get('${pds_host}/com.atproto.sync.getBlob?did=${did}&cid=${cid}')!
	return match response.status() {
		.ok { response.body }
		else { error(response.status_msg) }
	}
}
