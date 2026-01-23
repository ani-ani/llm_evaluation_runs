module tuple_subtract(
    input [7:0] tuple1_0,
    input [7:0] tuple1_1,
    input [7:0] tuple1_2,
    input [7:0] tuple2_0,
    input [7:0] tuple2_1,
    input [7:0] tuple2_2,
    output [7:0] result_0,
    output [7:0] result_1,
    output [7:0] result_2
);
assign result_0 = (signed(tuple1_0) - signed(tuple2_0));
assign result_1 = (signed(tuple1_1) - signed(tuple2_1));
assign result_2 = (signed(tuple1_2) - signed(tuple2_2));
endmodule