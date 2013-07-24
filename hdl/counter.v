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



// A 15 digit binary encoded decimal counter
module bcd_counter # (
	parameter STEP = 1
) (
	input clk,
	input rst,
	input [59:0] rx_reset_value,
	output reg [59:0] tx_nonce
);

genvar i;
generate
	for (i = 0; i < 15; i=i+1) begin : C
		reg [3:0] a = 4'd0;
		wire [3:0] tx_s;
		wire tx_c;

		if (i == 0)
			bcd_add_digit adder (.rx_a (a), .rx_b (STEP), .rx_c (0), .tx_s (tx_s), .tx_c (tx_c));
		else
			bcd_add_digit adder (.rx_a (a), .rx_b (0), .rx_c (C[i-1].tx_c), .tx_s (tx_s), .tx_c (tx_c));

		always @ (posedge clk)
		begin
			a <= tx_s;
			tx_nonce[(i+1)*4-1:i*4] <= tx_s;

			if (rst)
				a <= rx_reset_value[(i+1)*4-1:i*4];
		end
	end
endgenerate

endmodule


module bcd_add_digit (
	input [3:0] rx_a,
	input [3:0] rx_b,
	input rx_c,
	output [3:0] tx_s,
	output tx_c
);

	wire [4:0] s = rx_a + rx_b + rx_c;
	wire [4:0] s_wrap = s + 5'd6;

	assign tx_s = (s > 5'd9) ? s_wrap[3:0] : s[3:0];
	assign tx_c = s > 5'd9;

endmodule


// Add a 15 digit and a 1 digit BCD number together
module bcd_add (
	input clk,
	input [59:0] rx_a,
	input [3:0] rx_b,
	output reg [59:0] tx_sum
);

genvar i;
generate
	for (i = 0; i < 15; i=i+1) begin : C
		wire [3:0] tx_s, b;
		wire c, tx_c;

		if (i == 0)
			assign {c, b} = {1'b0, rx_b};
		else
			assign {c, b} = {C[i-1].tx_c, 4'b0};

		bcd_add_digit adder (.rx_a (rx_a[(i+1)*4-1:i*4]), .rx_b (b), .rx_c (c), .tx_s (tx_s), .tx_c (tx_c));

		always @ (posedge clk)
			tx_sum[(i+1)*4-1:i*4] <= tx_s;
	end
endgenerate

endmodule

