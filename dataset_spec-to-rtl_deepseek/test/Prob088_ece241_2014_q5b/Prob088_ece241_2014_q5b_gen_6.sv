module TopModule (
  input clk,
  input areset,
  input x,
  output z
);
  logic state_A, state_B;
  logic next_state_A, next_state_B;

  assign next_state_A = state_A & ~x;
  assign next_state_B = (state_A & x) | state_B;

  always_ff @(posedge clk, posedge areset) begin
    if (areset) begin
      state_A <= 1'b1;
      state_B <= 1'b0;
    end else begin
      state_A <= next_state_A;
      state_B <= next_state_B;
    end
  end

  assign z = state_A ? x : ~x;

endmodule