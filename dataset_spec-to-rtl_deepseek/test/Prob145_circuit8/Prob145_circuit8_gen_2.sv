module TopModule(input clock, a, output p, q);
  assign p = a & clock;
  reg q_reg;
  always_ff @(negedge clock) begin
    q_reg <= p;
  end
  assign q = q_reg;
endmodule