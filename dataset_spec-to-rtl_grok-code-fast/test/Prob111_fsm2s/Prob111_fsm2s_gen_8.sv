module TopModule(
  input clk,
  input reset,
  input j,
  input k,
  output out
);

  logic state;

  always @(posedge clk) begin
    if (reset) begin
      state <= 0;
    end else begin
      case (state)
        0: state <= j;
        1: state <= ~k;
      endcase
    end
  end

  assign out = state;

endmodule