module digit_rotate_multiplier (
  input clk,
  input rst_n,
  input start,
  input [31:0] x_fixed,
  output reg [31:0] result,
  output reg valid,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK,
    ROTATE,
    VERIFY,
    NEXT,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [13:0] n_current = 0; // 100-9999 range
  reg [31:0] product;
  reg [31:0] rotated;
  reg [31:0] found_result = 0;
  reg [13:0] counter = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      n_current <= 0;
      product <= 0;
      rotated <= 0;
      found_result <= 0;
      counter <= 0;
      result <= 0;
      valid <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK;
            n_current <= 100; // Start from 100
            counter <= 100;
          end
        end

        CHECK: begin
          // Fixed-point multiplication: (n * x_fixed) >> 16
          product <= (n_current * x_fixed) >>> 16;
          state <= ROTATE;
        end

        ROTATE: begin
          // Rotate first digit to end
          // For 3-digit: 123 -> 231
          // For 4-digit: 1234 -> 2341
          if (n_current < 1000) begin
            // 3-digit number
            rotated <= (n_current % 100) * 10 + (n_current / 100);
          end else begin
            // 4-digit number
            rotated <= (n_current % 1000) * 10 + (n_current / 1000);
          end
          state <= VERIFY;
        end

        VERIFY: begin
          if (product == rotated) begin
            found_result <= n_current; // Store found number
            result <= n_current;
            valid <= 1;
          end
          state <= NEXT;
        end

        NEXT: begin
          valid <= 0;
          n_current <= n_current + 1;
          counter <= counter + 1;
          
          if (counter == 9999) begin
            state <= DONE;
          end else begin
            state <= CHECK;
          end
        end

        DONE: begin
          done <= 1;
          if (found_result == 0) begin
            result <= 0;
          end else begin
            result <= found_result;
          end
          
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule