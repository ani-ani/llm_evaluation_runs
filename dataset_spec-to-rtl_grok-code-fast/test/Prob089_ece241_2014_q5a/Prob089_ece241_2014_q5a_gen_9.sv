module TopModule(
  input clk,
  input areset,
  input x,
  output z
);
  reg state; // 0: not seen first 1, 1: seen first 1
  assign z = state ? ~x : x;
  always @(posedge clk or posedge areset) begin
    if (areset)
      state <= 1'b0;
    else if (state == 1'b0 && x)
      state <= 1'b1;
    // else remain in current state
  end
endmodule