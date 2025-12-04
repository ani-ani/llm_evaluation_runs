module nonagonal_calculator(
  input [15:0] n,
  output reg [31:0] result
);

  always @(*) begin
    result = (32'(n) * (7 * 32'(n) - 5)) / 2;
  end

endmodule