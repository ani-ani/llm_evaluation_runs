module odd_position_checker(
    input [7:0] arr [0:7],
    input [2:0] len,
    output result
);
    wire valid0, valid1, valid2, valid3, valid4, valid5, valid6, valid7;
    assign valid0 = (3'd0 < len) ? (arr[0][0] == 1'b0) : 1'b1;
    assign valid1 = (3'd1 < len) ? (arr[1][0] == 1'b1) : 1'b1;
    assign valid2 = (3'd2 < len) ? (arr[2][0] == 1'b0) : 1'b1;
    assign valid3 = (3'd3 < len) ? (arr[3][0] == 1'b1) : 1'b1;
    assign valid4 = (3'd4 < len) ? (arr[4][0] == 1'b0) : 1'b1;
    assign valid5 = (3'd5 < len) ? (arr[5][0] == 1'b1) : 1'b1;
    assign valid6 = (3'd6 < len) ? (arr[6][0] == 1'b0) : 1'b1;
    assign valid7 = (3'd7 < len) ? (arr[7][0] == 1'b1) : 1'b1;
    assign result = valid0 & valid1 & valid2 & valid3 & valid4 & valid5 & valid6 & valid7;
endmodule