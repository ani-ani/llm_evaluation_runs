module integer_quotient(
  input [7:0] a,
  input [7:0] b,
  output reg [7:0] q
);

  always @(*) begin
    q = a / b;
  end
endmodule