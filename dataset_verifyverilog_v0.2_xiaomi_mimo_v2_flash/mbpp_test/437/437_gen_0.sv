module remove_odd (
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [7:0] char_8,
    output [7:0] result_1,
    output [7:0] result_2,
    output [7:0] result_3,
    output [7:0] result_4
);

    assign result_1 = char_2;
    assign result_2 = char_4;
    assign result_3 = char_6;
    assign result_4 = char_8;

endmodule