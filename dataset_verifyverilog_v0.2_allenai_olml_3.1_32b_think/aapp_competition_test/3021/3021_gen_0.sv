module alphabet_solver (
    input clk,
    input rst_n,
    input start,
    input [4:0] word_chars_0,
    input [4:0] word_chars_1,
    input [4:0] word_chars_2,
    input [4:0] word_chars_3,
    input [4:0] word_chars_4,
    input [4:0] word_chars_5,
    input [4:0] word_chars_6,
    input [4:0] word_chars_7,
    input [3:0] num_words,
    input [4:0] max_char,
    output reg [1:0] result_type,
    output reg [4:0] alphabet_0,
    output reg [4:0] alphabet_1,
    output reg [4:0] alphabet_2,
    output reg [4:0] alphabet_3,
    output reg [4:0] alphabet_4,
    output reg [4:0] alphabet_5,
    output reg [4:0] alphabet_6,
    output reg [4:0] alphabet_7,
    output reg [4:0] alphabet_8,
    output reg [4:0] alphabet_9,
    output reg [4:0] alphabet_10,
    output reg [4:0] alphabet_11,
    output reg [4:0] alphabet_12,
    output reg [4:0] alphabet_13,
    output reg [4:0] alphabet_14,
    output reg [4:0] alphabet_15,
    output reg done
);
    reg [1:0] result_type = 2'b00;
    reg [4:0] alphabet_0 = 5'b0;
    reg [4:0] alphabet_1 = 5'b0;
    reg [4:0] alphabet_2 = 5'b0;
    reg [4:0] alphabet_3 = 5'b0;
    reg [4:0] alphabet_4 = 5'b0;
    reg [4:0] alphabet_5 = 5'b0;
    reg [4:0] alphabet_6 = 5'b0;
    reg [4:0] alphabet_7 = 5'b0;
    reg [4:0] alphabet_8 = 5'b0;
    reg [4:0] alphabet_9 = 5'b0;
    reg [4:0] alphabet_10 = 5'b0;
    reg [4:0] alphabet_11 = 5'b0;
    reg [4:0] alphabet_12 = 5'b0;
    reg [4:0] alphabet_13 = 5'b0;
    reg [4:0] alphabet_14 = 5'b0;
    reg [4:0] alphabet_15 = 5'b0;
    reg done = 1'b0;
endmodule