module TopModule(input clk, input a, input b, output q, output state);
  logic state_reg;
  always_ff @(posedge clk) begin
    if (a == b) state_reg <= ~state_reg;
  end
  assign state = state_reg;
  assign q = a ^ b ^ state_reg;
endmodule