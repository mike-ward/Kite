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
	for field in s.fields() {
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
	if line.len > 0 {
		wrap += line
	}
	return wrap
}
