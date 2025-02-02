module extra

import time

pub fn debounce(fn_to_debounce fn (), delay time.Duration) fn () {
	mut last := [0]
	return fn [fn_to_debounce, delay, mut last] () {
		last[0] += 1
		current := last[0]
		spawn fn [fn_to_debounce, delay, last, current] () {
			time.sleep(delay)
			if current == last[0] {
				fn_to_debounce()
			}
		}()
	}
}
