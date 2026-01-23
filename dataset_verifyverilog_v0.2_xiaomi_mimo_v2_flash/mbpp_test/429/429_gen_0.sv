module and_tuples(
    input [7:0] tuple1_0,
    input [7:0] tuple1_1,
    input [7:0] tuple1_2,
    input [7:0] tuple1_3,
    input [7:0] tuple2_0,
    input [7:0] tuple2_1,
    input [7:0] tuple2_2,
    input [7:0] tuple2_3,
    output [7:0] result_0,
    output [7:0] result_1,
    output [7:0] result_2,
    output [7:0] result_3
);

    assign result_0 = tuple1_0 & tuple2_0;
    assign result_1 = tuple1_1 & tuple2_1;
    assign result_2 = tuple1_2 & tuple2_2;
    assign result_3 = tuple1_3 & tuple2_3;

endmodule