module TopModule(input clk, input x, output z);
  logic d_xor, d_and, d_or;
  logic q_xor = 0;
  logic q_and = 0;
  logic q_or = 0;

  always_ff @(posedge clk) begin
    q_xor <= d_xor;
    q_and <= d_and;
    q_or <= d_or;
  end

  assign d_xor = x ^ q_xor;
  assign d_and = x & ~q_and;
  assign d_or = x | ~q_or;
  assign z = ~(q_xor | q_and | q_or);
endmodule