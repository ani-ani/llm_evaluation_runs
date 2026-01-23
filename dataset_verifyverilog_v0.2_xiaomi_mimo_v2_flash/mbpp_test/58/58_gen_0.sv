module opposite_signs(
    input signed [7:0] x,
    input signed [7:0] y,
    output opposite
);
    wire [7:0] xor_result;
    assign xor_result = x ^ y;
    assign opposite = xor_result[7];
endmodule