module min_plus_adder(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start computation
  input [3:0] digit_count, // Actual digit count (1-8)
  input [7:0][3:0] digits, // Up to 8 digits (4-bit each, MSB first)
  input [15:0] target_sum, // Target S value
  output reg [6:0] plus_positions, // Split positions between digits (bitmask)
  output reg [3:0] plus_count, // Number of '+' inserted
  output reg [15:0] computed_sum, // Sum of split segments
  output reg done // High when computation completes
);

  // Internal registers
  reg [6:0] mask;             // current mask candidate
  reg [6:0] max_mask;         // (1 << (digit_count-1)) - 1
  reg [3:0] min_plus_found;   // minimal plus count found so far
  reg        searching;       // indicates search in progress
  reg [15:0] cur_sum;         // working sum while evaluating
  reg [15:0] cur_num;         // current number being built from digits
  reg [3:0]  idx;             // index over digits
  reg [3:0]  plus_cnt_tmp;    // plus count for current mask
  reg [2:0]  state;           // FSM state

  localparam S_IDLE      = 3'd0;
  localparam S_INIT      = 3'd1;
  localparam S_EVAL_PRE  = 3'd2;
  localparam S_EVAL_RUN  = 3'd3;
  localparam S_EVAL_DONE = 3'd4;
  localparam S_NEXT_MASK = 3'd5;
  localparam S_DONE      = 3'd6;

  // Combinational function to count pluses (population count of mask within valid bits)
  function automatic [3:0] popcount7_valid;
    input [6:0] m;
    input [3:0] dcnt;
    integer i;
    reg [3:0] c;
  begin
    c = 4'd0;
    // only bits [dcnt-2:0] are valid when dcnt >= 2
    if (dcnt > 1) begin
      for (i = 0; i < 7; i = i + 1) begin
        if ((i < (dcnt-1)) && m[i]) c = c + 1'b1;
      end
    end
    popcount7_valid = c;
  end
  endfunction

  // Synchronous FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      plus_positions <= 7'd0;
      plus_count     <= 4'd0;
      computed_sum   <= 16'd0;
      done           <= 1'b0;

      mask           <= 7'd0;
      max_mask       <= 7'd0;
      min_plus_found <= 4'd15; // large sentinel
      searching      <= 1'b0;
      cur_sum        <= 16'd0;
      cur_num        <= 16'd0;
      idx            <= 4'd0;
      plus_cnt_tmp   <= 4'd0;
      state          <= S_IDLE;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize search bounds
            if (digit_count <= 1) begin
              // Trivial case: no '+' possible, just single number
              cur_num = digits[0];
              computed_sum <= cur_num;
              plus_positions <= 7'd0;
              plus_count <= 4'd0;
              if (cur_num == target_sum)
                done <= 1'b1;
              else
                done <= 1'b1; // no other solution
              state <= S_DONE;
            end else begin
              // max_mask: valid bits only up to digit_count-1
              max_mask       <= (7'd1 << (digit_count - 1)) - 1'b1;
              mask           <= 7'd0;
              min_plus_found <= 4'd15;
              plus_positions <= 7'd0;
              plus_count     <= 4'd0;
              computed_sum   <= 16'd0;
              searching      <= 1'b1;
              state          <= S_EVAL_PRE;
            end
          end
        end

        // Prepare evaluation of current mask
        S_EVAL_PRE: begin
          // If mask exceeds max_mask, finish search
          if (mask > max_mask || !searching) begin
            state <= S_DONE;
          end else begin
            // Early pruning: if even zero pluses already exceed known minimal (never) or
            // if we already found a solution with 0 pluses, we would have stopped.
            plus_cnt_tmp <= popcount7_valid(mask, digit_count);
            // If we already have a better or equal solution, skip this mask
            if (plus_cnt_tmp > min_plus_found) begin
              state <= S_NEXT_MASK;
            end else begin
              // Initialize evaluation
              cur_sum  <= 16'd0;
              cur_num  <= 16'd0;
              idx      <= 4'd0;
              state    <= S_EVAL_RUN;
            end
          end
        end

        // Evaluate current mask across digits sequentially
        S_EVAL_RUN: begin
          // Build current number by appending next digit
          // digits are given MSB first, index 0..digit_count-1
          cur_num <= cur_num * 10 + digits[idx];

          if (idx == digit_count - 1) begin
            // Last digit: finalize last segment
            cur_sum <= cur_sum + (cur_num * 10 + digits[idx]);
            state   <= S_EVAL_DONE;
          end else begin
            // Check if we insert '+' after this digit
            if (mask[idx]) begin
              // close current segment here
              cur_sum <= cur_sum + (cur_num * 10 + digits[idx]);
              cur_num <= 16'd0;
            end
            idx <= idx + 1'b1;
          end
        end

        // After forming all segments, compare sum to target
        S_EVAL_DONE: begin
          // By here, cur_sum holds sum including last segment
          if (cur_sum == target_sum) begin
            // Found a candidate; update if better
            if (plus_cnt_tmp < min_plus_found) begin
              min_plus_found <= plus_cnt_tmp;
              plus_positions <= mask;
              plus_count     <= plus_cnt_tmp;
              computed_sum   <= cur_sum;
            end
          end
          state <= S_NEXT_MASK;
        end

        // Move to next mask or finish if done
        S_NEXT_MASK: begin
          if (mask >= max_mask) begin
            // Completed all combinations
            state <= S_DONE;
          end else begin
            mask  <= mask + 1'b1;
            state <= S_EVAL_PRE;
          end
        end

        // Done state: signal completion; wait for next start
        S_DONE: begin
          done <= 1'b1;
          searching <= 1'b0;
          // Stay here until start deasserted then asserted again
          if (!start) begin
            state <= S_IDLE;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule