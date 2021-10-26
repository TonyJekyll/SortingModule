//==============================================================================
//  Author : Vadim Kuznetsov
//  E-mail : vdmsov@yandex.ru
//  File   : sequence_generator.v
//  Data   : 26-10-2021
//==============================================================================

module sequence_generator
#(    
    parameter   NUM_WORDS = 8
)
(

    input           clk,
    input           reset_n,

    input           in_busy,

    output  [7:0]   out_data,
    output          out_valid,
    output          out_sop,
    output          out_eop
);

//------------------------------------------------------------------------------

reg [7:0] words_counter;
reg [7:0] data;

//------------------------------------------------------------------------------

assign out_valid    = (words_counter >= 1) && (words_counter <= NUM_WORDS) ? 1 : 0;
assign out_sop      = (words_counter == 1) ? 1 : 0;
assign out_eop      = (words_counter == NUM_WORDS) ? 1 : 0;
assign out_data     = out_valid ? data : 0;

//------------------------------------------------------------------------------

always @ (posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        words_counter <= 0;
    end else begin

        if (words_counter == NUM_WORDS || in_busy) begin
            words_counter <= 0;                
        end else begin
            words_counter <= words_counter + 1;
        end

        data = $random%256;

    end
end


//------------------------------------------------------------------------------

endmodule