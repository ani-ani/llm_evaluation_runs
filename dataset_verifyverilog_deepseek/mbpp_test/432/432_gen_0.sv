module median_trapezium(
  input [31:0] base1,
  input [31:0] base2,
  input [31:0] height,
  output reg [31:0] median
);
  always_comb begin
    logic [32:0] sum = {1'b0, base1} + {1'b0, base2};
    median = sum[32:1];
  end
endmodule