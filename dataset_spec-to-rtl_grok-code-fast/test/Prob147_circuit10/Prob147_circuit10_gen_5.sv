module TopModule(
  input clk,
  input a,
  input b,
  output q,
  output state
);
  assign q = (a ^ b) ^ state;
  always_ff @(posedge clk)
    state <= state ^ (a == b && a == 0);
endmodule