module TopModule (
  input clk,
  input reset,
  input j,
  input k,
  output reg out
);

  typedef enum reg {OFF, ON} state_t;
  state_t state, next_state;

  always @(posedge clk) begin
    if (reset) begin
      state <= OFF;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    case (state)
      OFF: begin
        next_state = j ? ON : OFF;
        out = 1'b0;
      end
      ON: begin
        next_state = k ? OFF : ON;
        out = 1'b1;
      end
      default: begin
        next_state = OFF;
        out = 1'b0;
      end
    endcase
  end

endmodule