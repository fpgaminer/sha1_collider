/*
*
* Copyright (c) 2012
* All rights reserved
*/

`define IDX(x) (((x)+1)*(32)-1):((x)*(32))


// Calculates the hash of rx_data which is an expanded message.
// The message must be small enough to fit into a single chunk, after
// expansion.
module sha1 (
	input clk,
	input [511:0] rx_data,
	output reg [159:0] tx_hash
);

	// Pre-calculation
	reg [31:0] pre_temp;
	reg [511:0] delay_data;

	always @ (posedge clk)
	begin
		pre_temp <= 32'hC3D2E1F0 + 32'h5A827999 + rx_data[`IDX(0)];
		delay_data <= rx_data;
	end


	// Rounds
genvar i;
generate
	for (i = 0; i < 80; i=i+1) begin : R
		wire [511:0] data, tx_data;
		wire [31:0] a, b, c, d, presum;
		wire [31:0] tx_a, tx_b, tx_c, tx_d, tx_presum;

		if (i == 0)
		begin
			assign data = delay_data;
			assign {a, b, c, d, presum} = {32'h67452301, 32'hEFCDAB89, 32'h98BADCFE, 32'h10325476, pre_temp};
		end
		else
		begin
			assign data = R[i-1].tx_data;
			assign {a, b, c, d, presum} = {R[i-1].tx_a, R[i-1].tx_b, R[i-1].tx_c, R[i-1].tx_d, R[i-1].tx_presum};
		end

		sha1_round # (.ROUND (i)) round (
			.clk (clk),
			.rx_w (data),
			.rx_a (a), .rx_b (b), .rx_c (c), .rx_d (d), .rx_presum (presum),
			.tx_w (tx_data),
			.tx_a (tx_a), .tx_b (tx_b), .tx_c (tx_c), .tx_d (tx_d), .tx_presum (tx_presum)
		);
	end
endgenerate


	// Calculate final hash
	reg [31:0] e_delay;
	always @ (posedge clk)
	begin
		e_delay <= R[78].tx_d;

		tx_hash[`IDX(4)] <= R[79].tx_a + 32'h67452301;
		tx_hash[`IDX(3)] <= R[79].tx_b + 32'hEFCDAB89;
		tx_hash[`IDX(2)] <= R[79].tx_c + 32'h98BADCFE;
		tx_hash[`IDX(1)] <= R[79].tx_d + 32'h10325476;
		tx_hash[`IDX(0)] <= e_delay + 32'hC3D2E1F0;
	end
	

endmodule


// A single round of SHA1
// presum is w[i] + k + e
module sha1_round # (
	parameter ROUND = 0
) (
	input clk,
	input [511:0] rx_w,
	input [31:0] rx_a, rx_b, rx_c, rx_d, rx_presum,
	output reg [511:0] tx_w,
	output reg [31:0] tx_a, tx_b, tx_c, tx_d, tx_presum
);

	// f and k assignments
generate
	wire [31:0] k = (ROUND < 19) ? 32'h5A827999 : (ROUND < 39) ? 32'h6ED9EBA1 : (ROUND < 59) ? 32'h8F1BBCDC : 32'hCA62C1D6;
	wire [31:0] f;

	if (ROUND <= 19)
		assign f = (rx_b & rx_c) | ((~rx_b) & rx_d);
	else if (ROUND <= 39)
		assign f = rx_b ^ rx_c ^ rx_d;
	else if (ROUND <= 59)
		assign f = (rx_b & rx_c) | (rx_b & rx_d) | (rx_c & rx_d);
	else
		assign f = rx_b ^ rx_c ^ rx_d;
endgenerate


	// The new w, before leftrotating
	wire [31:0] new_w = rx_w[`IDX(0)] ^ rx_w[`IDX(2)] ^ rx_w[`IDX(8)] ^ rx_w[`IDX(13)];


	always @ (posedge clk)
	begin
		tx_w[`IDX(15)] <= {new_w[30:0], new_w[31]};	// leftrotate 1
		tx_w[479:0] <= rx_w[511:32];

		tx_a <= {rx_a[26:0], rx_a[31:27]} + f + rx_presum;
		tx_b <= rx_a;
		tx_c <= {rx_b[1:0], rx_b[31:2]};
		tx_d <= rx_c;
		tx_presum <= rx_d + rx_w[`IDX(1)] + k;
	end

endmodule

