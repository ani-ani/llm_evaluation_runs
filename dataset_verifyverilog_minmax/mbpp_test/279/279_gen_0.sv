module decagonal_number(
  input [7:0] n,
  output reg [17:0] result
);
  always @(*) begin
    result = (4 * n * n) - (3 * n);
  end
endmodule