module TopModule(input clk, input reset, input in, output out);
  reg state_reg; // 1: B, 0: A

  always_ff @(posedge clk) begin
    if (reset)
      state_reg <= 1'b1; // Reset to B
    else
      state_reg <= state_reg ? (in ? 1'b1 : 1'b0) : (in ? 1'b0 : 1'b1); // Next state logic
  end

  assign out = state_reg; // Moore output
endmodule