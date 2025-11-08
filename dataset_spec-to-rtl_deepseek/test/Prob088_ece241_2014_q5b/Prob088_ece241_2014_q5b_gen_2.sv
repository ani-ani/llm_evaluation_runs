module TopModule (
  input clk,
  input areset,
  input x,
  output z
);
  reg [1:0] state;
  reg [1:0] next_state;

  always_comb begin
    next_state[0] = state[0] & ~x;
    next_state[1] = (state[0] & x) | state[1];
  end

  assign z = (state[0] & x) | (state[1] & ~x);

  always_ff @(posedge clk, posedge areset) begin
    if (areset)
      state <= 2'b01;
    else
      state <= next_state;
  end
endmodule