module models

import bsky
import time
import os
import stbi

const image_prefix = 'kite_image'

pub struct Timeline {
pub:
	posts []Post
}

pub struct Post {
pub:
	author     string
	created_at time.Time
	text       string
	link_uri   string
	link_title string
	image_path string
	image_alt  string
	repost_by  string
	replies    int
	reposts    int
	likes      int
}

pub fn from_bluesky_timeline(timeline bsky.BlueskyTimeline) Timeline {
	mut posts := []Post{}

	for post in timeline.posts {
		posts << from_bluesky_post(post)
	}
	return Timeline{
		posts: posts
	}
}

fn from_bluesky_post(post bsky.BlueskyPost) Post {
	handle := post.post.author.handle
	d_name := post.post.author.display_name
	uri, title := external_link(post)
	path, alt := post_image(post)

	return Post{
		author:     if d_name.len > 0 { d_name } else { handle }
		created_at: time.parse_iso8601(post.post.record.created_at) or { time.utc() }
		text:       post.post.record.text
		link_uri:   uri
		link_title: title
		image_path: path
		image_alt:  alt
		repost_by:  repost_by(post)
		replies:    post.post.replies
		reposts:    post.post.reposts + post.post.quotes
		likes:      post.post.likes
	}
}

fn repost_by(post bsky.BlueskyPost) string {
	return match post.reason.type.contains('Repost') {
		true {
			match post.reason.by.display_name.len > 0 {
				true { post.reason.by.display_name }
				else { post.reason.by.handle }
			}
		}
		else {
			''
		}
	}
}

fn external_link(post bsky.BlueskyPost) (string, string) {
	external := post.post.record.embed.external
	return match external.uri.len > 0 && external.title.trim_space().len > 0 {
		true { external.uri, external.title.trim_space() }
		else { '', '' }
	}
}

// get_post_image downloads the first image blob assciated with the post
// and returns the file path where the image is stored and the alt text
// for that image. Images are resized to reduce memory load.
fn post_image(post bsky.BlueskyPost) (string, string) {
	if post.post.record.embed.images.len > 0 {
		image := post.post.record.embed.images[0]
		cid := image.image.ref.link
		tmp_file := os.join_path_single(os.temp_dir(), '${image_prefix}_${cid}')
		if os.exists(tmp_file) {
			return tmp_file, image.alt
		}
	}
	return '', ''
}

pub fn get_timeline_images(timeline bsky.BlueskyTimeline) {
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
