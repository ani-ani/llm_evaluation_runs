module store_path_detector (
  input  clk,
  input  rst_n,
  input  start,
  input  [1:0] num_stores,       // N = 4 max (0..3)
  input  [3:0][1:0] store_ids,   // up to 4 inventory pairs (store_id)
  input  [3:0][1:0] item_ids,    // up to 4 inventory pairs (item_id)
  input  [3:0][1:0] bought_list, // M items to buy (0..3), processed in order
  input  [1:0] num_bought,       // M = 4 max (0..3)
  output reg [1:0] result,       // 00=impossible, 01=unique, 10=ambiguous
  output reg done
);

  // Internal constants and types
  localparam STW = $clog2(4+1);  // width to encode store index 0..4
  localparam W   = 1 << (4+1);   // bit-width for state bitmask (bit k => store index k reachable)
  typedef logic [W-1:0] bitmask_t;

  // State
  bitmask_t state_r, state_next;
  logic [$clog2(4+1)-1:0] cur_item_r, cur_item_next;
  logic [$clog2(4+1)-1:0] cur_store_r, cur_store_next;
  logic [$clog2(4+2)-1:0] step_r, step_next; // counts 0..(M+1)
  logic started_q;
  logic [$clog2(4+2)-1:0] target_steps; // M+2

  // Helper: check if item is available in the current store
  function item_available_in_store;
    input [1:0] item_id;
    input [1:0] store_idx;
    integer i;
    begin
      item_available_in_store = 1'b0;
      for (i = 0; i < 4; i = i + 1) begin
        if (store_ids[i] == store_idx && item_ids[i] == item_id) begin
          item_available_in_store = 1'b1;
        end
      end
    end
  endfunction

  // Count number of bits set in a bitmask (max store index is 0..4, so width 32 is safe)
  function [$clog2(4+2)-1:0] count_ones;
    input [31:0] v;
    integer j;
    begin
      count_ones = 0;
      for (j = 0; j < 32; j = j + 1) begin
        if (v[j]) count_ones = count_ones + 1;
      end
    end
  endfunction

  // Compute target number of cycles: M + 2
  assign target_steps = {{1'b0}, num_bought} + 2'b10; // M + 2

  // Sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_r      <= '0;  // no paths reachable yet
      cur_item_r   <= '0;
      cur_store_r  <= '0;
      step_r       <= '0;
      started_q    <= 1'b0;
      result       <= 2'b00;
      done         <= 1'b0;
    end else begin
      // Latch current state
      state_r      <= state_next;
      cur_item_r   <= cur_item_next;
      cur_store_r  <= cur_store_next;
      step_r       <= step_next;
      started_q    <= start | started_q; // detect start pulse (latch)

      // On step == target_steps, finalize and hold done
      if (step_next == target_steps) begin
        done <= 1'b1;
        if (count_ones(state_r) == 0)       result <= 2'b00; // impossible
        else if (count_ones(state_r) == 1)  result <= 2'b01; // unique
        else                                result <= 2'b10; // ambiguous
      end else begin
        done   <= 1'b0; // keep 0 until processing finishes
        result <= result; // hold previous result
      end
    end
  end

  // Next-state logic
  always @(*) begin
    // Defaults (hold state)
    state_next   = state_r;
    cur_item_next= cur_item_r;
    cur_store_next= cur_store_r;
    step_next    = step_r;

    if (!started_q) begin
      // Idle until start is asserted
      if (start) begin
        // Initialize for a new run
        state_next   = {1'b1, {(W-1){1'b0}}}; // only "end" state (index 4) is reachable at start
        cur_item_next= '0;
        cur_store_next= '0;
        step_next    = '0;
      end
      // else remain idle
    end else if (done) begin
      // Hold result after completion
      state_next   = state_r;
      cur_item_next= cur_item_r;
      cur_store_next= cur_store_r;
      step_next    = step_r;
    end else begin
      // Active processing
      // item to process this step
      cur_item_next = cur_item_r;
      cur_store_next= cur_store_r;
      step_next     = step_r + 1;

      // Determine transitions given current state (set of possible store indices)
      // For each possible store index k in [0..4], propagate to next set:
      // - If item available at store k: buy it and advance to store k+1
      // - If not: stay at store k (item not seen yet, keep looking in later stores)
      state_next = '0;
      if (cur_item_r < num_bought) begin
        if (item_available_in_store(bought_list[cur_item_r], 0)) state_next[1] = 1'b1; else state_next[0] = 1'b1;
        if (item_available_in_store(bought_list[cur_item_r], 1)) state_next[2] = 1'b1; else state_next[1] = state_next[1] | 1'b0; // keep
        if (item_available_in_store(bought_list[cur_item_r], 2)) state_next[3] = 1'b1; else state_next[2] = state_next[2] | 1'b0;
        if (item_available_in_store(bought_list[cur_item_r], 3)) state_next[4] = 1'b1; else state_next[3] = state_next[3] | 1'b0;
        // state_next[4] only gets set if available at store 3 and we can buy it to reach 4
      end else begin
        // After all M items processed, just carry forward the "end" marker if present
        // No new transitions; the number of reachable states remains unchanged
        state_next = state_r;
      end

      // Advance indices for next cycle
      cur_item_next  = (step_next == (num_bought + 1)) ? cur_item_r : (cur_item_r + 1);
      cur_store_next = cur_store_r; // not needed in this bitmask-based approach
    end
  end

endmodule