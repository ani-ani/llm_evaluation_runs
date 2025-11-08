module TopModule (
  input clk,
  input a,
  input b,
  output q,
  output state
);

  reg state_reg;

  always_ff @(posedge clk) begin
    state_reg <= a & b;
  end

  assign q = state_reg ? ~(a ^ b) : (a ^ b);
  assign state = state_reg;

endmodule