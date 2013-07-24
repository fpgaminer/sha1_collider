##
#
# Copyright (c) 2011-2013 fpgaminer@bitcoin-mining.com
#
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 
##


package require sha1
source utils.tcl
source jtag_comm.tcl


proc say_line {msg} {
	set t [clock format [clock seconds] -format "%D %T"]
	puts "\[$t\] $msg"
}

proc say_error {msg} {
	set t [clock format [clock seconds] -format "%D %T"]
	puts stderr "\[$t\] $msg"
}

proc convert_bcd {x} {
	return [string trimleft $x 0]
}

proc rand_digit {} {
	return [expr {int(rand() * 9.9999999)}]
}

proc rand_digit_string {x y} {
	set result ""

	for { set i 1 } { $i <= $x } { incr i } {
		set digit [rand_digit]
		set result "${result}${digit}"
	}

	return $result
}

proc pad_digit_string {x} {
	set result ""
	set len [string length $x]

	for { set i 0 } { $i < $len } { incr i } {
		set digit [string range $x $i $i]
		set result "${result}0${digit}"
	}

	return $result
}

proc convert.hex.to.string hex {
	foreach c [split $hex ""] {
		if {![string is xdigit $c]} {
			return "#invalid $hex"
		}
	}

	binary format H* $hex
}


# Loop until a new share is found, or timeout seconds have passed.
# Prints status updates every second.
proc wait_for_golden_ticket {timeout} {
	global total_accepted
	global total_rejected
	global global_start_time

	
	#puts "Current nonce"
	#set current_nonce [read_instance GNON]
	#puts $current_nonce
	set last_nonce [get_current_fpga_nonce]
	set begin_time [clock clicks -milliseconds]

	#puts "FPGA is now searching for lottery ticket..."

	while {$timeout > 0} {
		set golden_nonce [get_result_from_fpga]

		if {$golden_nonce != -1} {
			return $golden_nonce
		}

		# TODO: We may need to sleep for a small amount of time to avoid taxing the CPU
		# Or the JTAG comms might throttle back our CPU usage anyway.
		# If the FPGA had a proper results queue we could just sleep for a second, but
		# for now we might as well loop as fast as possible

		after 1000
		
		set now [clock clicks -milliseconds]
		if { [expr {$now - $begin_time}] >= 2000 } {
			incr timeout -2

			set current_nonce [get_current_fpga_nonce]
			set dt [expr {$now - $begin_time}]
			set begin_time $now

			if {$current_nonce < $last_nonce} {
				set nonces [expr {$current_nonce + (0xFFFFFFFF - $last_nonce) + 1}]
			} else {
				set nonces [expr {$current_nonce - $last_nonce + 1}]
			}

			set last_nonce $current_nonce

			if {$dt == 0} {
				set dt 1
			}

			set rate [expr {$nonces / ($dt * 1000.0)}]
			set current_time [clock seconds]
			# Adding 0.00001 to the denom is a quick way to avoid divide by zero :P
			# Each share is worth ~(2^32 / 1,000,000) MH/s
			set est_rate [expr {($total_accepted + $total_rejected) * 4294.967296 / ($current_time - $global_start_time + 0.00001)}]

			say_status $rate $est_rate $total_accepted $total_rejected
		}
	}

	return -1
}

puts " --- FPGA SHA1 Collider Tcl Script --- \n\n"


puts "Looking for and preparing FPGAs...\n"
if {[fpga_init] == -1} {
	puts stderr "No supported FPGAs found."
	puts "\n\n --- Shutting Down --- \n\n"
	exit
}

set fpga_name [get_fpga_name]
puts "FPGA Found: $fpga_name\n\n"


set RANDOM_WORK 0
source config.tcl

if {$RANDOM_WORK} {
	set start_nonce 0x0000000000000000
	set secret [rand_digit_string 11 1]
	set secret "0000$secret"
	set fixed_data [rand_digit_string 14 0]

	puts "Secret Nonce is: $secret"

	set secret [pad_digit_string $secret]
	set secretb [convert.hex.to.string $secret]
	set fixed_datab [convert.hex.to.string $fixed_data]
	set msg "$secretb\x00$fixed_datab\x00"
	set target_hash [sha1::sha1 $msg]
	
	set target_hash "0x$target_hash"
	set fixed_data "0x$fixed_data"
}


puts "Searching for...\nSHA1 (Unknown Nonce + 0x00 + $fixed_data + 0x00) == $target_hash\nStarting Nonce: $start_nonce\n"


push_work_to_fpga $target_hash $fixed_data $start_nonce

set begin_time [clock clicks -milliseconds]

after 500


while {1} {
	set golden_nonce [get_result_from_fpga]
	set now [clock clicks -milliseconds]
	set nonce [convert_bcd $golden_nonce]

	# Sometimes incorrect nonces are returned
	set check [regexp {^[1-9][0-9]*$} $nonce]
	if {! $check} {
		#puts $nonce
		continue
	}

	if {[string range $golden_nonce 0 0] == 1} {
		# Double check
		set golden_nonce2 [get_result_from_fpga]

		if {$golden_nonce2 != $golden_nonce} {
			continue
		}

		puts "Collision Found!\n"
		puts "-----------------"
		#puts [string range $golden_nonce 1 15]
		set nonce [expr {$nonce - 1000000000000000 - 168}]
		puts [format "%015lu" $nonce]
		puts "-----------------"
		puts "\n\n"
		break
	}

	set golden_nonce [convert_bcd $golden_nonce]

	set dt [expr {$now - $begin_time}]
	#puts "$golden_nonce $dt"
	set rate [expr {$golden_nonce / ($dt * 1000.0)}]
	set progress [expr {$golden_nonce * 100.0 / 999999999999999}]
	set nonces_remaining [expr {999999999999999 - $golden_nonce}]
	set time_remaining [expr {int($nonces_remaining * 0.5 / (1000000 * $rate))}]
	set days [expr {int($time_remaining / 86400)}]
	set time_remaining [expr {$time_remaining - ($days * 86400)}]
	set hours [expr {int($time_remaining / 3600)}]
	set time_remaining [expr {$time_remaining - ($hours * 3600)}]
	set minutes [expr {int($time_remaining / 60)}]
	#puts $nonces_remaining

	say_line [format "%.2f%% (%.2f MH/s) \[%s\] ~%d Days %d Hours %d Minutes Remaining" $progress $rate $golden_nonce $days $hours $minutes]

	after 2000
}


puts "\n\n --- Shutting Down --- \n\n"



