module extra

import os
import time

pub fn install_kite_segmentation_fault_handler() {
	os.signal_opt(.segv, kite_segmentation_fault_handler) or { panic(err) }
}

fn kite_segmentation_fault_handler(signal os.Signal) {
	t := time.now()
	signal_number := int(signal)
	eprintln('signal ${signal_number}: segmentation fault: ${t}')
	print_backtrace()
	exit(128 + signal_number)
}
