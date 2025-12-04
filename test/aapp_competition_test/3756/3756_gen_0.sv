module grade_rounder(
  input clk,
  input rst_n,
  input start,
  input [3:0] grade_len,
  input [119:0] grade_in,
  input [2:0] t_in,
  output reg [119:0] grade_out,
  output reg [3:0] out_len,
  output reg done
);

  // Internal parameters
  localparam MAX_LEN = 15;

  // State encoding
  typedef enum logic [1:0] {
    IDLE            = 2'd0,
    FIND_POSITION   = 2'd1,
    ROUND_PROPAGATE = 2'd2,
    TRIM_TRAILING   = 2'd3
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0] buf [0:MAX_LEN-1];       // working buffer of characters
  reg [3:0] len_r;                   // current effective length
  reg [2:0] t_left;                  // remaining rounding steps
  reg [3:0] dec_pos;                 // position of decimal point (index), 0..14, or 15 if none
  reg       has_decimal;             // flag if decimal point exists
  reg [3:0] idx;                     // generic index / scan position
  reg       need_round;              // flag if any rounding step remains
  reg       any_round_done;          // flag to indicate if any rounding actually applied

  // Helper wires
  integer i;

  // Unpack grade_in into buf on start (MSB aligned, char[0] is leftmost)
  // Synchronous FSM

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      len_r         <= 4'd0;
      t_left        <= 3'd0;
      dec_pos       <= 4'd15;
      has_decimal   <= 1'b0;
      idx           <= 4'd0;
      need_round    <= 1'b0;
      any_round_done<= 1'b0;
      grade_out     <= {120{1'b0}};
      out_len       <= 4'd0;
      done          <= 1'b0;
      for (i = 0; i < MAX_LEN; i = i + 1) begin
        buf[i] <= 8'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Clamp length
            len_r <= (grade_len <= MAX_LEN[3:0]) ? grade_len : MAX_LEN[3:0];

            // Unpack input into buffer
            for (i = 0; i < MAX_LEN; i = i + 1) begin
              if (i < grade_len)
                buf[i] <= grade_in[119 - 8*i -: 8];
              else
                buf[i] <= 8'd0;
            end

            // Clamp t_in to 4
            if (t_in[2] == 1'b1)
              t_left <= 3'd4; // if t_in >=4, cap at 4
            else
              t_left <= (t_in > 3'd4) ? 3'd4 : t_in;

            // Reset helpers
            dec_pos        <= 4'd15;
            has_decimal    <= 1'b0;
            idx            <= 4'd0;
            need_round     <= 1'b0;
            any_round_done <= 1'b0;
          end
        end

        FIND_POSITION: begin
          // One-pass scan to:
          //  - identify decimal position
          //  - find earliest digit >= '5' after decimal using parallel-like checks
          // For efficiency / parallel style, we conceptually evaluate all digits,
          // but here sequenced once per start (single-cycle combinational inside this clocked block).

          // Detect decimal position
          has_decimal <= 1'b0;
          dec_pos     <= 4'd15;
          for (i = 0; i < MAX_LEN; i = i + 1) begin
            if (i < len_r && !has_decimal && buf[i] == 8'h2E) begin // '.'
              has_decimal <= 1'b1;
              dec_pos     <= i[3:0];
            end
          end

          need_round <= 1'b0;

          if (t_left != 3'd0 && has_decimal) begin
            // Search first position after decimal where digit >= '5'
            // within any available span; the effective "steps" constraint
            // is implemented in ROUND_PROPAGATE phase by limiting how many
            // times we apply rounding.
            for (i = 0; i < MAX_LEN; i = i + 1) begin
              if (!need_round && i < len_r && i > dec_pos) begin
                if (buf[i] >= 8'h35 && buf[i] <= 8'h39) begin
                  // Mark that we should round at/above this position
                  need_round <= 1'b1;
                end
              end
            end
          end

          // Initialize index for ROUND_PROPAGATE from end
          idx <= (len_r == 0) ? 4'd0 : (len_r - 1);
        end

        ROUND_PROPAGATE: begin
          // Apply rounding with at most t_left steps.
          // We propagate from right to left; when we find a digit >= '5'
          // after decimal and t_left>0, we:
          //   - clear this digit to '0'
          //   - propagate carry left (skipping '.')
          //   - count one step
          // Continue until no more triggers or t_left==0.

          if (t_left == 0 || !has_decimal) begin
            // nothing more to do
          end else begin
            // We implement a single combined sweep where multiple rounds
            // may occur, but overall bounded by t_left.
            integer j;
            reg [2:0] steps_used;
            steps_used = 3'd0;

            // Repeat over buffer while we still have steps (bounded, MAX_LEN small)
            for (j = 0; j < MAX_LEN; j = j + 1) begin
              if (steps_used < t_left) begin
                integer k;
                // Find first candidate from left to right that currently
                // satisfies: position > dec_pos, digit >= '5'.
                reg found;
                found = 1'b0;
                integer pos;
                pos = -1;
                integer s;
                for (s = 0; s < MAX_LEN; s = s + 1) begin
                  if (!found && s < len_r && s > dec_pos &&
                      buf[s] >= 8'h35 && buf[s] <= 8'h39) begin
                    found = 1'b1;
                    pos   = s;
                  end
                end

                if (found) begin
                  any_round_done = 1'b1;
                  // Clear digit at pos to '0'
                  buf[pos] = 8'h30;

                  // Propagate carry to the left
                  integer p;
                  p = pos - 1;
                  reg carry_done;
                  carry_done = 1'b0;

                  while (p >= 0 && !carry_done) begin
                    if (buf[p] == 8'h2E) begin
                      p = p - 1; // skip decimal
                    end else if (buf[p] >= 8'h30 && buf[p] <= 8'h38) begin
                      buf[p] = buf[p] + 8'd1; // increment digit
                      carry_done = 1'b1;
                    end else if (buf[p] == 8'h39) begin
                      buf[p] = 8'h30; // 9 -> 0, continue carry
                      p = p - 1;
                    end else begin
                      // Non-digit: insert '1' before if carry reaches here
                      carry_done = 1'b1;
                    end
                  end

                  // If carry not resolved and we moved past index 0,
                  // we need to insert leading '1'
                  if (!carry_done) begin
                    // Shift right by 1 to make room at buf[0]
                    if (len_r < MAX_LEN) begin
                      for (k = len_r; k > 0; k = k - 1) begin
                        buf[k] = buf[k-1];
                      end
                      buf[0] = 8'h31; // '1'
                      len_r  = len_r + 1;

                      // Adjust decimal position if existed
                      if (has_decimal && dec_pos != 4'd15)
                        dec_pos = dec_pos + 1;
                    end
                  end

                  steps_used = steps_used + 3'd1;
                end // if(found)
              end
            end

            // Update remaining steps
            t_left <= t_left - steps_used;
          end
        end

        TRIM_TRAILING: begin
          // Remove trailing zeros after decimal point.
          // If decimal exists, trim '0's from the end that are after decimal.
          if (has_decimal && dec_pos < len_r) begin
            // Trim zeros
            while (len_r > 0 && buf[len_r-1] == 8'h30 && (len_r-1) > dec_pos) begin
              buf[len_r-1] <= 8'd0;
              len_r        <= len_r - 1;
            end
            // If last char is '.', remove it as well
            if (len_r > 0 && buf[len_r-1] == 8'h2E) begin
              buf[len_r-1] <= 8'd0;
              len_r        <= len_r - 1;
            end
          end

          // Pack buf into grade_out
          for (i = 0; i < MAX_LEN; i = i + 1) begin
            if (i < len_r)
              grade_out[119 - 8*i -: 8] <= buf[i];
            else
              grade_out[119 - 8*i -: 8] <= 8'd0;
          end

          out_len <= len_r[3:0];
          done    <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = FIND_POSITION;
      end
      FIND_POSITION: begin
        // Move to ROUND_PROPAGATE if rounding possible and t_left>0
        if (t_left != 0 && has_decimal && need_round)
          next_state = ROUND_PROPAGATE;
        else
          next_state = TRIM_TRAILING;
      end
      ROUND_PROPAGATE: begin
        // After rounding steps applied, go to trimming
        next_state = TRIM_TRAILING;
      end
      TRIM_TRAILING: begin
        // After done, go back to IDLE next cycle
        next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule