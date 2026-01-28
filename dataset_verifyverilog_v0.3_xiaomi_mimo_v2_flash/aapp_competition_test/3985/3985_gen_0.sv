module max_operations(
    input [3:0] e0, e1, e2, e3, e4, e5, e6, e7,
    output [4:0] result
);
    wire [4:0] sum_left = {1'b0, e0} + {1'b0, e2} + {1'b0, e4} + {1'b0, e6};
    wire [4:0] sum_right = {1'b0, e1} + {1'b0, e3} + {1'b0, e5} + {1'b0, e7};
    assign result = (sum_left < sum_right) ? sum_left : sum_right;
endmodule