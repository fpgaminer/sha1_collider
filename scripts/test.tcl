source utils.tcl
source jtag_comm.tcl

fpga_init


while {1} {
	puts [format %08X%08X [read_fpga_register 2] [read_fpga_register 1]]
	after 1000
}

