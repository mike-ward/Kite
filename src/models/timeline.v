module models

import bsky
import time
import os
import stbi

pub const image_width = 278

const kite_dir = 'kite'
const image_tmp_dir = os.join_path(os.temp_dir(), kite_dir)

pub struct Timeline {
pub:
	posts []Post
}

pub struct Post {
pub:
	id                    string
	author                string
	created_at            time.Time
	text                  string
	link_uri              string
	link_title            string
	image_path            string
	image_alt             string
	repost_by             string
	replies               int
	reposts               int
	likes                 int
	bsky_link_uri         string
	embed_post_author     string
	embed_post_created_at time.Time
	embed_post_text       string
	embed_post_link_title string
	embed_post_link_uri   string
}

pub fn from_bluesky_timeline(timeline bsky.BlueskyTimeline, max_posts int) Timeline {
	mut posts := []Post{cap: max_posts}
	mut post_count := 0

	for post in timeline.posts {
		if post.post.record.reply.parent.cid.len > 0 || post.post.record.reply.root.cid.len > 0 {
			// don't display stand alone replies, no context'
			continue
		}
		posts << from_bluesky_post(post)
		post_count += 1
		if post_count > max_posts {
			break
		}
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
	bsky_link_uri := bluesky_post_link(post)
	e_uri, e_title := get_embed_post_link(post)

	return Post{
		id:                    post.post.uri
		author:                if d_name.len > 0 { d_name } else { handle }
		created_at:            time.parse_iso8601(post.post.record.created_at) or { time.utc() }
		text:                  post.post.record.text
		link_uri:              uri
		link_title:            title
		image_path:            path
		image_alt:             alt
		repost_by:             repost_by(post)
		replies:               post.post.replies
		reposts:               post.post.reposts + post.post.quotes
		likes:                 post.post.likes
		bsky_link_uri:         bsky_link_uri
		embed_post_author:     get_embed_post_author(post)
		embed_post_created_at: get_embed_post_created_at(post)
		embed_post_text:       get_embed_post_text(post)
		embed_post_link_title: e_title
		embed_post_link_uri:   e_uri
	}
}

fn bluesky_post_link(post bsky.BlueskyPost) string {
	id := post.post.uri.all_after_last('.post/')
	handle := post.post.author.handle
	return 'https://bsky.app/profile/${handle}/post/${id}'
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
		tmp_file := image_tmp_file_path(cid)
		if os.exists(tmp_file) {
			return tmp_file, image.alt
		}
	}
	return '', ''
}

pub fn get_timeline_images(timeline bsky.BlueskyTimeline) {
	os.mkdir_all(image_tmp_dir) or { eprintln(err) }

	for post in timeline.posts {
		if post.post.record.embed.images.len > 0 {
			image := post.post.record.embed.images[0]
			if image.image.ref.link.len > 0 {
				cid := image.image.ref.link
				image_tmp_file := image_tmp_file_path(cid)
				if !os.exists(image_tmp_file) {
					blob := bsky.get_blob(post.post.author.did, cid) or {
						eprintln(err)
						continue
					}
					m_img := stbi.load_from_memory(blob.str, blob.len) or {
						eprintln(err)
						continue
					}
					ratio := match image.aspect_ratio.width != 0 && image.aspect_ratio.height != 0 {
						true { f64(image.aspect_ratio.height) / f64(image.aspect_ratio.width) }
						else { 1.0 }
					}
					r_img := stbi.resize_uint8(m_img, image_width, int(image_width * ratio)) or {
						eprintln(err)
						continue
					}
					stbi.stbi_write_jpg(image_tmp_file, r_img.width, r_img.height, r_img.nr_channels,
						r_img.data, 90) or { eprintln(err) }
				}
			}
		}
	}
}

fn has_embed_post(post bsky.BlueskyPost) bool {
	return post.post.embed.record.type.contains('#viewRecord')
		&& post.post.embed.record.value.type.contains('post')
}

fn get_embed_post_author(post bsky.BlueskyPost) string {
	if has_embed_post(post) {
		handle := post.post.embed.record.author.handle
		name := post.post.embed.record.author.display_name
		return if name.len > 0 { name } else { handle }
	}
	return ''
}

fn get_embed_post_created_at(post bsky.BlueskyPost) time.Time {
	if has_embed_post(post) {
		return time.parse_iso8601(post.post.embed.record.value.created_at) or { time.Time{} }
	}
	return time.Time{}
}

fn get_embed_post_text(post bsky.BlueskyPost) string {
	if has_embed_post(post) {
		return post.post.embed.record.value.text
	}
	return ''
}

fn get_embed_post_link(post bsky.BlueskyPost) (string, string) {
	embed := post.post.embed.record.value.embed
	if has_embed_post(post) && embed.type.contains('external') {
		return embed.external.uri, embed.external.title
	}
	return '', ''
}

fn image_tmp_file_path(cid string) string {
	return os.join_path_single(image_tmp_dir, '${cid}.jpg')
}

pub fn clear_image_cache() {
	entries := os.ls(image_tmp_dir) or { return }
	for entry in entries {
		path := os.join_path_single(image_tmp_dir, entry)
		last := os.file_last_mod_unix(path)
		date := time.unix(last)
		diff := time.utc() - date
		if diff > time.hour {
			os.rm(path) or {}
		}
	}
}
