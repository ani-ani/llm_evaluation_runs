module cube_nums (
    input  [15:0][7:0]  nums_in,
    output [15:0][31:0] cubes_out
);

    // Generate block to compute x*x*x for each of the 16 elements in parallel
    // An 8-bit input ranges 0-255, so the result max is 255^3 = 16,581,375
    // which fits in 24 bits. We compute x * x first (16-bit), then multiply by x again.
    // The 32-bit output port provides sufficient padding.
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : cube_loop
            assign cubes_out[i] = nums_in[i] * nums_in[i] * nums_in[i];
        end
    endgenerate

endmodule