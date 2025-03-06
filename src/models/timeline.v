module models

import bsky
import math
import net.http
import os
import stbi
import time
import xtra

const kite_dir = 'kite'
const image_tmp_dir = os.join_path(os.temp_dir(), kite_dir)

@[heap]
pub struct Timeline {
pub:
	posts []Post
}

@[heap]
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
	quote_post_author     string
	quote_post_created_at time.Time
	quote_post_text       string
	quote_post_link_title string
	quote_post_link_uri   string
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
	name := if d_name.len > 0 { d_name } else { handle }
	path, alt := post_image(post)
	bsky_link_uri := bluesky_post_link(post)

	// links are displayed below post text.
	// If link appears in text, remove it from text.
	mut text := post.post.record.text
	mut uri, mut title := external_link(post)
	inline_uri, byte_start, byte_end := inline_link(post)
	if xtra.indexes_in_string(text, byte_start, byte_end) {
		uri = inline_uri
		title = text[byte_start..byte_end]
		text = text[0..byte_start] + text[byte_end..]
	}

	// quoted links are displayed below quoted text.
	// If link appears in quoted text, remove it from quoted text.
	mut q_text := get_quote_post_text(post)
	q_uri, mut q_title, q_byte_start, q_byte_end := get_quote_post_link(post)
	if xtra.indexes_in_string(q_text, q_byte_start, q_byte_end) {
		uri = q_uri
		q_title = q_text[q_byte_start..q_byte_end]
		q_text = q_text[0..q_byte_start] + q_text[q_byte_end..]
	}

	return Post{
		id:                    post.post.uri
		author:                name
		created_at:            time.parse_iso8601(post.post.record.created_at) or { time.utc() }
		text:                  text
		link_uri:              uri
		link_title:            title
		image_path:            path
		image_alt:             alt
		repost_by:             repost_by(post)
		replies:               post.post.replies
		reposts:               post.post.reposts + post.post.quotes
		likes:                 post.post.likes
		bsky_link_uri:         bsky_link_uri
		quote_post_author:     get_quote_post_author(post)
		quote_post_created_at: get_quote_post_created_at(post)
		quote_post_text:       q_text
		quote_post_link_title: q_title
		quote_post_link_uri:   q_uri
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
	if external.uri.len > 0 {
		title := if external.title.len > 0 { external.title } else { external.uri }
		return external.uri, title
	}
	return '', ''
}

// get_post_image downloads the first image blob assciated with the post
// and returns the file path where the image is stored and the alt text
// for that image.
fn post_image(post bsky.BlueskyPost) (string, string) {
	if post.post.record.embed.images.len > 0 {
		for image in post.post.record.embed.images {
			cid := image.image.ref.link
			tmp_file := image_tmp_file_path(cid)
			if os.exists(tmp_file) {
				return tmp_file, image.alt
			}
		}
	} else if post.post.record.embed.media.images.len > 0 {
		for image in post.post.record.embed.media.images {
			cid := image.image.ref.link
			tmp_file := image_tmp_file_path(cid)
			if os.exists(tmp_file) {
				return tmp_file, image.alt
			}
		}
	} else if post.post.embed.thumbnail.len > 0 {
		cid := post.post.embed.cid
		tmp_file := image_tmp_file_path(cid)
		if os.exists(tmp_file) {
			return tmp_file, ''
		}
	} else if post.post.embed.record.value.embed.images.len > 0 {
		for image in post.post.embed.record.value.embed.images {
			cid := image.image.ref.link
			tmp_file := image_tmp_file_path(cid)
			if os.exists(tmp_file) {
				return tmp_file, image.alt
			}
		}
	}
	return '', ''
}

// get_timeline_images retrieves images from bluesky.
// Instead of direct links, an identitier (cid) is specified.
// The api also requires the authors identifier (did)
pub fn get_timeline_images(timeline bsky.BlueskyTimeline) {
	os.mkdir_all(image_tmp_dir) or { eprintln(err) }

	// There are several places wehre images are buried.
	// Similar and yet different enough to make for messy code.
	for post in timeline.posts {
		if post.post.record.embed.images.len > 0 {
			for image in post.post.record.embed.images {
				if image.image.ref.link.len > 0 {
					cid := image.image.ref.link
					image_tmp_file := image_tmp_file_path(cid)
					if !os.exists(image_tmp_file) {
						blob := bsky.get_blob(post.post.author.did, cid) or {
							eprintln(err)
							continue
						}
						save_image(image_tmp_file, blob) or {
							eprintln(err)
							continue
						}
					}
				}
			}
		} else if post.post.record.embed.media.images.len > 0 {
			for image in post.post.record.embed.media.images {
				if image.image.ref.link.len > 0 {
					cid := image.image.ref.link
					image_tmp_file := image_tmp_file_path(cid)
					if !os.exists(image_tmp_file) {
						blob := bsky.get_blob(post.post.author.did, cid) or {
							eprintln(err)
							continue
						}
						save_image(image_tmp_file, blob) or {
							eprintln(err)
							continue
						}
					}
				}
			}
		} else if post.post.embed.thumbnail.len > 0 {
			cid := post.post.embed.cid
			image_tmp_file := image_tmp_file_path(cid)
			if !os.exists(image_tmp_file) {
				response := http.get(post.post.embed.thumbnail) or {
					eprintln(err.msg())
					continue
				}
				if response.status() != .ok {
					eprintln(response.status())
					continue
				}
				save_image(image_tmp_file, response.body) or {
					eprintln(err)
					continue
				}
			}
		} else if post.post.embed.record.value.embed.images.len > 0 {
			for image in post.post.embed.record.value.embed.images {
				if image.image.ref.link.len > 0 {
					cid := image.image.ref.link
					image_tmp_file := image_tmp_file_path(cid)
					if !os.exists(image_tmp_file) {
						blob := bsky.get_blob(post.post.embed.record.author.did, cid) or {
							eprintln(err)
							continue
						}
						save_image(image_tmp_file, blob) or {
							eprintln(err)
							continue
						}
					}
				}
			}
		}
	}
}

fn save_image(name string, blob string) ! {
	m_img := stbi.load_from_memory(blob.str, blob.len) or { return err }
	ratio := f64(m_img.height) / f64(m_img.width)
	r_img := stbi.resize_uint8(m_img, image_width, int(image_width * ratio)) or { return err }
	height := math.min(max_image_height, r_img.height)

	stbi.stbi_write_jpg(name, r_img.width, height, r_img.nr_channels, r_img.data, 90) or {
		return err
	}
}

fn has_embed_post(post bsky.BlueskyPost) bool {
	return post.post.embed.record.type.contains('#viewRecord')
		&& post.post.embed.record.value.type.contains('post')
}

fn get_quote_post_author(post bsky.BlueskyPost) string {
	if has_embed_post(post) {
		handle := post.post.embed.record.author.handle
		name := post.post.embed.record.author.display_name
		return if name.len > 0 { name } else { handle }
	}
	return ''
}

fn get_quote_post_created_at(post bsky.BlueskyPost) time.Time {
	if has_embed_post(post) {
		return time.parse_iso8601(post.post.embed.record.value.created_at) or { time.Time{} }
	}
	return time.Time{}
}

fn get_quote_post_text(post bsky.BlueskyPost) string {
	if has_embed_post(post) {
		return post.post.embed.record.value.text
	}
	return ''
}

fn get_quote_post_link(post bsky.BlueskyPost) (string, string, int, int) {
	embed := post.post.embed.record.value.embed
	facets := post.post.embed.record.value.facets
	if has_embed_post(post) && embed.type.contains('external') {
		title := if embed.external.title.len > 0 { embed.external.title } else { embed.external.uri }
		return embed.external.uri, title, 0, 0
	} else if facets.len > 0 { // usually a link to a video
		for facet in facets {
			for feature in facet.features {
				if feature.uri.len > 0 {
					return feature.uri, feature.uri, facets[0].index.byte_start, facets[0].index.byte_end
				}
			}
		}
	}

	return '', '', 0, 0
}

fn image_tmp_file_path(cid string) string {
	return os.join_path_single(image_tmp_dir, '${cid}.jpg')
}

fn inline_link(post bsky.BlueskyPost) (string, int, int) {
	for facet in post.post.record.facets {
		for feature in facet.features {
			if feature.type.contains('#link') {
				return feature.uri, facet.index.byte_start, facet.index.byte_end
			}
		}
	}
	return '', 0, 0
}

pub fn prune_disk_image_cache() {
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
