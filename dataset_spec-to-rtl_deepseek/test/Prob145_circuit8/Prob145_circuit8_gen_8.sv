module TopModule (
  input  clock,
  input  a,
  output p,
  output q
);

  reg p_reg, q_reg;

  always_latch begin
    if (clock) p_reg = a;
  end

  always_ff @(negedge clock) begin
    q_reg <= p_reg;
  end

  assign p = p_reg;
  assign q = q_reg;

endmodule