module TopModule(
  input clk,
  input reset,
  output shift_ena
);

  reg [2:0] counter;
  reg [1:0] state;

  localparam IDLE = 2'd0;
  localparam SHIFT = 2'd1;

  always @(posedge clk) begin
    if (reset) begin
      state <= SHIFT;
      counter <= 3'd0;
    end else begin
      case (state)
        IDLE: begin
          counter <= 3'd0;
        end
        SHIFT: begin
          if (counter == 3'd3) begin
            state <= IDLE;
            counter <= 3'd0;
          end else begin
            counter <= counter + 3'd1;
          end
        end
        default: begin
          state <= IDLE;
          counter <= 3'd0;
        end
      endcase
    end
  end

  assign shift_ena = (state == SHIFT);

endmodule