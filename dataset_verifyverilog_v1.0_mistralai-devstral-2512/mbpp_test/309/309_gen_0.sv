module max_signed_8bit(
    input signed [7:0] a,
    input signed [7:0] b,
    output signed [7:0] max_result
);
    assign max_result = (a >= b) ? a : b;
endmodule