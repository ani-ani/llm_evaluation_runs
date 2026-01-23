module elder_gui (
    input clk,
    input rst_n,
    input start,
    input [31:0] W_in,
    input [31:0] H_in,
    input [31:0] F_in,
    input [31:0] N_in,
    input [15:0] char_data,
    input char_valid,
    output reg char_read,
    output reg [15:0] out_char,
    output reg out_valid,
    output reg done
);

    // Default assignments
    always @(*) begin
        char_read = 0;
        out_char = 0;
        out_valid = 0;
        done = 0;
    end

endmodule
