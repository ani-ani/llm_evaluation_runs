module query_array_validator(
  input clk,
  input rst_n,
  input start, // 1-cycle start pulse
  input [2:0] n,   // array size (1..8)
  input [5:0] q,   // max query value (1..63)
  input [5:0] a0, input [5:0] a1, input [5:0] a2, input [5:0] a3,
  input [5:0] a4, input [5:0] a5, input [5:0] a6, input [5:0] a7,
  output reg valid,
  output reg [5:0] restored_0, restored_1, restored_2, restored_3,
  output reg [5:0] restored_4, restored_5, restored_6, restored_7,
  output reg done // 1-cycle pulse when validation complete
);

  // Constants
  localparam ST_IDLE      = 2'b00;
  localparam ST_PROC      = 2'b01;
  localparam ST_DONE      = 2'b10; // held for 1 cycle (done)
  localparam MAX_ELEMS    = 8;
  localparam MAX_CYCLES   = 32; // 32-cycle budget
  localparam STACK_DEPTH  = 4;

  // Internal state and datapath
  reg [1:0] state, next_state;
  reg [4:0] cycle_cnt; // counts 0..31 (fits in 5 bits)

  // Processing indices and control
  reg [3:0] idx;       // 0..8 (fits in 4 bits)
  reg [2:0] n_reg;
  reg [5:0] q_reg;
  reg [5:0] elems [0:MAX_ELEMS-1];
  reg [5:0] elems_next [0:MAX_ELEMS-1];

  reg [5:0] cur_max;
  reg [3:0] last_peak_idx;   // last occurrence index of current max
  reg [3:0] last_peak_idx_next;
  reg       invalid_flag;
  reg       invalid_flag_next;

  reg [2:0] top_ptr;   // 0..STACK_DEPTH
  reg [5:0] stack_max [0:STACK_DEPTH-1];
  reg [3:0] stack_idx [0:STACK_DEPTH-1];

  reg [3:0] zero_idx;        // index of a zero to be replaced by q (if needed)
  reg       zero_valid;      // whether a zero index is available
  reg       q_placed;        // q already placed into array
  reg [3:0] last_idx_of_v [1:63]; // last occurrence of each value v (1..q)

  // Internal outputs (captured on completion)
  reg valid_next;
  reg [5:0] restored [0:MAX_ELEMS-1];

  // Load array from inputs (combinational)
  always_comb begin
    elems_next[0] = a0;
    elems_next[1] = a1;
    elems_next[2] = a2;
    elems_next[3] = a3;
    elems_next[4] = a4;
    elems_next[5] = a5;
    elems_next[6] = a6;
    elems_next[7] = a7;
  end

  // FSM: next state logic
  always_comb begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (start) begin
          if ((n_reg == 0) || (q_reg == 0) || (n_reg > 8)) begin
            // Impossible by constraints -> complete immediately
            next_state = ST_DONE;
          end else begin
            next_state = ST_PROC;
          end
        end else begin
          next_state = ST_IDLE;
        end
      end
      ST_PROC: begin
        if ((idx >= n_reg) || invalid_flag || (cycle_cnt >= MAX_CYCLES-1)) begin
          next_state = ST_DONE;
        end else begin
          next_state = ST_PROC;
        end
      end
      ST_DONE: begin
        next_state = ST_IDLE; // DONE is held for exactly 1 cycle
      end
      default: next_state = ST_IDLE;
    endcase
  end

  // Datapath: processing per cycle (sequential, non-blocking)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= ST_IDLE;
      cycle_cnt  <= 0;
      n_reg      <= 0;
      q_reg      <= 0;
      idx        <= 0;
      cur_max    <= 0;
      last_peak_idx <= 0;
      invalid_flag <= 1'b0;
      top_ptr    <= 0;
      zero_idx   <= 0;
      zero_valid <= 1'b0;
      q_placed   <= 1'b0;
      valid      <= 1'b0;
      done       <= 1'b0;
      restored_0 <= 0; restored_1 <= 0; restored_2 <= 0; restored_3 <= 0;
      restored_4 <= 0; restored_5 <= 0; restored_6 <= 0; restored_7 <= 0;
      // Clear arrays
      for (int i=0; i<MAX_ELEMS; i++) elems[i] <= 0;
      for (int i=0; i<STACK_DEPTH; i++) begin
        stack_max[i] <= 0;
        stack_idx[i] <= 0;
      end
      for (int v=0; v<64; v++) last_idx_of_v[v] <= 0;
    end else begin
      // State transition
      state <= next_state;

      // default control signals
      valid <= 1'b0;
      done  <= 1'b0;
      // Note: outputs restored_* will be set in ST_DONE below

      if (state == ST_IDLE) begin
        cycle_cnt <= 0;
        idx <= 0;
        // Sample inputs on start pulse
        if (start) begin
          n_reg <= n;
          q_reg <= q;
          for (int i=0; i<MAX_ELEMS; i++) elems[i] <= elems_next[i];

          // Initialize control registers
          cur_max <= 0;
          last_peak_idx <= 0;
          invalid_flag <= 1'b0;
          top_ptr <= 0;
          zero_idx <= 0;
          zero_valid <= 1'b0;
          q_placed <= 1'b0;
          for (int v=0; v<64; v++) last_idx_of_v[v] <= 0;
        end
      end
      else if (state == ST_PROC) begin
        cycle_cnt <= cycle_cnt + 1;

        // Process a single element per cycle at index idx
        if (!invalid_flag) begin
          if (idx < n_reg) begin
            // Access current element
            reg [5:0] val;
            val = elems[idx];

            // Range check: values must be between 0 and q inclusive
            if (val > q_reg) begin
              invalid_flag_next <= 1'b1;
              invalid_flag <= 1'b1;
            end else begin
              invalid_flag_next <= 1'b0;
              // Track last occurrence of each value v>0 (for peak checks)
              if (val > 0) begin
                last_idx_of_v[val] <= idx;
              end

              // Determine the last occurrence index of the current max value (cur_max)
              if (val > cur_max) begin
                cur_max <= val;
                last_peak_idx_next <= idx;          // first occurrence of new max
                last_peak_idx <= idx;
              end else if (val == cur_max) begin
                last_peak_idx_next <= idx;          // update last occurrence of current max
                last_peak_idx <= idx;
              end else begin
                last_peak_idx_next <= last_peak_idx; // keep previous last peak
              end

              // Peak-condition check:
              // - Before last occurrence of the current max, values must not decrease.
              // - Only enforce this when we already have a current max > 0.
              if (cur_max > 0) begin
                // If we are before the last peak, value must be >= previous processed value
                if (idx < last_peak_idx) begin
                  // Need prev value for comparison; we track via stack top.
                  // If stack empty or val < stack_max[top_ptr-1], invalid.
                  if (top_ptr == 0) begin
                    // No previous value to compare to; this should not happen for idx>0
                    // but we guard anyway.
                    invalid_flag_next <= 1'b1;
                    invalid_flag <= 1'b1;
                  end else begin
                    if (val < stack_max[top_ptr-1]) begin
                      invalid_flag_next <= 1'b1;
                      invalid_flag <= 1'b1;
                    end
                  end
                end
              end

              // Stack update (peak tracking with max depth 4)
              if (cur_max > 0) begin
                if ((top_ptr == 0) || (val > stack_max[top_ptr-1])) begin
                  // push new peak
                  if (top_ptr < STACK_DEPTH) begin
                    stack_max[top_ptr] <= val;
                    stack_idx[top_ptr] <= idx;
                    top_ptr <= top_ptr + 1;
                  end else begin
                    // stack overflow -> mark invalid
                    invalid_flag_next <= 1'b1;
                    invalid_flag <= 1'b1;
                  end
                end
              end

              // Zero replacement strategy (ensure at least one q exists if possible):
              // - If val == 0 and q not yet placed and we have not stored a zero index, remember this zero.
              // - When we later see a val > 0 before any q, we can replace the remembered zero with q.
              if (!q_placed) begin
                if (val == 0) begin
                  if (!zero_valid) begin
                    zero_idx <= idx;
                    zero_valid <= 1'b1;
                  end
                end else begin // val > 0
                  if (val < q_reg) begin
                    // we can place q at the remembered zero if available
                    if (zero_valid) begin
                      // Replace elems[zero_idx] with q now.
                      elems[zero_idx] <= q_reg;
                      q_placed <= 1'b1;
                      zero_valid <= 1'b0;
                    end
                  end else if (val == q_reg) begin
                    // q already present naturally
                    q_placed <= 1'b1;
                    zero_valid <= 1'b0;
                  end
                  // if val > q_reg: already invalid above
                end
              end
            end

            // Advance to next index
            idx <= idx + 1;
          end
        end else begin
          // Already invalid; continue until budget spent or array scanned
          if (idx < n_reg) idx <= idx + 1;
        end
      end
      else if (state == ST_DONE) begin
        done <= 1'b1; // 1-cycle pulse

        // Determine validity and assemble restored array on completion
        if (state == ST_IDLE) begin
          // In case we entered DONE directly from IDLE (e.g., invalid constraints),
          // keep outputs as-is.
          valid <= 1'b0;
        end else begin
          // We're transitioning from either IDLE->DONE (start on n=0 or q=0)
          // or from PROC->DONE (after scan or earlier invalid/timeout).
          if (state == ST_IDLE) begin
            valid <= 1'b0;
          end else begin
            // We are completing either from PROC or directly from IDLE
            if (state == ST_IDLE) begin
              valid <= 1'b0;
            end else begin
              // Final determination
              if ((state == ST_IDLE) || (n_reg == 0) || (q_reg == 0) || (n_reg > 8)) begin
                valid <= 1'b0;
              end else begin
                // If we didn't find any zero and q wasn't present, impossible to ensure q
                if (!zero_valid && !q_placed) begin
                  valid <= 1'b0;
                end else begin
                  valid <= ~invalid_flag;
                end
              end
            end
            // Capture restored array on completion (valid or not, but only valid outputs are meaningful)
            restored[0] <= elems[0];
            restored[1] <= elems[1];
            restored[2] <= elems[2];
            restored[3] <= elems[3];
            restored[4] <= elems[4];
            restored[5] <= elems[5];
            restored[6] <= elems[6];
            restored[7] <= elems[7];
            restored_0 <= elems[0];
            restored_1 <= elems[1];
            restored_2 <= elems[2];
            restored_3 <= elems[3];
            restored_4 <= elems[4];
            restored_5 <= elems[5];
            restored_6 <= elems[6];
            restored_7 <= elems[7];
          end
        end
      end
    end
  end

endmodule
