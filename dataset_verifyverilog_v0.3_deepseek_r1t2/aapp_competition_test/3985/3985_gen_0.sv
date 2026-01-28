module max_operations(
    input [3:0] e0,
    input [3:0] e1,
    input [3:0] e2,
    input [3:0] e3,
    input [3:0] e4,
    input [3:0] e5,
    input [3:0] e6,
    input [3:0] e7,
    output [4:0] result
);
    wire [4:0] sum_left = e0 + e2 + e4 + e6;
    wire [4:0] sum_right = e1 + e3 + e5 + e7;
    assign result = (sum_left < sum_right) ? sum_left : sum_right;
endmodule