module TopModule(
  input clk,
  input reset,
  input j,
  input k,
  output reg out
);

  reg state;

  always @(posedge clk) begin
    if (reset) begin
      state <= 1'b0; // OFF
    end else begin
      case (state)
        1'b0: // OFF
          if (j)
            state <= 1'b1; // to ON
          else
            state <= 1'b0; // stay OFF
        1'b1: // ON
          if (k)
            state <= 1'b0; // to OFF
          else
            state <= 1'b1; // stay ON
      endcase
    end
  end

  always @(*) begin
    case (state)
      1'b0: out = 1'b0;
      1'b1: out = 1'b1;
    endcase
  end

endmodule