module TopModule(input clk, input areset, input x, output reg z);
  enum logic {STATE_COPY, STATE_INVERT} state;
  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= STATE_COPY;
      z <= 1'b0;
    end
    else begin
      case (state)
        STATE_COPY: begin
          z <= x;
          if (x) state <= STATE_INVERT;
          else state <= STATE_COPY;
        end
        STATE_INVERT: begin
          z <= ~x;
          state <= STATE_INVERT;
        end
      endcase
    end
  end
endmodule