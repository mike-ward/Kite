module xtra

import os
import time

pub fn install_kite_segmentation_fault_handler() {
	start := time.now()
	handler := fn [start] (signal os.Signal) {
		now := time.now()
		elapsed := now - start
		signal_number := int(signal)
		eprintln('signal ${signal_number}: segmentation fault: ${now} (${elapsed})')
		print_backtrace()
		exit(128 + signal_number)
	}
	os.signal_opt(.segv, handler) or { panic(err) }
}
