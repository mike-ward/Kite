import atprotocol
import os
import toml
import ui

const settings_file = '.kite.toml'

pub struct Settings {
pub:
	width   int = 300
	height  int = 900
	session atprotocol.BlueskySession
}

fn (s Settings) is_valid() bool {
	return s.session.handle.len > 0 && s.session.email.len > 0 && s.session.access_jwt.len > 0
		&& s.session.refresh_jwt.len > 0
}

fn Settings.load_settings() Settings {
	path := get_settings_path()
	if os.exists(path) {
		contents := os.read_file(path) or { '' }
		return toml.decode[Settings](contents) or { Settings{} }
	}
	return Settings{}
}

fn (settings Settings) save_settings() {
	contents := toml.encode(settings)
	path := get_settings_path()
	os.write_file(path, contents) or { ui.message_box(err.str()) }
}

fn get_settings_path() string {
	home_dir := os.home_dir()
	path := os.join_path_single(home_dir, settings_file)
	return path
}
