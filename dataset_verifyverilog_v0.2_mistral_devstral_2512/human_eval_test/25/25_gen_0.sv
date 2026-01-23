module factorize (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  output reg [15:0] factors_out,
  output reg factors_valid,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    CHECK_DIVISOR,
    OUTPUT_FACTOR,
    INCREMENT_DIVISOR,
    DONE
  } state_t;

  // Internal registers
  reg [15:0] current_n;
  reg [15:0] divisor;
  reg [3:0] current_state;
  reg [15:0] next_n;
  reg [15:0] next_divisor;
  reg [3:0] next_state;
  reg divisor_squared_gt_n;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset state
      current_state <= IDLE;
      current_n <= 0;
      divisor <= 0;
      factors_out <= 0;
      factors_valid <= 0;
      done <= 0;
    end else begin
      // State transitions
      case (current_state)
        IDLE: begin
          if (start) begin
            if (n == 0 || n == 1) begin
              next_state = DONE;
              done <= 1;
            end else begin
              next_state = CHECK_DIVISOR;
              next_n = n;
              next_divisor = 2;
            end
          end else begin
            next_state = IDLE;
          end
        end

        CHECK_DIVISOR: begin
          if (current_n % divisor == 0) begin
            next_state = OUTPUT_FACTOR;
          end else begin
            next_state = INCREMENT_DIVISOR;
          end
        end

        OUTPUT_FACTOR: begin
          next_state = CHECK_DIVISOR;
          next_n = current_n / divisor;
          if (next_n == 1) begin
            next_state = DONE;
          end
        end

        INCREMENT_DIVISOR: begin
          next_divisor = divisor + 1;
          if (next_divisor * next_divisor > current_n) begin
            next_state = DONE;
          end else begin
            next_state = CHECK_DIVISOR;
          end
        end

        DONE: begin
          if (start) begin
            if (n == 0 || n == 1) begin
              next_state = DONE;
              done <= 1;
            end else begin
              next_state = CHECK_DIVISOR;
              next_n = n;
              next_divisor = 2;
              done <= 0;
            end
          end else begin
            next_state = DONE;
          end
        end

        default: next_state = IDLE;
      endcase

      // Update registers
      current_state <= next_state;
      current_n <= next_n;
      divisor <= next_divisor;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      factors_out <= 0;
      factors_valid <= 0;
      done <= 0;
    end else begin
      factors_valid <= 0;
      case (current_state)
        OUTPUT_FACTOR: begin
          factors_out <= divisor;
          factors_valid <= 1;
        end
        DONE: begin
          done <= 1;
          factors_valid <= 0;
        end
        default: begin
          factors_valid <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule