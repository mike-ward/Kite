import arrays
import regex
import math
import ui

fn truncate_long_fields(s string) string {
	return arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return match true {
			elem.len > 35 { elem[..20] + '...' }
			else { elem }
		}
	})
}

fn remove_non_ascii(s string) string {
	// convert smart quotes to regular quotes
	s1 := arrays.join_to_string[string](s.fields(), ' ', fn (elem string) string {
		return elem
			.replace('“', '"')
			.replace('”', '"')
			.replace('’', "'")
			.replace('‘', "'")
			.replace('—', '--')
	})
	// strip out non-ascii characters
	if mut query := regex.regex_opt(r"[^' ',!-~]") {
		return query.replace(s1, '')
	}
	return s1
}

fn remove_www_links(s string) string {
	if mut query := regex.regex_opt(r'www\.\S+') {
		return query.replace(s, '')
	}
	return s
}

fn sanitize_text(s string) string {
	l := remove_www_links(s)
	t := truncate_long_fields(l)
	return remove_non_ascii(t)
}

fn short_size(size int) string {
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

fn wrap_text(s string, width_dpi int, mut dtw ui.DrawTextWidget) string {
	mut wrap := ''
	mut line := ''
	dtw.load_style()
	ss := s.replace('\n', ' ')
	for field in ss.fields() {
		tw := dtw.text_width(line + ' ' + field)
		if tw > width_dpi {
			wrap += '${line}\n'
			line = field
		} else {
			if line.len > 0 {
				line += ' '
			}
			line += field
		}
	}
	line = line.trim_space()
	if line.len > 0 {
		wrap += line
	}
	return wrap
}
