module TopModule(
  input clk,
  input reset,
  input j,
  input k,
  output reg out
);

  parameter OFF = 1'b0;
  parameter ON = 1'b1;

  reg state, next_state;

  always @(*) begin
    case(state)
      OFF: begin
        next_state = j ? ON : OFF;
        out = 0;
      end
      ON: begin
        next_state = k ? OFF : ON;
        out = 1;
      end
    endcase
  end

  always @(posedge clk) begin
    if(reset) begin
      state <= OFF;
    end else begin
      state <= next_state;
    end
  end

endmodule