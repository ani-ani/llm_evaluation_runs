module nonagonal_calculator(
  input  [15:0] n,
  output [31:0] result
);

  wire [31:0] n_ext;
  wire [31:0] seven_n;
  wire [31:0] seven_n_minus_5;
  wire [63:0] mult_result;

  assign n_ext = {16'b0, n};
  assign seven_n = (n_ext << 2) + (n_ext << 1) + n_ext; // 7 * n
  assign seven_n_minus_5 = seven_n - 32'd5;
  assign mult_result = n_ext * seven_n_minus_5;
  assign result = mult_result[32] ? (mult_result[31:0] + 32'd1) >> 1 : mult_result[31:0] >> 1;

endmodule