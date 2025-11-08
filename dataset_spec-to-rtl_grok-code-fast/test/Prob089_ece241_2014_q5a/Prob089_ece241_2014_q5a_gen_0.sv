module TopModule(
  input clk,
  input areset,
  input x,
  output z
);

  reg state;

  assign z = (state == 1'b0) ? x : ~x;

  always @(posedge clk or posedge areset) begin
    if (areset)
      state <= 1'b0;
    else
      if (state == 1'b0 && x == 1'b1)
        state <= 1'b1;
      // else stay in state
  end

endmodule