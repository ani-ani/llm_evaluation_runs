module even_binomial_sum(
  input reg [3:0] n,
  output reg [15:0] sum
);
  always @(*) begin
    sum = 1 << (n - 1);
  end
endmodule
