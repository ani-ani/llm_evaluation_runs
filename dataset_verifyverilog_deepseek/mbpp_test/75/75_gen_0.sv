module divisible_tuples (
    input [7:0] K,
    input [7:0] tuple0_0, input [7:0] tuple0_1, input [7:0] tuple0_2,
    input [7:0] tuple1_0, input [7:0] tuple1_1, input [7:0] tuple1_2,
    input [7:0] tuple2_0, input [7:0] tuple2_1, input [7:0] tuple2_2,
    input [7:0] tuple3_0, input [7:0] tuple3_1, input [7:0] tuple3_2,
    output [3:0] valid_tuples
);
    wire valid0 = (tuple0_0 % K == 8'd0) && (tuple0_1 % K == 8'd0) && (tuple0_2 % K == 8'd0);
    wire valid1 = (tuple1_0 % K == 8'd0) && (tuple1_1 % K == 8'd0) && (tuple1_2 % K == 8'd0);
    wire valid2 = (tuple2_0 % K == 8'd0) && (tuple2_1 % K == 8'd0) && (tuple2_2 % K == 8'd0);
    wire valid3 = (tuple3_0 % K == 8'd0) && (tuple3_1 % K == 8'd0) && (tuple3_2 % K == 8'd0);
    assign valid_tuples = {valid3, valid2, valid1, valid0};
endmodule