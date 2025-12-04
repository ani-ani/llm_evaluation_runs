module median_trapezium (
    input [31:0] base1,
    input [31:0] base2,
    input [31:0] height,
    output reg [31:0] median
);

wire [32:0] sum_ext = {1'b0, base1} + {1'b0, base2};
assign median = {sum_ext[32], sum_ext[31:1]};

endmodule