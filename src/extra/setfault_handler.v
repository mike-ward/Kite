module extra

import os
import time

pub fn install_kite_segmentation_fault_handler() {
	start := time.now()
	handler := fn [start] (signal os.Signal) {
		t := time.now()
		signal_number := int(signal)
		eprintln('signal ${signal_number}: segmentation fault: ${t} (${t - start})')
		print_backtrace()
		exit(128 + signal_number)
	}
	os.signal_opt(.segv, handler) or { panic(err) }
}
