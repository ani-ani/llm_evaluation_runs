module k_multihedgehog_checker(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start checking
  input [3:0] num_nodes, // number of nodes (1-16)
  input [3:0] k_value, // hedgehog parameter (0-15)
  input [255:0] adjacency, // flattened 16x16 adjacency matrix (bit [15:0] -> node1, bits [255:240] -> node16)
  output reg result, // 1: Yes, 0: No
  output reg done // high when computation complete
);

  // Internal state and storage
  logic [255:0] cur_adj;       // current adjacency matrix used by the algorithm
  logic [15:0] active_mask;    // bit i = 1 if node i is still present
  logic [3:0] step_cnt;        // how many pruning steps completed (0..16)
  logic found_center;          // indicates whether a valid center node was found
  logic [15:0] center_mask;    // nodes that qualify as center (deg >= 3 and dist <= k from pruned leaves)
  logic invalid;               // early exit if any structural rule fails
  logic [3:0] k_reg;           // latched k_value when start is asserted

  // Helper functions
  function [7:0] popcount8 (input [7:0] v);
    integer i;
    popcount8 = 0;
    for (i = 0; i < 8; i = i + 1) popcount8 = popcount8 + v[i];
  endfunction

  function [7:0] popcount16 (input [15:0] v);
    popcount16 = popcount8(v[7:0]) + popcount8(v[15:8]);
  endfunction

  function [3:0] clz4 (input [3:0] v);
    // count leading zeros over 4 bits (clz4(4'b0) = 4)
    if (v == 4'b0) clz4 = 4;
    else if (v[3]) clz4 = 0;
    else if (v[2]) clz4 = 1;
    else if (v[1]) clz4 = 2;
    else clz4 = 3;
  endfunction

  integer r, c, i, j;

  // Main sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 1'b0;
      done   <= 1'b0;
      cur_adj <= 256'b0;
      active_mask <= 16'b0;
      step_cnt <= 4'b0;
      found_center <= 1'b0;
      center_mask <= 16'b0;
      invalid <= 1'b0;
      k_reg <= 4'b0;
    end else begin
      if (start) begin
        // Latch inputs and initialize
        k_reg <= k_value;
        cur_adj <= adjacency;
        active_mask <= (num_nodes == 4'd0) ? 16'b0 : ({16{1'b1}} >> (4'd16 - num_nodes)); // LSB = node0
        step_cnt <= 4'b0;
        found_center <= 1'b0;
        center_mask <= 16'b0;
        invalid <= 1'b0;
        done <= 1'b0;
        result <= 1'b0; // default unless validated later
      end else if (!done) begin
        // Perform one pruning/checking step per cycle (up to 16 steps)
        if (!invalid) begin
          // Degrees and masks for current step
          logic [15:0] deg_vec, deg1_mask, deg_gt1_mask, leaf_mask, nonleaf_mask;
          logic [15:0] step_leaves, step_center_like, step_invalid_mask, new_active;
          logic [15:0] step_center_mask, step_has_center, step_center_count;
          logic step_violation, step_ok;
          logic [3:0] s;

          deg_vec = 16'b0;
          for (i = 0; i < 16; i = i + 1) begin
            logic [15:0] row;
            row = cur_adj[i*16 +: 16] & active_mask; // neighbors among active nodes
            deg_vec[i] = popcount16(row);
          end
          deg1_mask = (deg_vec == 16'b1);
          leaf_mask = active_mask & deg1_mask;
          deg_gt1_mask = (deg_vec > 16'b1);
          nonleaf_mask = active_mask & ~deg1_mask;

          // Step index
          s = step_cnt;
          // Leaves to be removed this round: all degree-1 nodes
          step_leaves = leaf_mask;
          // Candidates for center (degree >=3) among active nodes
          step_center_like = active_mask & (deg_vec >= 16'd3);
          // Violation mask: after pruning, remaining active should not contain degree 1 nodes
          step_invalid_mask = (deg_vec == 16'b1) & active_mask;

          // Build center mask (deg>=3) and check existence of at least one center node
          step_center_mask = step_center_like;
          step_has_center = |step_center_mask;
          step_center_count = popcount16(step_center_mask);
          step_violation = 1'b0;
          // For k==0 we need exactly one center node; for k>0 we allow up to two centers
          if (k_reg == 4'd0) begin
            if (step_center_count != 4'd1) step_violation = 1'b1;
          end else begin
            if (step_center_count < 4'd1 || step_center_count > 4'd2) step_violation = 1'b1;
          end
          // If no candidate center at this round, mark violation unless pruning not yet started (s=0) and k=0
          if (s == 4'd0 && k_reg == 4'd0) begin
            // allow 0 here; must appear after pruning is complete
          end else begin
            if (!step_has_center) step_violation = 1'b1;
          end

          // Validity of each leaf edge this round (every leaf must be attached to a deg>=3 node)
          for (i = 0; i < 16; i = i + 1) begin
            if (leaf_mask[i]) begin
              logic [15:0] neigh;
              logic [3:0] cnt;
              neigh = cur_adj[i*16 +: 16] & active_mask; // neighbors currently active
              cnt = popcount16(neigh);
              if (cnt != 4'd1) begin
                // leaf must have exactly one neighbor (tree property) - fail
                step_violation = 1'b1;
              end else begin
                // that neighbor must be deg>=3
                j = clz4(~neigh); // index of single 1 bit (neighbors are <=1 due to tree property)
                if (deg_vec[j] < 4'd3) step_violation = 1'b1;
              end
            end
          end

          step_ok = ~step_violation;

          // Update state if step is ok
          if (step_ok) begin
            // Remove all leaves (deg==1) from active set
            new_active = active_mask & ~step_leaves;
            // Clear removed leaves from adjacency to keep future degrees correct
            for (i = 0; i < 16; i = i + 1) begin
              if (step_leaves[i]) begin
                for (j = 0; j < 16; j = j + 1) begin
                  cur_adj[i*16 + j] = 1'b0;
                  cur_adj[j*16 + i] = 1'b0;
                end
              end
            end
            active_mask <= new_active;
            // Track the first center we encounter (if any)
            if (!found_center && step_has_center) begin
              found_center <= 1'b1;
              center_mask <= step_center_mask;
            end else if (found_center) begin
              // For k>0 allow up to 2 centers: keep union of all seen center-like nodes
              center_mask <= center_mask | step_center_mask;
            end
            // Detect early invalid state: leftover degree-1 after pruning
            if (step_invalid_mask != 16'b0) begin
              invalid <= 1'b1;
            end
          end else begin
            // Step failed -> invalid
            invalid <= 1'b1;
          end

          // Advance step counter
          if (step_ok) begin
            if (step_cnt < 4'd16) step_cnt <= step_cnt + 1;
          end
        end

        // Finish when we have completed k_reg rounds OR early invalid OR up to 16 steps
        if (invalid) begin
          result <= 1'b0;
          done <= 1'b1;
        end else if (step_cnt >= k_reg) begin
          // Post-conditions:
          // - Center must exist and have degree >= 3
          // - If k>0, all remaining nodes (if any) must be part of paths to the center with internal nodes of degree 2 only
          logic [15:0] final_center_mask, final_deg_vec;
          logic [15:0] final_active, deg_gt2_mask, deg_eq2_mask, deg1_mask_final, final_violation_mask;
          logic has_center, center_count, center_deg_ok, final_ok;

          final_active = active_mask;
          final_center_mask = center_mask & final_active; // only consider centers still active
          has_center = |final_center_mask;
          center_count = popcount16(final_center_mask);

          // Compute final degrees on the remaining graph
          final_deg_vec = 16'b0;
          for (i = 0; i < 16; i = i + 1) begin
            logic [15:0] row;
            row = cur_adj[i*16 +: 16] & final_active;
            final_deg_vec[i] = popcount16(row);
          end

          // Validate center degree
          center_deg_ok = 1'b0;
          if (has_center) begin
            // All centers must have degree >= 3 (for k==0, there's exactly 1 center; for k>0, at most 2)
            logic [15:0] pass_mask;
            pass_mask = (final_deg_vec >= 16'd3);
            center_deg_ok = (pass_mask & final_center_mask) == final_center_mask;
          end

          // Validate structure: for k>0, all non-center active nodes must be on a simple path to the center with internal degree exactly 2
          final_violation_mask = 16'b0;
          if (k_reg > 4'd0) begin
            // If any non-center active node with degree != 2, invalid
            deg_eq2_mask = (final_deg_vec == 16'd2);
            deg_gt2_mask = (final_deg_vec > 16'd2);
            // non-center nodes should be deg==2 (path internals), and there should be no degree==1 nodes left
            deg1_mask_final = (final_deg_vec == 16'd1);
            if ((deg_gt2_mask & ~final_center_mask) != 16'b0) final_violation_mask = 16'bFFFF;
            if ((deg1_mask_final) != 16'b0) final_violation_mask = 16'bFFFF;
          end else begin
            // k==0: only the center node should remain
            if (popcount16(final_active) != 4'd1) final_violation_mask = 16'bFFFF;
          end

          final_ok = has_center && center_deg_ok && (final_violation_mask == 16'b0);

          result <= final_ok;
          done   <= 1'b1;
        end else if (step_cnt == 4'd16) begin
          // Safety finish if we reached 16 steps without completing k
          result <= 1'b0;
          done   <= 1'b1;
        end
      end
    end
  end

endmodule
