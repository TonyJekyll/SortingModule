`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:08:38 10/24/2021 
// Design Name: 
// Module Name:    comparator 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module comparator #(
	parameter DATA_WIDTH = 8 
    )(
    input oen,
    input [DATA_WIDTH - 1 : 0] comp_in_word_A,
    input [DATA_WIDTH - 1 : 0] comp_in_word_B,
    output [DATA_WIDTH - 1 : 0] comp_out_word_A,
    output [DATA_WIDTH - 1 : 0] comp_out_word_B
    );

    assign comp_out_word_A = (oen) ? ((comp_in_word_B > comp_in_word_A) ? comp_in_word_A : comp_in_word_B) : comp_in_word_A;
    assign comp_out_word_B = (oen) ? ((comp_in_word_B > comp_in_word_A) ? comp_in_word_B : comp_in_word_A) : comp_in_word_B;

endmodule

module decoder #(
	parameter ADR_WIDTH = 3
	)(
	input [ADR_WIDTH - 1 : 0] decoder_i,
	output [2**ADR_WIDTH - 1 : 0] decoder_o
	);

	localparam [2**ADR_WIDTH - 1 : 0] mask = 32'hAAAAAAAA;

	reg [ADR_WIDTH - 1 : 0] decoder_i_prev = 0;
	reg [2**ADR_WIDTH - 1 : 0] decoder_o_r = 0;
	assign decoder_o = decoder_o_r;

	always @(decoder_i) begin
		decoder_o_r = mask >> 2**ADR_WIDTH - decoder_i;
	end

endmodule