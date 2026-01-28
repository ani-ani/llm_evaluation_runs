module set_even_bits(
    input [15:0] n,
    output [15:0] result
);
    assign result = n | 16'h5555;
endmodule