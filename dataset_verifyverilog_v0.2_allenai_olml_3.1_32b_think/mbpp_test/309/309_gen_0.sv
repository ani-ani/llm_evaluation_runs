module maximum (
    input signed [15:0] a,
    input signed [15:0] b,
    output signed [15:0] max_result
);
assign max_result = (a >= b) ? a : b;
endmodule