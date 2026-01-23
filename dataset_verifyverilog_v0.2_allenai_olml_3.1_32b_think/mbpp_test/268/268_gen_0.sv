module star_number(
    input [15:0] n,
    output [31:0] result
);
assign result = (6 * n * (n - 1) + 1) << 16;
endmodule