module extra

import bsky
import os
import stbi
import time

pub const image_prefix = 'kite_image'

pub fn get_timeline_images(timeline bsky.Timeline) {
	for post in timeline.posts {
		if post.post.record.embed.images.len > 0 {
			image := post.post.record.embed.images[0]
			if image.image.ref.link.len > 0 {
				cid := image.image.ref.link
				tmp_file := os.join_path_single(os.temp_dir(), '${image_prefix}_${cid}')
				ratio := match image.aspect_ratio.width != 0 && image.aspect_ratio.height != 0 {
					true { f64(image.aspect_ratio.height) / f64(image.aspect_ratio.width) }
					else { 1.0 }
				}
				if !os.exists(tmp_file) {
					blob := bsky.get_blob(post.post.author.did, cid) or { continue }
					tmp_file_ := tmp_file + '_'
					os.write_file(tmp_file_, blob) or { continue }
					img_ := stbi.load(tmp_file_) or { continue }
					os.rm(tmp_file_) or { continue }
					width := 215 // any bigger and images take up too much vertical space
					img := stbi.resize_uint8(img_, width, int(width * ratio)) or { continue }
					stbi.stbi_write_png(tmp_file, img.width, img.height, img.nr_channels,
						img.data, img.width * img.nr_channels) or { continue }
				}
			}
		}
	}
}

pub fn clear_image_cache() {
	tmp_dir := os.temp_dir()
	entries := os.ls(tmp_dir) or { [] }
	for entry in entries {
		if entry.starts_with(image_prefix) {
			path := os.join_path_single(tmp_dir, entry)
			last := os.file_last_mod_unix(path)
			date := time.unix(last)
			diff := time.utc() - date
			if diff > time.hour {
				os.rm(path) or {}
			}
		}
	}
}
