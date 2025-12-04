module first_digit (
  input clk,
  input rst_n,
  input start,
  input [15:0] num,
  output reg [3:0] result,
  output reg done
);

  typedef enum logic { IDLE, DIVIDE } state_t;
  state_t state, next_state;
  reg [15:0] val, next_val;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      val <= 16'd0;
      result <= 4'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      val <= next_val;
      if (state == DIVIDE && next_state == IDLE) begin
        result <= next_val[3:0];
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

  always_comb begin
    next_state = state;
    next_val = val;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = DIVIDE;
          next_val = num;
        end
      end

      DIVIDE: begin
        if (val >= 16'd10) begin
          next_val = val / 10;
          next_state = (next_val < 16'd10) ? IDLE : DIVIDE;
        end else begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule