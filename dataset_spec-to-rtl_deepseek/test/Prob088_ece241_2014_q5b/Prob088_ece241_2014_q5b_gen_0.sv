module TopModule (
  input clk,
  input areset,
  input x,
  output logic z
);

  logic [1:0] state_reg, state_next;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) state_reg <= 2'b01;
    else state_reg <= state_next;
  end

  assign state_next[0] = state_reg[0] & ~x;
  assign state_next[1] = (state_reg[0] & x) | state_reg[1];
  assign z = (state_reg[0] & x) | (state_reg[1] & ~x);

endmodule