module TopModule(
  input clk,
  input a,
  input b,
  output q,
  output state
);

  reg state_reg;
  
  assign state = state_reg;
  assign q = a ^ b ^ state_reg;
  
  always @(posedge clk) begin
    state_reg <= a & b | a & state_reg | b & state_reg;
  end

endmodule