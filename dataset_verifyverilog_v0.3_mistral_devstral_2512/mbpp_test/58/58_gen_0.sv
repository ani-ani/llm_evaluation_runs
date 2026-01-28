module opposite_signs(
    input signed [7:0] x,
    input signed [7:0] y,
    output result
);
    assign result = x[7] ^ y[7];
endmodule