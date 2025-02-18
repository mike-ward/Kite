module extra

import arrays
import regex
import math
import ui

pub fn truncate_long_fields(s string) string {
	return arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return match true {
			elem.len > 35 { elem[..20] + '...' }
			else { elem }
		}
	})
}

pub fn remove_non_ascii(s string) string {
	// convert smart quotes to regular quotes
	s1 := arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		// These characters don't work with VUi for now
		return elem
			.replace('“', '"')
			.replace('”', '"')
			.replace('’', "'")
			.replace('‘', "'")
			.replace('—', '--')
			.replace('…', '...')
			.replace('&mdash;', '--')
			.replace(' ', ' ') // &nbsp;
	})
	// strip out non-ascii characters
	if mut query := regex.regex_opt(r"[^' ',!-ÿ]") {
		return query.replace(s1, '')
	}
	return s1
}

pub fn remove_links(s string) string {
	if mut www := regex.regex_opt(r'www\.\S+') {
		mut ss := www.replace(s, '')
		if mut https := regex.regex_opt(r'https://\S+') {
			ss = https.replace(ss, '')
		}
		return ss
	}
	return s
}

pub fn sanitize_text(s string) string {
	l := remove_links(s)
	t := truncate_long_fields(l)
	return remove_non_ascii(t)
}

pub fn short_size(size int) string {
	kb := 1000
	mut sz := f64(size)
	for unit in ['', 'K', 'M', 'G', 'T', 'P', 'E', 'Z'] {
		if sz < kb {
			short := match unit == '' {
				true { size.str() }
				else { math.round_sig(sz + .049999, 1).str() }
			}
			return '${short}${unit}'
		}
		sz /= kb
	}
	return size.str()
}

pub fn wrap_text(s string, width_dip int, mut dtw ui.DrawTextWidget) []string {
	mut wrap := []string{}
	mut line := ''
	for field in s.fields() {
		width := match line.len > 0 {
			true { dtw.text_width(line + ' ' + field) }
			else { dtw.text_width(field) }
		}
		if width >= width_dip {
			wrap << line
			line = field
		} else {
			line += match line.len > 0 {
				true { ' ' + field }
				else { field }
			}
		}
	}
	wrap << line
	return wrap
}
