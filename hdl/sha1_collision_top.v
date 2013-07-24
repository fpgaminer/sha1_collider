/*
*
* Copyright (c) 2012-2013 fpgaminer@bitcoin-mining.com
*
*
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
* 
*/

`define IDX(x) (((x)+1)*(8)-1):((x)*(8))
`define IDX4(x) (((x)+1)*(4)-1):((x)*(4))


// Finds a collision with a given SHA1 hash, given some information about the
// input message.
module sha1_collision_top (
	input CLK_100MHZ
);

	// Clock Generator
	wire hash_clk;

	main_pll clk_blk (
		.CLK_IN1 (CLK_100MHZ),
		.CLK_OUT1 (hash_clk)
	);


	// SHA1 Hashers
	wire [511:0] expanded_message0, expanded_message1;
	wire [159:0] hash0, hash1;

	sha1 hasher0 ( .clk (hash_clk), .rx_data (expanded_message0), .tx_hash (hash0) );
	sha1 hasher1 ( .clk (hash_clk), .rx_data (expanded_message1), .tx_hash (hash1) );


	// Comm
	reg [59:0] golden_nonce = 0;
	reg golden_nonce_found = 1'b0;
	wire comm_new_work;
	wire [55:0] comm_fixed_data;
	wire [159:0] comm_target_hash;
	wire [59:0] comm_start_nonce;

	jtag_comm comm_blk (
		.rx_hash_clk (hash_clk),
		.rx_golden_nonce_found (golden_nonce_found),
		.rx_golden_nonce (golden_nonce),
		.tx_new_work (comm_new_work),
		.tx_fixed_data (comm_fixed_data),
		.tx_target_hash (comm_target_hash),
		.tx_start_nonce (comm_start_nonce)
	);


	// Nonce Counter
	wire [59:0] nonce;
	wire [59:0] nonce0, nonce1;

	bcd_counter # (.STEP(2)) counter_blk (
		.clk (hash_clk),
		.rst (golden_nonce_found | comm_new_work),
		.rx_reset_value (comm_start_nonce),
		.tx_nonce (nonce)
	);

	bcd_add counter_add0 ( .clk (hash_clk), .rx_a (nonce), .rx_b (4'd0), .tx_sum (nonce0) );
	bcd_add counter_add1 ( .clk (hash_clk), .rx_a (nonce), .rx_b (4'd1), .tx_sum (nonce1) );


	// Controller
	reg [14*4-1:0] fixed_data = 56'h35691903801083;
	reg [159:0] target_hash = 160'h754d1309a35eb188292dc628947a0e70ab7ccd2a; //160'h3b8d562adb792985a7393a6ab228aa6e7526410a;
	// secret nonce is 000000509803065
	

	expand_message msg0 ( .clk (hash_clk), .rx_fixed_data (fixed_data), .rx_nonce (nonce0), .tx_expanded_message (expanded_message0) );
	expand_message msg1 ( .clk (hash_clk), .rx_fixed_data (fixed_data), .rx_nonce (nonce1), .tx_expanded_message (expanded_message1) );
	
	
	always @ (posedge hash_clk)
	begin
		fixed_data <= comm_fixed_data;
		target_hash <= comm_target_hash;

		// Constantly updating the golden nonce until we've found
		// a real golden nonce allows the external controller to
		// monitor progress.
		if (!golden_nonce_found)
			golden_nonce <= nonce;

		// Collision found?
		if (hash0 == target_hash || hash1 == target_hash)
			golden_nonce_found <= 1'b1;

		if (comm_new_work)
			golden_nonce_found <= 1'b0;
	end
	
endmodule


module expand_message (
	input clk,
	input [14*4-1:0] rx_fixed_data,
	input [59:0] rx_nonce,
	output reg [511:0] tx_expanded_message
);

	always @ (posedge clk)
	begin
		tx_expanded_message <= {32'd192, 32'h0, 224'h0, 32'h80000000, rx_fixed_data[`IDX(2)], rx_fixed_data[`IDX(1)], rx_fixed_data[`IDX(0)], 8'h00, rx_fixed_data[`IDX(6)], rx_fixed_data[`IDX(5)], rx_fixed_data[`IDX(4)], rx_fixed_data[`IDX(3)], {4'b0,rx_nonce[`IDX4(2)]}, {4'b0,rx_nonce[`IDX4(1)]}, {4'b0,rx_nonce[`IDX4(0)]}, 8'h00, {4'b0,rx_nonce[`IDX4(6)]}, {4'b0,rx_nonce[`IDX4(5)]}, {4'b0,rx_nonce[`IDX4(4)]}, {4'b0,rx_nonce[`IDX4(3)]}, {4'b0,rx_nonce[`IDX4(10)]}, {4'b0,rx_nonce[`IDX4(9)]}, {4'b0,rx_nonce[`IDX4(8)]}, {4'b0,rx_nonce[`IDX4(7)]}, {4'b0,rx_nonce[`IDX4(14)]}, {4'b0,rx_nonce[`IDX4(13)]}, {4'b0,rx_nonce[`IDX4(12)]}, {4'b0,rx_nonce[`IDX4(11)]}};
	end

endmodule

