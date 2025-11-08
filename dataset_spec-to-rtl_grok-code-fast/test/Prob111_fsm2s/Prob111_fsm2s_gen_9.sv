module TopModule (
  input clk,
  input reset,
  input j,
  input k,
  output out
);

  logic state;

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= 1'b0;  // Reset to OFF
    end else begin
      case (state)
        0: if (j) state <= 1; else state <= 0;  // OFF
        1: if (k) state <= 0; else state <= 1;  // ON
      endcase
    end
  end

  assign out = state;  // Moore output

endmodule