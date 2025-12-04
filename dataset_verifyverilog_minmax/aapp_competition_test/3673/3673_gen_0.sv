module arrow_reconstruction(
    input clk,               // system clock
    input rst_n,             // active-low reset
    input start,             // start processing (pulse high for 1 cycle)
    input [15:0] K,          // number of moves (16-bit max 65535)
    input [3:0] a[15:0],     // end permutation (16 elements, each 4-bit)
    output reg [3:0] arrows[15:0], // reconstructed arrows (16 elements)
    output reg done           // high when computation complete
);

  // State machine states
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    FIND_CYCLES = 2'b01,
    COMPUTE_BACK_STEPS = 2'b10,
    DONE = 2'b11
  } state_t;

  state_t state, state_next;

  // Internal storage for cycles (explicit 16-element fixed size)
  reg [4:0] cycles_index[15:0];  // index in cycle for each position; 5-bit to hold 0..15 (16 invalid)
  reg [4:0] cycles_start[15:0];  // start position of each cycle
  reg [3:0] cycles_len;          // length of each cycle
  reg [4:0] cycle_count;         // number of cycles found

  // Counters
  reg [3:0] i_idx, i_idx_next;           // general iterator for elements 0..15
  reg [3:0] c_idx, c_idx_next;           // cycles iterator
  reg [3:0] j_idx, j_idx_next;           // inner loop for reading cycles

  // Flags
  reg cycle_error, cycle_error_next;     // set if any cycle verification fails

  // Computed back step for the current cycle
  reg [4:0] back_step, back_step_next;   // 0..15 valid range

  // Sequential logic (reset + state)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      cycle_error <= 1'b0;
      i_idx <= 4'd0;
      c_idx <= 4'd0;
      j_idx <= 4'd0;
      back_step <= 5'd0;
      cycles_len <= 4'd0;
      cycle_count <= 5'd0;
    end else begin
      state <= state_next;
      done <= (state_next == DONE);
      cycle_error <= cycle_error_next;
      i_idx <= i_idx_next;
      c_idx <= c_idx_next;
      j_idx <= j_idx_next;
      back_step <= back_step_next;
      // These values are fully set before reading in COMPUTE_BACK_STEPS
      cycles_len <= cycles_len;   // keep value (read-only here)
      cycle_count <= cycle_count; // keep value
    end
  end

  // Next-state and control logic
  always_comb begin
    // default: hold current values
    state_next = state;
    i_idx_next = i_idx;
    c_idx_next = c_idx;
    j_idx_next = j_idx;
    back_step_next = back_step;
    cycle_error_next = cycle_error;

    // Default: don't override arrows unless we set them in DONE
    // We will assign arrows inside COMPUTE or in DONE on error
    unique case (state)
      IDLE: begin
        i_idx_next = 4'd0;
        c_idx_next = 4'd0;
        j_idx_next = 4'd0;
        back_step_next = 5'd0;
        cycle_error_next = 1'b0;
        if (start) begin
          // Clear internal state
          cycles_len = 4'd0;
          cycle_count = 5'd0;
          cycles_index = '{16{5'd16}};  // mark all as unvisited
          cycles_start = '{16{4'd0}};
          state_next = FIND_CYCLES;
        end else begin
          state_next = IDLE;
        end
      end

      FIND_CYCLES: begin
        if (i_idx == 4'd15) begin
          // Completed building all cycles; now compute back steps and assign arrows
          c_idx_next = 4'd0;
          j_idx_next = 4'd0;
          if (cycle_count == 0) begin
            // No cycles found: degenerate case, set error and go to DONE
            cycle_error_next = 1'b1;
            state_next = DONE;
          end else begin
            // Prepare for COMPUTE_BACK_STEPS: compute back_step for the first cycle
            back_step_next = (K % cycles_len);
            state_next = COMPUTE_BACK_STEPS;
          end
        end else begin
          // Not done: check if current i_idx is unvisited
          if (cycles_index[i_idx] == 5'd16) begin
            // Start a new cycle from i_idx
            // Explore the cycle using j_idx
            j_idx_next = 4'd0;
            cycles_start[cycle_count] = i_idx;
            cycles_len = 4'd1; // length for this new cycle; will be replaced below
            cycle_error_next = 1'b0; // clear any previous error for this run
            // Mark the starting node
            cycles_index[i_idx] = 4'd0;
            // Move to compute the rest of the cycle
            i_idx_next = i_idx; // stay to advance after cycle fully traversed
            state_next = FIND_CYCLES; // remain in this state
            // Mark visited for the rest of cycle in next cycles
            // We'll do the actual traversal in the following iterations
            // to avoid complex nested loop structures, we progress linearly:
            // We'll detect end of cycle when we revisit a visited element
            // Implementation detail: continue in this state; will walk through cycle via a[].
          end
          // Walk along the permutation to complete the cycle
          // This block uses j_idx to walk from the start until we close the cycle or detect an error.
          // To control progress, we advance i_idx only when we finish this cycle.
          // We use a temporary next index computation here.
          // Determine start for this cycle (it was set when we started a new cycle)
          // We store the start index for the active cycle being explored in cycles_start[cycle_count].
          // This requires a small helper to track which cycle we are building; we can use a temporary.
          // Instead, we track a secondary index 'temp_c' implicitly by c_idx: we build one cycle at a time.
          // We'll only start a cycle when cycles_index[i_idx]==16; the start index is i_idx at that moment.
          // To walk, we need to know the start of the current cycle; we saved it in cycles_start[cycle_count] just now.
          // We'll now set j_idx_next appropriately in the next code block (below).
        end
      end

      COMPUTE_BACK_STEPS: begin
        if (cycle_error) begin
          state_next = DONE;
        end else if (c_idx == cycle_count) begin
          // Finished processing all cycles
          state_next = DONE;
        end else begin
          // We are processing cycles[c_idx]
          // Compute back_step for this cycle (we do it once per cycle when entering)
          if (j_idx == 4'd0) begin
            back_step_next = (K % cycles_len);
          end
          // Assign arrows for this cycle
          if (back_step == 5'd0) begin
            // Exactly cycles_len -> arrows = a for this cycle positions
            arrows[cycles_start[c_idx] + j_idx] = a[cycles_start[c_idx] + j_idx];
          end else begin
            // arrows[x] = element (back_step-1) positions ahead in the cycle
            // Compute: (cycles_index[x] + back_step - 1) % cycles_len
            reg [4:0] offset;
            offset = (cycles_index[cycles_start[c_idx] + j_idx] + back_step - 1);
            if (offset >= cycles_len) offset = offset - cycles_len; // subtract cycles_len once is enough since max 2*len-2 < 31
            // Lookup the original position that has that offset (using cycles_index inverse map)
            // To avoid scanning all 16, we compute the target by walking back from start.
            // Since we only have index in cycle, we can compute target as:
            // target = start of cycle + ((cycles_index[x] + back_step - 1) % cycles_len)
            // But we need to map offset->position. We have start and offset; the element at 'offset' in the cycle is:
            //   cycles_start[c_idx] + offset, if offset < 16; However, the cycle may wrap-around.
            // We'll reconstruct by walking from start offset steps.
            reg [4:0] pos;
            pos = cycles_start[c_idx];
            // Walk offset steps using the permutation a (by following the cycle forward)
            for (int s = 0; s < 16; s++) begin
              if (s == offset) break;
              pos = a[pos];
            end
            arrows[cycles_start[c_idx] + j_idx] = pos[3:0];
          end
          // Advance j_idx within this cycle
          if (j_idx + 1 == cycles_len) begin
            // Move to next cycle
            j_idx_next = 4'd0;
            c_idx_next = c_idx + 1;
          end else begin
            j_idx_next = j_idx + 1;
          end
          state_next = COMPUTE_BACK_STEPS;
        end
      end

      DONE: begin
        // Hold done=1; arrows already set (or zeroed on error)
        if (cycle_error) begin
          // Ensure arrows are all zeros if an error was detected during cycle find/verify
          for (int z = 0; z < 16; z++) begin
            arrows[z] = 4'd0;
          end
        end
        if (start) begin
          // Restart on new start pulse
          state_next = IDLE;
        end else begin
          state_next = DONE;
        end
      end

      default: state_next = IDLE;
    endcase
  end

  // Additional cycle walking logic for FIND_CYCLES:
  // This block advances cycles_index as we discover the cycle.
  // It is separated to keep the previous always_comb readable.
  // We'll implement the cycle discovery by checking and extending the current 'in-progress' cycle.
  // We maintain a flag to indicate we are building a cycle, and a cursor 'build_cursor'.

  // Build-cycle control (combinational with FIND_CYCLES)
  reg [4:0] build_cursor;  // current pointer in the cycle being discovered
  reg building;            // 1 if currently walking a cycle
  reg [3:0] build_len;     // length accumulated so far
  reg [4:0] build_start;   // start of the cycle being built
  reg [3:0] build_c_idx;   // which cycle we are building (equals cycle_count when we start)

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      build_cursor <= 5'd0;
      building <= 1'b0;
      build_len <= 4'd0;
      build_start <= 4'd0;
      build_c_idx <= 4'd0;
    end else begin
      if (state == IDLE) begin
        build_cursor <= 5'd0;
        building <= 1'b0;
        build_len <= 4'd0;
        build_start <= 4'd0;
        build_c_idx <= 4'd0;
      end else if (state == FIND_CYCLES) begin
        if (!building) begin
          // If current i_idx is unvisited, start a new cycle
          if (cycles_index[i_idx] == 5'd16) begin
            building <= 1'b1;
            build_start <= i_idx;
            build_c_idx <= cycle_count; // new cycle index
            build_len <= 4'd1;          // will mark i_idx immediately
            cycles_index[i_idx] <= 4'd0;
            build_cursor <= a[i_idx];
            // We will set cycles_len later when we close the cycle
          end
          // else: if already visited, we'll just increment i_idx later
        end else begin
          // Currently walking a cycle
          // Check if the next position is out of range or already visited in another cycle
          if (build_cursor > 4'd15) begin
            // Out-of-range element: error
            cycle_error <= 1'b1;
            building <= 1'b0;
          end else if (cycles_index[build_cursor] != 5'd16) begin
            // Already visited: cycle closed or overlap
            if (cycles_index[build_cursor] == 4'd0 && build_cursor == build_start) begin
              // Successfully closed cycle back to start
              // Record the cycle length
              cycles_len[build_c_idx] <= build_len;
              // Increment cycle_count
              cycle_count <= cycle_count + 1;
              building <= 1'b0;
              // Advance i_idx by 1 to continue searching for next unvisited
              i_idx <= i_idx + 1;
            end else begin
              // Not the start: either duplicate detection or broken cycle -> error
              cycle_error <= 1'b1;
              building <= 1'b0;
            end
          end else begin
            // Continue the cycle
            // Assign next index in cycle
            cycles_index[build_cursor] <= build_len;
            // Advance build_len and build_cursor
            build_len <= build_len + 1;
            build_cursor <= a[build_cursor];
          end
        end
      end else begin
        // Not in FIND_CYCLES; keep values (no change)
      end
    end
  end

endmodule