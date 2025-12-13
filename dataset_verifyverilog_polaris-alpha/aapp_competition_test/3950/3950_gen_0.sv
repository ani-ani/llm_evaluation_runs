module query_array_validator(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [5:0] q,
  input [5:0] a0, input [5:0] a1, input [5:0] a2, input [5:0] a3,
  input [5:0] a4, input [5:0] a5, input [5:0] a6, input [5:0] a7,
  output reg valid,
  output reg [5:0] restored_0, restored_1, restored_2, restored_3,
  output reg [5:0] restored_4, restored_5, restored_6, restored_7,
  output done
);

  // State encoding (2 bits as requested)
  localparam IDLE       = 2'd0;
  localparam PROCESSING = 2'd1;
  localparam DONE       = 2'd2;

  reg [1:0] state, next_state;

  // Internal registers
  reg [5:0] arr [0:7];          // working array
  reg [5:0] out_arr [0:7];      // final restored array

  // Existence tracking
  reg found_q;                  // at least one q in final array
  reg has_zero;                 // at least one zero in input (free slot)

  // Stack-based peak tracking (max depth 4)
  reg [5:0] stack_val [0:3];
  reg [2:0] stack_idx [0:3];    // index of last occurrence for that peak value
  reg [2:0] sp;                 // stack pointer (number of entries)

  // Control
  reg [2:0] idx;                // index 0..7
  reg failed;                   // violation flag
  reg done_reg;

  assign done = done_reg;

  // Next-state combinational logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
        else
          next_state = IDLE;
      end
      PROCESSING: begin
        // Transition to DONE when idx has processed n elements and constraints checked
        // We'll use idx == n and no further work pending as the condition.
        if (idx == n && n != 3'd0)
          next_state = DONE;
        else
          next_state = PROCESSING;
      end
      DONE: begin
        // Single cycle done, then go back to IDLE
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid <= 1'b0;
      done_reg <= 1'b0;
      restored_0 <= 6'd0;
      restored_1 <= 6'd0;
      restored_2 <= 6'd0;
      restored_3 <= 6'd0;
      restored_4 <= 6'd0;
      restored_5 <= 6'd0;
      restored_6 <= 6'd0;
      restored_7 <= 6'd0;
      idx <= 3'd0;
      sp <= 3'd0;
      found_q <= 1'b0;
      has_zero <= 1'b0;
      failed <= 1'b0;
    end else begin
      state <= next_state;
      done_reg <= 1'b0; // default, may be asserted in DONE state below

      case (state)
        IDLE: begin
          valid <= 1'b0;
          failed <= 1'b0;
          sp <= 3'd0;
          idx <= 3'd0;
          found_q <= 1'b0;
          has_zero <= 1'b0;

          if (start) begin
            // Load input array into working buffer
            arr[0] <= a0;
            arr[1] <= a1;
            arr[2] <= a2;
            arr[3] <= a3;
            arr[4] <= a4;
            arr[5] <= a5;
            arr[6] <= a6;
            arr[7] <= a7;

            // Initialize outputs buffer (will be updated later)
            out_arr[0] <= a0;
            out_arr[1] <= a1;
            out_arr[2] <= a2;
            out_arr[3] <= a3;
            out_arr[4] <= a4;
            out_arr[5] <= a5;
            out_arr[6] <= a6;
            out_arr[7] <= a7;
          end
        end

        PROCESSING: begin
          // Core algorithm processed sequentially over idx
          if (!failed && idx < n) begin
            // Fetch current value from working array
            reg [5:0] val;
            val = arr[idx];

            // Track zero presence
            if (val == 6'd0)
              has_zero <= 1'b1;

            // Replace zero if needed (zero means any 1..q)
            // Strategy:
            // - If q already found, replace 0 with 1 (minimal safe value)
            // - Else if we're at last element (idx == n-1) and no q yet, set to q
            // - Else set to 1 (will adjust later if necessary)
            if (val == 6'd0) begin
              if (!found_q && (idx == (n - 1))) begin
                val = q;
              end else begin
                val = (q == 6'd0) ? 6'd0 : 6'd1;
              end
            end

            // Enforce bounds: 1..q (after replacement), and allow existing concrete 0 only as wildcard
            if (val > q || val == 6'd0) begin
              failed <= 1'b1;
            end else begin
              // Update working and output arrays with resolved val
              arr[idx] <= val;
              out_arr[idx] <= val;

              // Track presence of q
              if (val == q)
                found_q <= 1'b1;

              // Stack-based peak tracking
              // Maintain non-decreasing up to max-peak; ensure no invalid drop

              // If stack empty, push (val, idx)
              if (sp == 3'd0) begin
                stack_val[0] <= val;
                stack_idx[0] <= idx;
                sp <= 3'd1;
              end else begin
                // Top of stack
                reg [5:0] top_v;
                reg [2:0] top_i;
                top_v = stack_val[sp-1];
                top_i = stack_idx[sp-1];

                if (val > top_v) begin
                  // New higher peak -> push
                  if (sp < 3'd4) begin
                    stack_val[sp] <= val;
                    stack_idx[sp] <= idx;
                    sp <= sp + 3'd1;
                  end else begin
                    // Stack overflow -> invalid
                    failed <= 1'b1;
                  end
                end else if (val == top_v) begin
                  // Same as current peak -> update last occurrence index
                  stack_idx[sp-1] <= idx;
                end else begin
                  // val < top_v: may need to pop until valid or fail
                  reg [2:0] sp_tmp;
                  reg [5:0] cur_v;
                  reg [2:0] cur_i;
                  sp_tmp = sp;

                  // Pop while stack not empty and val < current top
                  while (sp_tmp > 0 && val < stack_val[sp_tmp-1]) begin
                    sp_tmp = sp_tmp - 3'd1;
                  end

                  if (sp_tmp == 0) begin
                    // All peaks popped, val must be >= first peak to be valid; but since we popped
                    // because val < each, it's invalid
                    failed <= 1'b1;
                  end else begin
                    cur_v = stack_val[sp_tmp-1];
                    cur_i = stack_idx[sp_tmp-1];
                    // Check non-decreasing relative to last occurrence of peak
                    if (idx < cur_i) begin
                      // Decrease before last occurrence of higher peak -> invalid
                      failed <= 1'b1;
                    end else begin
                      // Now val >= cur_v or val may be between peaks; if val == cur_v, extend last idx
                      if (val == cur_v) begin
                        stack_idx[sp_tmp-1] <= idx;
                      end else if (val > cur_v) begin
                        // Insert new peak above cur_v
                        if (sp_tmp < 3'd4) begin
                          stack_val[sp_tmp] <= val;
                          stack_idx[sp_tmp] <= idx;
                          sp_tmp = sp_tmp + 3'd1;
                        end else begin
                          failed <= 1'b1;
                        end
                      end
                      sp <= sp_tmp;
                    end
                  end
                end
              end
            end

            // Move to next index
            idx <= idx + 3'd1;
          end else if (!failed && idx == n) begin
            // Post-processing once all elements considered
            // Ensure at least one q exists if possible via zeros
            if (!found_q) begin
              if (!has_zero) begin
                // No way to create q
                failed <= 1'b1;
              end else begin
                // We must place q somewhere in existing out_arr
                // Strategy: choose rightmost position where original was 0 (or <= q)
                // and check peak constraints locally. For sequential simplicity, pick last valid index.
                reg placed;
                reg [2:0] k;
                placed = 1'b0;
                k = n - 1;
                // Sequential search in this cycle (bounded n<=8, synthesizable)
                while (k < n && !placed) begin
                  if ((arr[k] == 6'd1 || arr[k] <= q) && (arr[k] != q)) begin
                    // Only override if this position was originally 0 (wildcard)
                    if ((k == 3'd0 && a0 == 6'd0) ||
                        (k == 3'd1 && a1 == 6'd0) ||
                        (k == 3'd2 && a2 == 6'd0) ||
                        (k == 3'd3 && a3 == 6'd0) ||
                        (k == 3'd4 && a4 == 6'd0) ||
                        (k == 3'd5 && a5 == 6'd0) ||
                        (k == 3'd6 && a6 == 6'd0) ||
                        (k == 3'd7 && a7 == 6'd0)) begin
                      out_arr[k] <= q;
                      placed = 1'b1;
                    end
                  end
                  if (!placed)
                    k = k - 3'd1;
                end
                if (!placed)
                  failed <= 1'b1;
              end
            end
          end
        end

        DONE: begin
          // Latch final outputs and valid flag
          done_reg <= 1'b1;

          if (!failed && n != 3'd0) begin
            valid <= 1'b1;

            restored_0 <= out_arr[0];
            restored_1 <= out_arr[1];
            restored_2 <= out_arr[2];
            restored_3 <= out_arr[3];
            restored_4 <= out_arr[4];
            restored_5 <= out_arr[5];
            restored_6 <= out_arr[6];
            restored_7 <= out_arr[7];
          end else begin
            valid <= 1'b0;
            // restored_* can be left as-is or undefined per spec
          end

          // Prepare for next cycle (state machine will move to IDLE)
          idx <= 3'd0;
          sp <= 3'd0;
          found_q <= 1'b0;
          has_zero <= 1'b0;
          failed <= 1'b0;
        end

        default: begin
          // Should not occur; reset-like behavior
          valid <= 1'b0;
          done_reg <= 1'b0;
        end
      endcase
    end
  end

endmodule