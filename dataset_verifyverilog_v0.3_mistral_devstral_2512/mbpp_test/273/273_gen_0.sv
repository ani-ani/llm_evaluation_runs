module array_subtractor(
    input signed [7:0] a_0,
    input signed [7:0] a_1,
    input signed [7:0] a_2,
    input signed [7:0] b_0,
    input signed [7:0] b_1,
    input signed [7:0] b_2,
    output signed [7:0] result_0,
    output signed [7:0] result_1,
    output signed [7:0] result_2
);

    assign result_0 = a_0 - b_0;
    assign result_1 = a_1 - b_1;
    assign result_2 = a_2 - b_2;

endmodule