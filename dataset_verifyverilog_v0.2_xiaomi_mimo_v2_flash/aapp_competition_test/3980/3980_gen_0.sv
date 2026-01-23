module max_beauty_permutation(
    output [3:0] p_0,
    output [3:0] p_1,
    output [3:0] p_2,
    output [3:0] p_3,
    output [3:0] p_4,
    output [3:0] p_5,
    output [3:0] p_6,
    output [3:0] p_7,
    output [3:0] p_8,
    output [3:0] p_9,
    output [3:0] p_10,
    output [3:0] p_11,
    output [3:0] p_12,
    output [3:0] p_13,
    output [3:0] p_14,
    output [3:0] p_15
);

    // Assign each output to the bitwise complement of its index (i.e., 15 ^ i)
    assign p_0 = 4'b1111 ^ 4'd0;  // 15
    assign p_1 = 4'b1111 ^ 4'd1;  // 14
    assign p_2 = 4'b1111 ^ 4'd2;  // 13
    assign p_3 = 4'b1111 ^ 4'd3;  // 12
    assign p_4 = 4'b1111 ^ 4'd4;  // 11
    assign p_5 = 4'b1111 ^ 4'd5;  // 10
    assign p_6 = 4'b1111 ^ 4'd6;  // 9
    assign p_7 = 4'b1111 ^ 4'd7;  // 8
    assign p_8 = 4'b1111 ^ 4'd8;  // 7
    assign p_9 = 4'b1111 ^ 4'd9;  // 6
    assign p_10 = 4'b1111 ^ 4'd10; // 5
    assign p_11 = 4'b1111 ^ 4'd11; // 4
    assign p_12 = 4'b1111 ^ 4'd12; // 3
    assign p_13 = 4'b1111 ^ 4'd13; // 2
    assign p_14 = 4'b1111 ^ 4'd14; // 1
    assign p_15 = 4'b1111 ^ 4'd15; // 0

endmodule