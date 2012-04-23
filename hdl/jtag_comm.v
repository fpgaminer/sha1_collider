/*
*
* Copyright (c) 2012
* All Rights Reserved
*
*/


module jtag_comm (
	input rx_hash_clk,
	input rx_golden_nonce_found,
	input [59:0] rx_golden_nonce
);

	// JTAG
	wire jt_capture, jt_drck, jt_reset, jt_sel, jt_shift, jt_tck, jt_tdi, jt_update;
	wire jt_tdo;

	BSCAN_SPARTAN6 # (.JTAG_CHAIN(1)) jtag_blk (
		.CAPTURE(jt_capture),
		.DRCK(jt_drck),
		.RESET(jt_reset),
		.RUNTEST(),
		.SEL(jt_sel),
		.SHIFT(jt_shift),
		.TCK(jt_tck),
		.TDI(jt_tdi),
		.TDO(jt_tdo),
		.TMS(),
		.UPDATE(jt_update)
	);


	reg [3:0] addr = 4'hF;
	reg [37:0] dr;
	reg checksum;
	wire checksum_valid = ~checksum;
	wire [3:0] jtag_addr = dr[35:32];

	// Golden Nonce FIFO: from rx_hash_clk to TCK
	reg [60:0] golden_nonce_buf, golden_nonce;

	always @ (posedge rx_hash_clk)
	begin
		golden_nonce_buf <= {rx_golden_nonce_found, rx_golden_nonce};
		golden_nonce <= golden_nonce_buf;
	end


	assign jt_tdo = dr[0];


	always @ (posedge jt_tck or posedge jt_reset)
	begin
		if (jt_reset == 1'b1)
		begin
			dr <= 38'd0;
		end
		else if (jt_capture == 1'b1)
		begin
			// Capture-DR
			checksum <= 1'b1;
			dr[37:32] <= 6'd0;
			addr <= 4'hF;

			case (addr)
				4'h0: dr[31:0] <= 32'h01000100;
				4'h1: dr[31:0] <= golden_nonce[31:0];
				4'h2: dr[31:0] <= golden_nonce[60:32];
				4'h3: dr[31:0] <= 32'hFFFFFFFF;
				4'h4: dr[31:0] <= 32'hFFFFFFFF;
				4'h5: dr[31:0] <= 32'hFFFFFFFF;
				4'h6: dr[31:0] <= 32'hFFFFFFFF;
				4'h7: dr[31:0] <= 32'hFFFFFFFF;
				4'h8: dr[31:0] <= 32'hFFFFFFFF;
				4'h9: dr[31:0] <= 32'hFFFFFFFF;
				4'hA: dr[31:0] <= 32'hFFFFFFFF;
				4'hB: dr[31:0] <= 32'hFFFFFFFF;
				4'hC: dr[31:0] <= 32'h55555555;
				4'hD: dr[31:0] <= 32'hFFFFFFFF;
				4'hE: dr[31:0] <= 32'hFFFFFFFF;
				4'hF: dr[31:0] <= 32'hFFFFFFFF;
			endcase
		end
		else if (jt_shift == 1'b1)
		begin
			dr <= {jt_tdi, dr[37:1]};
			checksum <= checksum ^ jt_tdi;
		end
		else if (jt_update & checksum_valid)
		begin
			addr <= jtag_addr;
		end
	end


endmodule
