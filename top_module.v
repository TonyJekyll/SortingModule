`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:28:57 10/23/2021 
// Design Name: 
// Module Name:    top_module 
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
module top_module #(
	parameter DATA_WIDTH = 8,
	parameter ADR_WIDTH = 5
)(
	input clk_i,
	input async_rst_i,
	input sop_i,
	input eop_i,
	input [DATA_WIDTH - 1 : 0] data_i,
	input val_i,

	output sop_o,
	output eop_o,
	output [DATA_WIDTH - 1 : 0] data_o,
	output val_o,
	output busy_o
    );

	reg [DATA_WIDTH - 1 : 0] inner_buffer [0 : 2**ADR_WIDTH - 1]; // inner buffer for write input stream, sorting und read to output stream
	reg [ADR_WIDTH : 0] words_counter; // reverse counter for words. On recieve mode increase output, on tramnsmit - decrease
	reg [ADR_WIDTH : 0] words_count; // count of recieved words
	reg [ADR_WIDTH : 0] cycle_counter1;
	reg [ADR_WIDTH : 0] cycle_counter2; // need only for Callkhose realization
	reg cycle_counter_direction = 1; // if direction = 1 "+", else "-"

	// interface registers
	reg sop_o_r = 1'b0;
	reg eop_o_r = 1'b0;
	reg [DATA_WIDTH - 1 : 0] data_o_r = 0;
	reg val_o_r = 1'b0;
	reg busy_o_r = 1'b0;

	assign sop_o = sop_o_r;
	assign eop_o = eop_o_r;
	assign data_o = data_o_r;
	assign val_o = val_o_r;
	assign busy_o = busy_o_r;

	// FSM state constants. One bit reserved for available extensions of module
	localparam IDLE = 4'b0000; // IDLE state
	localparam ONSR = 4'b0001; // On Start Recieve state
	localparam ONR = 4'b0010;  // On Recieve state. It's have some questions about 
	localparam ONER = 4'b0011; // On End of Recieve state
	localparam ONW = 4'b0100;  // On work (for example on sort) state
	localparam ONST = 4'b0101; // On Start Transmit state
	localparam ONT = 4'b0110;  // On Transmit state
	localparam ONET = 4'b0111; // On End Transmit state

	reg [3:0] current_state = IDLE;

	wire [DATA_WIDTH - 1 : 0] outputs_comps_A [0 : 2**ADR_WIDTH - 2];
	wire [DATA_WIDTH - 1 : 0] outputs_comps_B [0 : 2**ADR_WIDTH - 2];
	wire [2**ADR_WIDTH - 1 : 0] oen_for_comparators;
	reg [DATA_WIDTH - 1 : 0] data_sorted [0 : 2**ADR_WIDTH - 1];

	// creating output enable signals for comparators
	decoder #(
		.ADR_WIDTH(ADR_WIDTH)
	) decoder_instance(
		.decoder_i(cycle_counter1),
		.decoder_o(oen_for_comparators)
	);

	// connecting 2**N-1 comparators with output enables and data
    generate 
		genvar i;
		for (i = 1; i < 2**ADR_WIDTH; i = i + 1)
		begin:instance_of_comparators
			comparator #(
				.DATA_WIDTH(DATA_WIDTH)
				) comparators (
					.oen((i > words_count - 1) ? 1'b0 : oen_for_comparators[i - 1]),
					.comp_in_word_A(inner_buffer[i - 1]),
					.comp_in_word_B(inner_buffer[i]),
					.comp_out_word_A(outputs_comps_A[i - 1]),
					.comp_out_word_B(outputs_comps_B[i - 1])
				);
		end
	endgenerate

	///* generate combinational logic - comparators for words in input buffer
	generate // Available some troubles in high frequency :-(
		genvar k;
		for (k = 0; k < 2**ADR_WIDTH; k = k + 1)
		begin:sorting
		always @ * begin
			case (k)
			0 : begin : case_0
				if (oen_for_comparators[0]) begin
					data_sorted[0] = outputs_comps_A[0];
				end
				else begin
					data_sorted[0] = inner_buffer[0];
				end
			end
			2**ADR_WIDTH - 1 : begin: case_end
				if (oen_for_comparators[2**ADR_WIDTH - 2]) begin
					data_sorted[2**ADR_WIDTH - 1] = outputs_comps_B[2**ADR_WIDTH - 2];
				end
				else begin
					data_sorted[2**ADR_WIDTH - 1] = inner_buffer[2**ADR_WIDTH - 1];
				end
			end
			default : begin : case_default
				if (oen_for_comparators[k]) begin
					data_sorted[k] = outputs_comps_A[k];
				end
				else begin
					if (oen_for_comparators[k - 1]) begin
						data_sorted[k] = outputs_comps_B[k - 1];
					end
					else begin
						data_sorted[k] = inner_buffer[k];
					end
				end
			end
			endcase
		end
			
		end
	endgenerate

	generate // sync logic for input buffer: rewrite sort_data into input buffer
		genvar j;
		for (j = 0; j < 2**ADR_WIDTH; j = j + 1)
		begin:update_buffer
			always @(posedge clk_i) begin
				if (async_rst_i) begin
					inner_buffer[j] <= 0;
					data_sorted[j] <= 0;
				end 
				else if (clk_i) begin
					if (current_state == ONW && cycle_counter1 != 0) begin
						inner_buffer[j] <= data_sorted[j];
					end
				end
			end
		end
	endgenerate

	always @(posedge clk_i or posedge async_rst_i) begin
		if (async_rst_i) begin
			busy_o_r <= 1'b0;
			sop_o_r <= 1'b0;
			eop_o_r <= 1'b0;
			data_o_r <= 0;
			val_o_r <= 1'b0;
			words_counter <= 0;
			current_state <= IDLE;
		end
		else if (clk_i) begin
			case (current_state)
			IDLE : begin
				if (sop_i) begin
					if (val_i) begin
						inner_buffer[0] <= data_i;
						words_counter <= 1;
					end
					if (eop_i) begin
						current_state <= ONST;
						words_count <= 1'b1;
						busy_o_r <= 1'b1;
					end else begin
						current_state <= ONR;
					end
				end
			end
			ONR : begin

				if (val_i) begin
					inner_buffer[words_counter] <= data_i;
					words_counter <= words_counter + 1;
				end

				if (eop_i) begin
					busy_o_r <= 1'b1;
					cycle_counter1 <= 1;
					cycle_counter_direction <= 1;
					current_state <= ONW;
					words_count <= words_counter + 1;
				end
				
			end
			ONW : begin
				// More efficient realization of bubble sort. For hardware realization need 2*N-3 cycles with N = number of words
				if (cycle_counter_direction) begin
					if (cycle_counter1 < words_count) begin	
						cycle_counter1 <= cycle_counter1 + 1;
					end
					else begin
						cycle_counter_direction <= ~cycle_counter_direction;
						cycle_counter1 <= cycle_counter1 - 1;
					end
				end
				else begin
					if (cycle_counter1 > 0) begin
						cycle_counter1 <= cycle_counter1 - 1;
					end
					else begin
						current_state <= ONST;
						cycle_counter_direction <= ~cycle_counter_direction;
					end
				end
			end
			ONST : begin
				sop_o_r <= 1'b1;
				val_o_r <= 1'b1; // all data is valid! Maybe in last create another clk for output interface
				data_o_r <= inner_buffer[words_count - words_counter];
				inner_buffer[words_count - words_counter] <= 0;
				if (words_counter > 1'b1) begin
					words_counter <= words_counter - 1'b1;
					current_state <= ONT;
				end
				else begin
					eop_o_r <= 1'b1;
					current_state <= ONET;
				end
			end
			ONT : begin
				sop_o_r <= 1'b0;
				data_o_r <= inner_buffer[words_count - words_counter];
				if (words_counter > 1'b1) begin
					words_counter <= words_counter - 1'b1;
				end
				else begin
					eop_o_r <= 1'b1;
					current_state <= ONET;
				end
			end
			ONET : begin
				val_o_r <= 1'b0;
				sop_o_r <= 1'b0;
				eop_o_r <= 1'b0;
				busy_o_r <= 1'b0;
				data_o_r <= 0;
				words_counter <= 0;
				current_state <= IDLE;
			end
			default : begin // error in current realization 
				// TODO place for catch exceptions
			end
			endcase
		end
	end

endmodule
