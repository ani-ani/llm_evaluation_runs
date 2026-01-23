module tuple_to_int (
    input [3:0] digit_0,
    input [3:0] digit_1,
    input [3:0] digit_2,
    input [3:0] digit_3,
    input [3:0] digit_4,
    input [3:0] digit_5,
    input [3:0] digit_6,
    input [3:0] digit_7,
    output [31:0] result
);
assign result = digit_0 * 1 + digit_1 * 10 + digit_2 * 100 + digit_3 * 1000 + digit_4 * 10000 + digit_5 * 100000 + digit_6 * 1000000 + digit_7 * 10000000;
endmodule