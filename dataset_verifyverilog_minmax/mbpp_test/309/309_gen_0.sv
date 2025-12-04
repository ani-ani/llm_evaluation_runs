module max_of_two(
  input signed [7:0] a,
  input signed [7:0] b,
  output reg signed [7:0] out
);
  always @(*) begin
    if (a >= b) out = a;
    else        out = b;
  end
endmodule