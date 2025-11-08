module TopModule(
  input clk,
  input x,
  output z
);
  reg q0, q1, q2;
  wire d0, d1, d2;
  assign d0 = x ^ q0;
  assign d1 = x & (~q1);
  assign d2 = x | (~q2);
  assign z = ~(q0 | q1 | q2);
  initial begin
    q0 = 1'b0;
    q1 = 1'b0;
    q2 = 1'b0;
  end
  always @(posedge clk) begin
    q0 <= d0;
    q1 <= d1;
    q2 <= d2;
  end
endmodule