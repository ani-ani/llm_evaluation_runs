module median_trapezium(
  input  [31:0] base1,
  input  [31:0] base2,
  input  [31:0] height,
  output reg [31:0] median
);

  wire [32:0] sum;

  assign sum = base1 + base2;

  always @(*) begin
    median = sum[32:1];
  end

endmodule