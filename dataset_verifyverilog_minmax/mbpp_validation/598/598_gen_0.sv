module armstrong_checker (
  input clk,
  input rst_n,
  input start,
  input [15:0] number,
  output reg result,
  output reg done
);

  // FSM states
  typedef enum logic [2:0] {
    IDLE          = 3'b000,
    COUNT_DIGITS  = 3'b001,
    CALC_POWER    = 3'b010,
    COMPARE       = 3'b011,
    FINISH        = 3'b100
  } state_t;

  state_t current_state, next_state;

  // Registers
  reg [15:0] num_reg;
  reg [15:0] digit_count;
  reg [15:0] digit;
  reg [15:0] sum;
  reg [15:0] power;
  reg [15:0] power_loop;
  reg [15:0] tmp; // temp for /10 in COUNT_DIGITS
  reg [15:0] rem; // remainder (mod 10) from COUNT_DIGITS
  reg [15:0] power_tmp; // temp for ^digits in CALC_POWER
  reg [15:0] power_res; // temp for ^digits in CALC_POWER
  reg [15:0] sum_tmp;   // temp for sum accumulation
  reg [15:0] rem2;      // remainder (mod 10) from CALC_POWER

  // State update (sequential)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 1'b0;
      done   <= 1'b0;
    end else begin
      current_state <= next_state;
      // These are updated in their respective states via blocking assigns
      // but captured here via non-blocking to register them.
      result <= result;
      done   <= done;
    end
  end

  // Next state and datapath (combinational)
  always_comb begin
    // Default to hold values to avoid latches
    next_state = current_state;
    result = result;
    done   = done;

    // State machine
    case (current_state)
      IDLE: begin
        result = 1'b0;
        done   = 1'b0;
        if (start) begin
          num_reg     = number;
          digit_count = 16'd0;
          next_state  = COUNT_DIGITS;
        end
      end

      COUNT_DIGITS: begin
        // Count digits using repeated division by 10
        if (num_reg >= 10) begin
          num_reg = num_reg / 10;
          digit_count = digit_count + 1;
          next_state = COUNT_DIGITS;
        end else begin
          // num_reg now holds the last digit
          digit = num_reg; // Save last digit
          num_reg = number; // Restore original number for power phase
          if (digit_count == 16'd0) begin
            // Single-digit number => Armstrong number
            result = 1'b1;
            done   = 1'b1;
            next_state = IDLE;
          end else begin
            // Init accumulation for power sum
            sum = 16'd0;
            power_loop = digit_count; // digits to process
            next_state = CALC_POWER;
          end
        end
      end

      CALC_POWER: begin
        // Compute next digit's contribution: digit^digits
        rem2 = num_reg % 10;           // get current least-significant digit
        num_reg = num_reg / 10;        // prepare for next iteration
        power_tmp = 16'd1;
        power_res = 16'd1;
        // Multiply 'rem2' by itself 'digit_count' times
        // Max exponent is 4 (16-bit safe: 9^4 = 6561 < 2^16)
        if (digit_count > 0) begin
          repeat (digit_count) begin
            power_res = power_res * rem2;
          end
        end
        sum_tmp = sum + power_res;
        // If last digit, move to compare; else continue accumulating
        if (power_loop == 16'd1) begin
          sum = sum_tmp;
          next_state = COMPARE;
        end else begin
          sum = sum_tmp;
          power_loop = power_loop - 1;
          next_state = CALC_POWER;
        end
      end

      COMPARE: begin
        // Compare computed sum with original number
        if (sum == number) begin
          result = 1'b1;
        end else begin
          result = 1'b0;
        end
        done = 1'b1;
        next_state = FINISH;
      end

      FINISH: begin
        // Hold result and done for 1 cycle (spec allows 1 cycle)
        result = result;
        done   = 1'b1;
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
