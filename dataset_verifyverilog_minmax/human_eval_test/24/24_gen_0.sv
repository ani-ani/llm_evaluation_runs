module largest_divisor(
  input clk,
  input rst_n,
  input start,
  input reg [7:0] n,
  output reg [7:0] divisor,
  output reg done
);

  localparam IDLE = 1'b0;
  localparam RUN  = 1'b1;

  reg state, next_state;
  reg [7:0] check_value;
  reg [7:0] n_r;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      divisor <= 8'h0;
      done <= 1'b0;
      n_r <= 8'h0;
      check_value <= 8'h0;
    end else begin
      state <= next_state;
      n_r <= n;
      case (next_state)
        IDLE: begin
          done <= 1'b0;
          divisor <= 8'h0;
          if (start) begin
            // Initialize with n-1
            check_value <= (n >= 2) ? (n - 1) : 8'h0;
          end
        end
        RUN: begin
          if (n_r < 2) begin
            // Output 0 for n < 2
            divisor <= 8'h0;
          end else begin
            // Check divisibility first, then decrement
            if ((n_r % check_value) == 0) begin
              divisor <= check_value;        // Largest proper divisor found
            end else begin
              divisor <= divisor;            // Hold current divisor (8'h0 until found)
            end
            check_value <= (check_value > 2) ? (check_value - 1) : 1;
          end
          done <= 1'b0;
        end
        default: begin
          // Maintain current values in default case
          done <= done;
          divisor <= divisor;
          check_value <= check_value;
        end
      endcase
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = RUN;
        end else begin
          next_state = IDLE;
        end
      end
      RUN: begin
        if (n_r < 2) begin
          next_state = IDLE;
        end else begin
          // Remain in RUN until we find a divisor (i.e., divisor becomes non-zero)
          if (divisor != 0) begin
            next_state = IDLE;
          end else begin
            next_state = RUN;
          end
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Assert done for exactly one cycle when result becomes valid
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
    end else begin
      if (state == RUN && next_state == IDLE) begin
        done <= 1'b1;
      end else if (state == IDLE && next_state == RUN) begin
        done <= 1'b0;
      end
      // else hold current done value (set appropriately in state machine above)
    end
  end

endmodule