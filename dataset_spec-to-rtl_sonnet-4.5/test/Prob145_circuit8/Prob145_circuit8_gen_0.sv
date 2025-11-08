module TopModule(
  input  clock,
  input  a,
  output p,
  output q
);

  reg q_reg;

  // p is the current value of 'a' AND'ed with the current clock
  assign p = a & clock;

  // q is a flip-flop that captures p on the negative edge of clock
  always @(negedge clock) begin
    q_reg <= p;
  end

  assign q = q_reg;

endmodule