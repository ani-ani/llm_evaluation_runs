module sum_to_n(
    input [15:0] n,
    output [15:0] sum
);
    wire [16:0] n17 = {1'b0, n};
    wire [16:0] n_plus1 = n17 + 1'b1;
    wire [33:0] product = n17 * n_plus1;
    wire [33:0] product_shifted = product >> 1;
    assign sum = product_shifted[15:0];
endmodule