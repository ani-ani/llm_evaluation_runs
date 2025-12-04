module house_number_counter(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start processing
  input [15:0] L, // Lower bound
  input [15:0] R, // Upper bound
  output reg [15:0] count, // Valid house count
  output reg done // High when counting complete
);

  // FSM states
  typedef enum logic { IDLE = 1'b0, COUNTING = 1'b1 } state_t;
  state_t state, next_state;

  // Current number being checked
  reg [15:0] current_number, next_current_number;

  // Next outputs (registered via always_ff)
  reg [15:0] next_count;
  reg next_done;

  // Sequential block: clock and reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_number <= '0;
      count <= '0;
      done <= 1'b1; // Complete at reset
    end else begin
      state <= next_state;
      current_number <= next_current_number;
      count <= next_count;
      done <= next_done;
    end
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults
    next_state = state;
    next_current_number = current_number;
    next_count = count;
    next_done = done;

    case (state)
      IDLE: begin
        next_count = '0;
        next_done = 1'b0;
        if (start) begin
          next_current_number = L;  // Setup cycle
          next_state = COUNTING;
        end
      end

      COUNTING: begin
        // Evaluate current_number (within [L, R] by construction)
        // 5-digit decimal digits, most-significant first
        logic [3:0] d4, d3, d2, d1, d0; // digits from 10000 to 1s place
        d4 = (current_number / 10000) % 10;
        d3 = (current_number / 1000) % 10;
        d2 = (current_number / 100) % 10;
        d1 = (current_number / 10) % 10;
        d0 = (current_number / 1) % 10;

        // Find first non-zero digit index from the left (4..0)
        logic [2:0] first_idx; // 0=units(d0), 1=tens(d1), 2=hundreds(d2), 3=thousands(d3), 4=ten-thousands(d4)
        logic found;
        found = 1'b0;
        if (d4 != 4 && d4 != 0) begin
          first_idx = 3'd4; found = 1'b1;
        end else if (d3 != 4 && d3 != 0) begin
          first_idx = 3'd3; found = 1'b1;
        end else if (d2 != 4 && d2 != 0) begin
          first_idx = 3'd2; found = 1'b1;
        end else if (d1 != 4 && d1 != 0) begin
          first_idx = 3'd1; found = 1'b1;
        end else if (d0 != 4 && d0 != 0) begin
          first_idx = 3'd0; found = 1'b1;
        end else begin
          first_idx = 3'd0;
        end

        // If number is zero (all zeros), treat as single digit '0' (valid if not 4)
        logic is_zero;
        is_zero = (current_number == 16'b0);

        // Digit validity and classification
        logic [4:0] digit_valid;
        logic [4:0] is_lucky;
        logic is_zero_num;
        is_zero_num = is_zero;

        // Determine digit validity and whether it is 6 or 8 (lucky)
        // Digits order: d4, d3, d2, d1, d0
        digit_valid[4] = ~is_zero_num & ~ (d4 == 4);
        digit_valid[3] = ~is_zero_num & ~ (d3 == 4);
        digit_valid[2] = ~is_zero_num & ~ (d2 == 4);
        digit_valid[1] = ~is_zero_num & ~ (d1 == 4);
        digit_valid[0] = ~is_zero_num & ~ (d0 == 4);

        is_lucky[4] = (d4 == 6) | (d4 == 8);
        is_lucky[3] = (d3 == 6) | (d3 == 8);
        is_lucky[2] = (d2 == 6) | (d2 == 8);
        is_lucky[1] = (d1 == 6) | (d1 == 8);
        is_lucky[0] = (d0 == 6) | (d0 == 8);

        // Count lucky and other digits from first non-zero digit onward
        int lucky_cnt, other_cnt;
        lucky_cnt = 0;
        other_cnt = 0;

        if (found) begin
          for (int i = 4; i >= 0; i--) begin
            if (i >= first_idx) begin
              if (digit_valid[i]) begin
                if (is_lucky[i]) lucky_cnt++;
                else other_cnt++;
              end
            end
          end
        end else if (is_zero_num) begin
          // Number is 0: treat as single digit '0'
          if (d0 != 4) other_cnt = 1;
        end

        // Number is valid if:
        // - No digit (from first non-zero) is '4'
        // - lucky_cnt == other_cnt
        logic is_valid_num;
        is_valid_num = (lucky_cnt == other_cnt);

        // Increment count if current_number is still within [L, R]
        if (current_number <= R) begin
          if (is_valid_num) next_count = count + 1'b1;
          else next_count = count;
        end else begin
          next_count = count;
        end

        // Move to next number and check for completion
        if (current_number < R) begin
          next_current_number = current_number + 1'b1;
          next_state = COUNTING;
          next_done = 1'b0;
        end else begin
          next_current_number = current_number; // stay
          next_state = IDLE;
          next_done = 1'b1;
        end
      end

      default: begin
        next_state = IDLE;
        next_current_number = '0;
        next_count = '0;
        next_done = 1'b1;
      end
    endcase
  end
endmodule
