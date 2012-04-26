source utils.tcl
source jtag_comm.tcl

fpga_init


write_fpga_register 0x01 "0xab7ccd2a"
write_fpga_register 0x02 "0x947a0e70"
write_fpga_register 0x03 "0x292dc628"
write_fpga_register 0x04 "0xa35eb188"
write_fpga_register 0x05 "0x754d1309"
write_fpga_register 0x06 "0x03801083"
write_fpga_register 0x07 "0x00356919"
write_fpga_register 0x08 "0x00000000"
write_fpga_register 0x09 "0x00000000"


while {1} {
	puts [format %08X%08X [read_fpga_register 0xE] [read_fpga_register 0xD]]
	after 1000
}

