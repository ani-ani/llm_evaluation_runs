module ludic_numbers (
  input clk,
  input rst_n,
  input start,
  input [5:0] n,
  output reg [5:0] out_value,
  output reg valid,
  output reg done,
  output reg [5:0] err_position // zero-indexed position error (if any)
);

  // Internal signals
  typedef enum logic [2:0] { IDLE=0, INIT=1, PROCESSING=2, OUTPUT=3, DONE=4 } state_t;
  state_t state, next_state;

  reg [63:0] valid_mask;    // bit i => i is valid (i from 0..63). We use 1..N inclusive, 0 unused.
  reg [5:0] size_q;         // current queue size (#valid numbers to output)
  reg [5:0] out_idx;        // current index being output (1..N)
  reg [5:0] out_cnt;        // how many numbers have been output so far
  reg [5:0] base;           // current base position (1..N)
  reg [5:0] step;           // current step size = valid_mask[base] ? base : next_valid(base)
  reg [5:0] rptr;           // read pointer for enumeration in PROCESSING
  reg [5:0] rem_bits;       // number of 1-bits remaining at or after rptr (in valid_mask)
  reg [5:0] mark_idx;       // position to mark invalid in current step
  reg [5:0] marks_to_do;    // how many marks remain this step
  reg [5:0] marks_done;     // how many marks have been done this step
  reg [5:0] marked_in_step; // count of actual invalidations done in this step
  reg start_sync, start_r1;

  // Helper: return next position >= p that is valid; 0 if none.
  function [5:0] next_valid;
    input [5:0] p;
    integer i;
    begin
      next_valid = 6'd0;
      for (i = p; i <= 6'd63; i = i + 1) begin
        if (valid_mask[i]) begin
          next_valid = i[5:0];
          break;
        end
      end
    end
  endfunction

  // Helper: return position of the k-th valid (1-based) number in current valid_mask; 0 if not enough.
  function [5:0] kth_valid;
    input [5:0] k;
    integer i;
    reg [5:0] count;
    begin
      count = 6'd0;
      kth_valid = 6'd0;
      for (i = 1; i <= 63; i = i + 1) begin
        if (valid_mask[i]) begin
          count = count + 1;
          if (count == k) begin
            kth_valid = i[5:0];
            break;
          end
        end
      end
    end
  endfunction

  // Helper: return count of valid bits from 1..N inclusive
  function [5:0] popcount_range;
    input [5:0] N;
    integer i;
    begin
      popcount_range = 6'd0;
      for (i = 1; i <= 63; i = i + 1) begin
        if (i <= N && valid_mask[i]) popcount_range = popcount_range + 1;
      end
    end
  endfunction

  // LFSR-based pseudorandom generator for deterministic seeding (for robustness)
  reg [7:0] lfsr;
  wire lfsr_next = ^lfsr[6:0];

  // Start pulse synchronization
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_r1 <= 1'b0;
      start_sync <= 1'b0;
    end else begin
      start_r1 <= start;
      start_sync <= start_r1;
    end
  end

  wire start_pulse = start && !start_r1;

  // Sequential process
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      out_value <= 6'd0;
      valid <= 1'b0;
      done <= 1'b0;
      err_position <= 6'd0;
      valid_mask <= 64'd0;
      size_q <= 6'd0;
      out_idx <= 6'd1;
      out_cnt <= 6'd0;
      base <= 6'd1;
      step <= 6'd1;
      rptr <= 6'd1;
      rem_bits <= 6'd0;
      mark_idx <= 6'd0;
      marks_to_do <= 6'd0;
      marks_done <= 6'd0;
      marked_in_step <= 6'd0;
      lfsr <= 8'hA5;
    end else begin
      // Defaults
      valid <= 1'b0;
      done <= 1'b0;
      err_position <= 6'd0;
      // Update LFSR
      lfsr <= {lfsr[6:0], lfsr_next};

      case (state)
        IDLE: begin
          out_value <= 6'd0;
          if (start_pulse) begin
            // Validate position input (1..63); position 0 is invalid.
            if (n == 6'd0 || n > 6'd63) begin
              err_position <= n; // report zero-indexed error for position
              state <= DONE;     // finish immediately on error
            end else begin
              state <= INIT;
            end
          end else begin
            state <= IDLE;
          end
        end

        INIT: begin
          // Initialize valid mask: bits 1..n set to 1
          valid_mask <= (n >= 1) ? (64'd1 << n) - 1 : 64'd0;
          // Count valid numbers to output
          size_q <= popcount_range(n);
          // Reset output counters
          out_idx <= 6'd1;
          out_cnt <= 6'd0;
          // Prepare processing indices
          base <= 6'd1;
          step <= 6'd1;
          rptr <= 6'd1;
          rem_bits <= 6'd0;
          mark_idx <= 6'd0;
          marks_to_do <= 6'd0;
          marks_done <= 6'd0;
          marked_in_step <= 6'd0;
          state <= PROCESSING;
        end

        PROCESSING: begin
          // One step per cycle:
          // Ensure base points to a valid position
          if (!valid_mask[base]) begin
            base <= next_valid(base);
          end
          // Determine step (current Ludic number)
          if (valid_mask[base]) begin
            step <= base;
          end else begin
            step <= next_valid(base);
          end

          // If we are at a valid base, perform the sieving step this cycle.
          if (valid_mask[base]) begin
            // Enumerate: scan from rptr to end counting remaining valid bits.
            // rptr is guaranteed >= 1..64 by construction; pad valid_mask with a 0 at bit 0.
            if (rptr <= n) begin
              if (valid_mask[rptr]) rem_bits <= rem_bits + 1;
              rptr <= rptr + 1;
            end

            // Determine which element to mark invalid in this step.
            if (marks_to_do == 0) begin
              // First mark in this step: position = base + step
              mark_idx <= (base + step <= n) ? (base + step) : 6'd0;
              if ((base + step <= n) && (valid_mask[base + step])) begin
                marks_to_do <= step - 1; // remaining marks after first
              end else begin
                marks_to_do <= 6'd0;     // no more marks this step
              end
              marks_done <= 6'd0;
              marked_in_step <= 6'd0;
            end else begin
              // Subsequent marks: step positions apart from last mark
              mark_idx <= (mark_idx + step <= n) ? (mark_idx + step) : 6'd0;
              if (mark_idx + step <= n) begin
                marks_done <= marks_done + 1;
              end
              marks_to_do <= (marks_to_do > 0) ? (marks_to_do - 1) : 6'd0;
            end

            // Apply the mark if target is in range and currently valid
            if (mark_idx != 6'd0 && mark_idx <= n && valid_mask[mark_idx]) begin
              valid_mask[mark_idx] <= 1'b0;
              marked_in_step <= marked_in_step + 1;
            end

            // Step complete when we have no more marks to do in this step
            if (marks_to_do == 6'd0) begin
              // Advance base to the next valid number after the current base
              if (base < n) begin
                base <= next_valid(base + 1);
              end else begin
                base <= 6'd0; // will be invalid, triggers exit below
              end
              // Prepare for next pass enumeration from next base
              rptr <= (base < n) ? (base + 1) : (n + 1);
              rem_bits <= 6'd0;
              mark_idx <= 6'd0;
              marks_to_do <= 6'd0;
              marks_done <= 6'd0;
              marked_in_step <= 6'd0;
            end
          end else begin
            // base is invalid: move to next valid base and do nothing this cycle
            base <= next_valid(base);
            step <= base; // will be updated on next cycle
            rptr <= (base < n) ? (base + 1) : (n + 1);
            rem_bits <= 6'd0;
            mark_idx <= 6'd0;
            marks_to_do <= 6'd0;
            marks_done <= 6'd0;
            marked_in_step <= 6'd0;
          end

          // If there is no valid base (base == 0) then processing is done
          if (base == 6'd0) begin
            // Prepare output state
            out_idx <= 6'd1;
            out_cnt <= 6'd0;
            state <= OUTPUT;
          end
        end

        OUTPUT: begin
          // Emit one Ludic number per cycle
          if (out_idx <= n) begin
            if (valid_mask[out_idx]) begin
              out_value <= out_idx;
              valid <= 1'b1;
              out_cnt <= out_cnt + 1;
            end
            out_idx <= out_idx + 1;
            if (out_cnt + 1 >= size_q) begin
              state <= DONE;
              done <= 1'b1;
            end
          end else begin
            // Should not reach here, but safe-guard
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          // Pulse done for exactly one cycle, then return to IDLE
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
