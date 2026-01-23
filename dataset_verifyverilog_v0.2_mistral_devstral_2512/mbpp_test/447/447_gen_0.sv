module cube_nums (
  input [15:0][7:0] nums_in,
  output [15:0][31:0] cubes_out
);

  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : cube_gen
      assign cubes_out[i] = nums_in[i] * nums_in[i] * nums_in[i];
    end
  endgenerate

endmodule