import json
import os
import ui

const settings_file = '.kite.json'

pub struct Settings {
pub:
	handle          string
	email           string
	email_confirmed bool
	access_jwt      string
	refresh_jwt     string
}

fn (s Settings) is_valid() bool {
	return s.handle.len > 0 && s.email.len > 0 && s.access_jwt.len > 0 && s.refresh_jwt.len > 0
}

fn load_settings() Settings {
	path := get_settings_path()
	if os.exists(path) {
		contents := os.read_file(path) or { '' }
		return json.decode(Settings, contents) or { Settings{} }
	}
	return Settings{}
}

fn save_settings(settings Settings) {
	contents := json.encode_pretty(settings)
	path := get_settings_path()
	os.write_file(path, contents) or { ui.message_box(err.str()) }
}

fn get_settings_path() string {
	home_dir := os.home_dir()
	path := os.join_path_single(home_dir, settings_file)
	return path
}
