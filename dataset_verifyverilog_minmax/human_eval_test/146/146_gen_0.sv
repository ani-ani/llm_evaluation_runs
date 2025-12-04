module special_filter(
  input clk,
  input rst_n,
  input start,
  input signed [15:0] nums [0:7],
  output reg [3:0] count,
  output reg done
);

  // State machine: 2 cycles per element (total 16 cycles)
  localparam IDLE = 1'b0;
  localparam RUN  = 1'b1;

  reg state, next_state;
  reg [3:0] cycle_cnt;          // 0..15
  reg [3:0] cycle_cnt_next;
  reg [2:0] elem_idx;           // 0..7

  // Pipeline for per-element condition checking
  reg [15:0] abs_val;           // absolute value of current element
  reg [15:0] first_digit;       // first (most-significant) non-zero decimal digit
  reg       gt10;               // nums[elem] > 10
  reg       valid_cond;         // first digit odd and last digit odd
  reg       valid_cond_d1;      // delayed by 1 cycle

  reg [3:0] count_next;
  reg       done_next;

  // Compute digits for nums[elem_idx] (one element at a time)
  always @(*) begin
    abs_val = $unsigned($abs(nums[elem_idx]));       // absolute value (0..32767)
    gt10 = (nums[elem_idx] > 16'sd10);

    // Find first non-zero decimal digit (most-significant digit)
    // For 0, first_digit stays 0
    if (gt10) begin
      if (abs_val >= 10000) first_digit = abs_val / 10000;
      else if (abs_val >= 1000) first_digit = abs_val / 1000;
      else if (abs_val >= 100) first_digit = abs_val / 100;
      else first_digit = abs_val / 10;               // abs_val is 11..99 at this point
    end else begin
      first_digit = 16'h0;
    end

    // Condition: both first (non-zero) and last digits must be odd
    // Last digit is abs_val % 10
    valid_cond = gt10 && (first_digit[3:0] % 2) && ((abs_val % 10) % 2);
  end

  // State update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_cnt <= 4'd0;
      elem_idx <= 3'd0;
      valid_cond_d1 <= 1'b0;
      count <= 4'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      cycle_cnt <= cycle_cnt_next;
      elem_idx <= (next_state == IDLE) ? 3'd0 : ((cycle_cnt_next == 4'd0) ? (elem_idx + 3'd1) : elem_idx);
      valid_cond_d1 <= valid_cond;
      count <= count_next;
      done <= done_next;
    end
  end

  // Next-state and output logic
  always @(*) begin
    // Defaults
    next_state = state;
    cycle_cnt_next = cycle_cnt;
    count_next = count;   // hold value until next start/reset
    done_next = done;     // default: hold done until start/reset

    case (state)
      IDLE: begin
        cycle_cnt_next = 4'd0;
        done_next = 1'b0;
        if (start) begin
          next_state = RUN;
          cycle_cnt_next = 4'd1;      // start processing immediately
          count_next = 4'd0;          // begin counting from 0
        end
      end

      RUN: begin
        // Increment cycle counter and roll over after 15 (produces 16 cycles total)
        cycle_cnt_next = cycle_cnt + 4'd1;
        count_next = count;

        // On odd cycles, use the pipeline result (from 2 cycles earlier)
        if (cycle_cnt[0]) begin
          if (valid_cond_d1) count_next = count + 4'd1;
        end

        // After the last cycle (15 -> 0 rollover), assert done and return to IDLE
        if (cycle_cnt == 4'd15) begin
          done_next = 1'b1;
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule