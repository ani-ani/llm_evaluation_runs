module TopModule(input clk, input areset, input x, output reg z);
  typedef enum reg {COPY, INVERT} state_t;
  state_t state;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= COPY;
      z <= 1'b0;
    end else begin
      case (state)
        COPY: begin
          if (x) begin
            state <= INVERT;
            z <= x;
          end else begin
            z <= x;
          end
        end
        INVERT: begin
          z <= ~x;
        end
      endcase
    end
  end
endmodule