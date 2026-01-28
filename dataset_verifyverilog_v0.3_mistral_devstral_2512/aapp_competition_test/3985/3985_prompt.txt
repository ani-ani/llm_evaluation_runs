module max_operations(
    input [3:0] e0, e1, e2, e3, e4, e5, e6, e7,
    output [4:0] result
);
    wire [4:0] sum_left = e0 + e2 + e4 + e6;
    wire [4:0] sum_right = e1 + e3 + e5 + e7;
    assign result = (sum_left < sum_right) ? sum_left : sum_right;
endmodule