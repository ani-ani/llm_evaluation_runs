module TopModule(
  input clk,
  input reset,
  input j,
  input k,
  output out
);
  reg state;
  assign out = state;
  always @(posedge clk) begin
    if (reset)
      state <= 1'b0; // OFF
    else begin
      case(state)
        1'b0: // OFF
          state <= j ? 1'b1 : 1'b0;
        1'b1: // ON
          state <= k ? 1'b0 : 1'b1;
      endcase
    end
  end
endmodule