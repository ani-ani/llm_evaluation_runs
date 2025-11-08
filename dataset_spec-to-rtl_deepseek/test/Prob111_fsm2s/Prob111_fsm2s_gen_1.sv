module TopModule(
  input clk,
  input reset,
  input j,
  input k,
  output out
);

  reg state;

  always @(posedge clk) begin
    if (reset)
      state <= 1'b0;  // OFF
    else if (state == 1'b0) begin  // OFF
      if (j)
        state <= 1'b1;  // to ON
      else
        state <= 1'b0;  // stay OFF
    end else begin  // ON
      if (k)
        state <= 1'b0;  // to OFF
      else
        state <= 1'b1;  // stay ON
    end
  end

  assign out = state;

endmodule