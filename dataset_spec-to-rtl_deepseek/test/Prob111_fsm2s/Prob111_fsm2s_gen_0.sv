module TopModule (
  input clk,
  input reset,
  input j,
  input k,
  output out
);

  parameter OFF = 1'b0;
  parameter ON = 1'b1;

  reg state;

  always @(posedge clk) begin
    if (reset) begin
      state <= OFF;
    end else begin
      case (state)
        OFF: if (j) state <= ON; else state <= OFF;
        ON: if (k) state <= OFF; else state <= ON;
      endcase
    end
  end

  assign out = (state == ON);

endmodule