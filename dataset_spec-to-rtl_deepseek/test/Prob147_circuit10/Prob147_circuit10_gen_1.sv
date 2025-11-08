module TopModule(input clk, a, b, output q, state);
  logic state_reg = 1'b0;
  always_ff @(posedge clk) begin
    state_reg <= (a ~^ b) ? ~state_reg : state_reg;
  end
  assign state = state_reg;
  assign q = state_reg ^ a ^ b;
endmodule