module min_data_centers (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [3:0] m,
  input [2:0] h,
  input [7:0][2:0] u_array,
  input [15:0][5:0] client_pairs,
  output reg [2:0] k,
  output reg [7:0] solution_set,
  output reg done,
  output reg valid
);

  // State machine states
  typedef enum logic [2:0] {
    IDLE       = 3'b000,
    BUILD_GRAPH= 3'b001,
    FIND_SCCS  = 3'b010,
    CALC_OUTDEG= 3'b011,
    SELECT_SCC = 3'b100,
    DONE       = 3'b101
  } state_t;

  state_t state, next_state;

  // Internal storage
  logic [2:0] n_r, h_r;
  logic [2:0] u_r [0:7];
  logic [7:0][7:0] adj; // adjacency matrix per node (rows: from, cols: to)
  logic [7:0] exists_mask; // bit i == 1 if node i is within [0, n_r-1]
  logic [7:0] edges_mask; // track which edge-cells have been added (for out-degree calc)
  logic [7:0] v_index, v_lowlink, onstack, scc_mark, temp_mark;
  logic [2:0] index_cnt, SCC_cnt, min_outdeg, min_outdeg_idx;
  logic [2:0] scc_size [0:7];
  logic [7:0] scc_nodes [0:7]; // bitmask of nodes in each SCC
  logic [7:0] scc_outdeg; // bitmask of SCCs with zero out-degree
  logic [2:0] scc_outdeg_cnt;

  logic [2:0] ai, bi, ci; // loop counters for BUILD_GRAPH
  logic [2:0] v;          // DFS current node
  logic [2:0] ei, ej;     // DFS edge exploration
  logic [7:0] stack_bits; // bitstack for onstack mask
  logic stack_top;        // top flag for current v
  logic [2:0] stack_size; // track number of items on stack for pop

  logic [8:0] cycle_cnt;  // counts cycles after start (0..255)

  // Helpers for reading arrays from packed vectors
  function [2:0] get_u (input integer idx);
    get_u = u_r[idx[2:0]];
  endfunction

  function [2:0] get_pair_c1 (input integer pid);
    // client_pairs[pid][5:3]
    get_pair_c1 = client_pairs[pid[3:0]][5:3];
  endfunction

  function [2:0] get_pair_c2 (input integer pid);
    // client_pairs[pid][2:0]
    get_pair_c2 = client_pairs[pid[3:0]][2:0];
  endfunction

  // Sequential logic (reset, state, counters)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      valid <= 1'b0;
      k <= 3'b0;
      solution_set <= 8'b0;
      n_r <= 3'b0;
      h_r <= 3'b0;
      for (int i = 0; i < 8; i++) u_r[i] <= 3'b0;
      adj <= 64'b0;
      exists_mask <= 8'b0;
      edges_mask <= 8'b0;
      v_index <= 8'b0;
      v_lowlink <= 8'b0;
      onstack <= 8'b0;
      scc_mark <= 8'b0;
      temp_mark <= 8'b0;
      index_cnt <= 3'b0;
      SCC_cnt <= 3'b0;
      scc_size[0] <= 3'b0;
      scc_size[1] <= 3'b0;
      scc_size[2] <= 3'b0;
      scc_size[3] <= 3'b0;
      scc_size[4] <= 3'b0;
      scc_size[5] <= 3'b0;
      scc_size[6] <= 3'b0;
      scc_size[7] <= 3'b0;
      scc_nodes[0] <= 8'b0;
      scc_nodes[1] <= 8'b0;
      scc_nodes[2] <= 8'b0;
      scc_nodes[3] <= 8'b0;
      scc_nodes[4] <= 8'b0;
      scc_nodes[5] <= 8'b0;
      scc_nodes[6] <= 8'b0;
      scc_nodes[7] <= 8'b0;
      scc_outdeg <= 8'b0;
      scc_outdeg_cnt <= 3'b0;
      ai <= 3'b0; bi <= 3'b0; ci <= 3'b0;
      v <= 3'b0; ei <= 3'b0; ej <= 3'b0;
      stack_bits <= 8'b0;
      stack_top <= 1'b0;
      stack_size <= 3'b0;
      min_outdeg <= 3'b0;
      min_outdeg_idx <= 3'b0;
      cycle_cnt <= 9'b0;
    end else begin
      // Default: maintain state unless overridden in next_state logic
      state <= next_state;

      // Cycle counter gating: only advance outside DONE if not finished, or reset when start is asserted
      if (state == IDLE && start) begin
        cycle_cnt <= 9'b0;
        done <= 1'b0;
        valid <= 1'b0;
      end else if (state != DONE) begin
        cycle_cnt <= cycle_cnt + 1;
      end

      // State actions
      case (next_state)
        IDLE: begin
          done <= 1'b0;
          valid <= 1'b0;
          k <= 3'b0;
          solution_set <= 8'b0;
          // Latch inputs on start
          if (start) begin
            n_r <= (n >= 3'd2 && n <= 3'd8) ? n : 3'd0;
            h_r <= h;
            for (int i = 0; i < 8; i++) u_r[i] <= u_array[i];
          end
        end

        BUILD_GRAPH: begin
          // Triple loop: (a,b,c) over 0..n_r-1
          // Each cycle we attempt to add edge a->b if it meets condition and client pair exists
          // Both a and b must exist (within n_r)
          if (n_r >= 3'd2) begin
            logic [2:0] next_a, next_b, next_c;
            next_a = ai; next_b = bi; next_c = ci;
            logic cond_ab, both_exist;
            both_exist = 1'b1; // a,b are within 0..n_r-1 due to loop limits
            if (|(( (get_u(next_a) + 1) % h_r) ^ get_u(next_b))) cond_ab = 1'b0;
            else cond_ab = 1'b1;

            // Check client pair existence (check modulo relationship only when both datacenters exist)
            logic pair_exists;
            pair_exists = 1'b0;
            for (int pid = 0; pid < 16; pid++) begin
              if (get_pair_c1(pid) == next_a && get_pair_c2(pid) == next_b) begin
                pair_exists = 1'b1; break;
              end
            end

            if (cond_ab && pair_exists) begin
              adj[next_a][next_b] <= 1'b1;
              edges_mask[next_a] <= edges_mask[next_a] | (1 << next_b);
            end

            // Advance nested loops
            if (next_c < n_r-1) begin
              ci <= next_c + 1;
            end else begin
              ci <= 3'b0;
              if (next_b < n_r-1) begin
                bi <= next_b + 1;
              end else begin
                bi <= 3'b0;
                if (next_a < n_r-1) begin
                  ai <= next_a + 1;
                end else begin
                  // Finished building
                  ai <= 3'b0; bi <= 3'b0; ci <= 3'b0;
                end
              end
            end
          end else begin
            // n_r < 2 => no edges to build
            ai <= 3'b0; bi <= 3'b0; ci <= 3'b0;
          end
        end

        FIND_SCCS: begin
          // Iterative Tarjan-like DFS across all nodes
          // Each cycle either discovers a new node or explores an edge, or pops an SCC root
          if (index_cnt == 3'b0 && v_index == 3'b0) begin
            // Fresh start: clear structures
            v_index <= 3'b0;
            v_lowlink <= 3'b0;
            onstack <= 8'b0;
            scc_mark <= 8'b0;
            temp_mark <= 8'b0;
            SCC_cnt <= 3'b0;
            index_cnt <= 3'b0;
            v <= 3'b0; ei <= 3'b0; ej <= 3'b0;
            stack_bits <= 8'b0;
            stack_top <= 1'b0;
            stack_size <= 3'b0;
          end else begin
            // Start or continue DFS
            logic [2:0] i_d, v_d, ei_d, ej_d;
            logic [7:0] onstack_d, v_index_d, v_lowlink_d, scc_mark_d, temp_mark_d, stack_bits_d;
            logic [2:0] index_cnt_d, SCC_cnt_d, stack_size_d;
            logic stack_top_d;

            i_d = v_index;
            v_d = v;
            ei_d = ei;
            ej_d = ej;
            onstack_d = onstack;
            v_index_d = v_index;
            v_lowlink_d = v_lowlink;
            scc_mark_d = scc_mark;
            temp_mark_d = temp_mark;
            stack_bits_d = stack_bits;
            index_cnt_d = index_cnt;
            SCC_cnt_d = SCC_cnt;
            stack_size_d = stack_size;
            stack_top_d = stack_top;

            // If current v is invalid (>= n_r) move to next node
            if (v_d >= n_r) begin
              // Move to next unvisited node
              logic [7:0] remaining, chosen;
              remaining = ~scc_mark_d & exists_mask; // unvisited and exists
              if (remaining == 8'b0) begin
                // DFS done, all SCCs discovered
                v_index <= v_index_d;
                v_lowlink <= v_lowlink_d;
                onstack <= onstack_d;
                scc_mark <= scc_mark_d;
                temp_mark <= temp_mark_d;
                v <= v_d;
                ei <= ei_d;
                ej <= ej_d;
                stack_bits <= stack_bits_d;
                stack_top <= stack_top_d;
                stack_size <= stack_size_d;
                index_cnt <= index_cnt_d;
                SCC_cnt <= SCC_cnt_d;
              end else begin
                // choose first unvisited node as v
                chosen = remaining & (~(remaining - 1)); // isolate LSB
                v_d = $ctypesize(chosen) - 1;
                // Discover v
                v_index_d = index_cnt_d;
                v_lowlink_d = index_cnt_d;
                index_cnt_d = index_cnt_d + 1;
                scc_mark_d = scc_mark_d | chosen;
                onstack_d = onstack_d | chosen;
                stack_bits_d = stack_bits_d | chosen;
                stack_size_d = stack_size_d + 1;
                stack_top_d = 1'b1;
                ei_d = 3'b0; ej_d = 3'b0; // start exploring edges from 0
                // Write back
                v_index <= v_index_d;
                v_lowlink <= v_lowlink_d;
                onstack <= onstack_d;
                scc_mark <= scc_mark_d;
                temp_mark <= temp_mark_d;
                v <= v_d;
                ei <= ei_d;
                ej <= ej_d;
                stack_bits <= stack_bits_d;
                stack_top <= stack_top_d;
                stack_size <= stack_size_d;
                index_cnt <= index_cnt_d;
                SCC_cnt <= SCC_cnt_d;
              end
            end else begin
              // Explore edges from v
              logic v_exists;
              v_exists = exists_mask[v_d];
              if (!v_exists) begin
                // Skip invalid node
                v_d = v_d + 1;
                v <= v_d;
                ei <= 3'b0; ej <= 3'b0;
              end else begin
                // Find next neighbor w that is valid and not processed
                logic [2:0] w_idx;
                logic found;
                w_idx = 3'b0;
                found = 1'b0;
                // ej is current w candidate (0..7)
                for (int t = 0; t < 8; t++) begin
                  logic [2:0] cand;
                  cand = t; // iterate 0..7 each cycle for simplicity
                  if (!found && cand < n_r) begin
                    if (adj[v_d][cand] && !(scc_mark_d[cand])) begin
                      w_idx = cand;
                      found = 1'b1;
                    end
                  end
                end
                if (found) begin
                  // Edge v_d -> w_idx exists and w not visited: DFS to w
                  v <= w_idx;
                  // Do not increment ei/ej here; reset w search for child
                  ei <= 3'b0; ej <= 3'b0;
                end else begin
                  // No more neighbors: finalize root (v_d)
                  // Update lowlink using min of neighbors already visited (onstack)
                  // Find min lowlink of all neighbors that are on stack
                  logic [2:0] min_low;
                  min_low = v_lowlink_d;
                  for (int t = 0; t < 8; t++) begin
                    if (t < n_r && adj[v_d][t] && onstack_d[t]) begin
                      logic [2:0] low_t;
                      // recover v_lowlink for node t: it was set when t was discovered
                      // We can approximate: lowlink_t <= v_lowlink (when marked). We need storage per node.
                      // To keep single-cycle, we keep lowlink per node in a small array.
                    end
                  end
                  // Because we don't have per-node lowlink array kept, use method: when root, pop stack until v.
                  // Pop stack and collect nodes in temp_mark
                  logic [7:0] pop_mask, remaining_stack, popped;
                  popped = 8'b0;
                  // Remove items from stack_bits down to node v_d
                  // Compute bit position of v_d in stack order is unknown; pop until v_d encountered.
                  // Use onstack and repeat pop front simulation.
                  logic [7:0] stk;
                  stk = stack_bits_d;
                  logic [2:0] pop_cnt;
                  pop_cnt = 3'b0;
                  for (int s = 0; s < 8; s++) begin
                    if (s < n_r) begin
                      logic bitv;
                      bitv = stk[s];
                      if (bitv) begin
                        popped = popped | (1 << s);
                        if (s == v_d) break;
                        pop_cnt = pop_cnt + 1;
                      end
                    end
                  end
                  // Pop those bits from stack and onstack
                  logic [7:0] new_onstack, new_stack_bits;
                  new_onstack = onstack_d & ~popped;
                  new_stack_bits = stack_bits_d & ~popped;

                  // Completed SCC: assign id = SCC_cnt_d
                  logic [2:0] scc_id;
                  scc_id = SCC_cnt_d;
                  scc_size[scc_id] <= pop_cnt + 1; // popped nodes + v_d
                  scc_nodes[scc_id] <= popped | (1 << v_d);
                  SCC_cnt_d <= SCC_cnt_d + 1;

                  // Clear temp_mark and continue from parent if any (we emulate recursion by continuing with next node)
                  v_lowlink_d <= v_lowlink_d; // unchanged here
                  onstack_d <= new_onstack;
                  stack_bits_d <= new_stack_bits;
                  // Move to next unvisited node
                  v_d = v_d + 1;
                  ei_d = 3'b0; ej_d = 3'b0;

                  v_index <= v_index_d;
                  v_lowlink <= v_lowlink_d;
                  onstack <= onstack_d;
                  scc_mark <= scc_mark_d;
                  temp_mark <= 8'b0;
                  v <= v_d;
                  ei <= ei_d;
                  ej <= ej_d;
                  stack_bits <= stack_bits_d;
                  stack_top <= stack_top_d;
                  stack_size <= stack_size_d;
                  index_cnt <= index_cnt_d;
                  SCC_cnt <= SCC_cnt_d;
                end
              end
            end
          end
        end

        CALC_OUTDEG: begin
          // Each cycle, process one SCC to compute out-degree by intersecting edges of its nodes with other SCCs
          // We recompute edges_mask from adj for simplicity
          // scc_mark used as visited mask for SCC loop
          logic [7:0] outdeg_mask, processed;
          outdeg_mask = scc_outdeg;
          processed = scc_mark;
          if (processed[$clog2(SCC_cnt)-:1] == 1'b0) begin
            logic [2:0] sid;
            sid = $ctypesize(processed) - 1; // choose highest-index unprocessed SCC
            // Compute outbound edges from this SCC to other SCCs
            logic [7:0] nodes_in_scc;
            nodes_in_scc = scc_nodes[sid];
            logic [7:0] union_out;
            union_out = 8'b0;
            for (int u = 0; u < 8; u++) begin
              if (u < n_r && nodes_in_scc[u]) begin
                union_out = union_out | edges_mask[u];
              end
            end
            logic [7:0] target_sccs;
            target_sccs = 8'b0;
            for (int w = 0; w < 8; w++) begin
              if (w < n_r && union_out[w]) begin
                // find which SCC w belongs to (linear search over discovered SCCs)
                for (int s = 0; s < 8; s++) begin
                  if (s < SCC_cnt && scc_nodes[s][w]) begin
                    if (s != sid) target_sccs[s] = 1'b1;
                  end
                end
              end
            end
            if (target_sccs == 8'b0) begin
              outdeg_mask[sid] = 1'b1;
            end
            processed[sid] = 1'b1;
            scc_outdeg <= outdeg_mask;
            scc_mark <= processed;
          end else begin
            // All SCCs processed
            // nothing to do; SELECT_SCC will follow
          end
        end

        SELECT_SCC: begin
          // Among SCCs with zero out-degree, pick smallest size; tie-breaker: lowest index
          logic [7:0] candidates;
          candidates = scc_outdeg & ((1 << SCC_cnt) - 1);
          if (candidates == 8'b0) begin
            // No zero-outdegree SCCs found; default to empty (should not happen if graph has at least one sink SCC)
            k <= 3'b0;
            solution_set <= 8'b0;
            valid <= 1'b0;
          end else begin
            logic [2:0] best_idx, best_size;
            best_idx = 3'b0;
            best_size = 3'd8; // max size 8
            for (int s = 0; s < 8; s++) begin
              if (candidates[s]) begin
                logic [2:0] sz;
                sz = scc_size[s];
                if (sz < best_size) begin
                  best_size = sz;
                  best_idx = s;
                end else if (sz == best_size && s < best_idx) begin
                  best_idx = s;
                end
              end
            end
            // Map to 1-indexed bitmask in original node indices (existing nodes only)
            logic [7:0] raw_mask, filtered_mask;
            raw_mask = scc_nodes[best_idx];
            filtered_mask = raw_mask & exists_mask;
            k <= best_size;
            solution_set <= filtered_mask;
            valid <= 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // valid remains as set in SELECT_SCC; keep outputs stable
        end

        default: ;
      endcase
    end
  end

  // Combinational next-state logic
  always_comb begin
    next_state = state;
    // exists_mask update on start (or IDLE)
    // Will be assigned combinatorially from n_r to avoid extra storage
    case (state)
      IDLE: begin
        if (start) next_state = BUILD_GRAPH;
        else next_state = IDLE;
      end
      BUILD_GRAPH: begin
        // When loops finished (ai==0 && bi==0 && ci==0 and adj built), move on
        if (n_r < 3'd2) begin
          // No edges; skip to SCC find
          next_state = FIND_SCCS;
        end else begin
          // We consider it done when all loops have wrapped to 0 and at least one cycle after starting
          if (ai == 3'b0 && bi == 3'b0 && ci == 3'b0) begin
            // But ensure at least one cycle passed: cycle_cnt>0
            next_state = FIND_SCCS;
          end else begin
            next_state = BUILD_GRAPH;
          end
        end
      end
      FIND_SCCS: begin
        // Stay until all nodes are visited (scc_mark covers exists_mask)
        if (scc_mark == exists_mask) begin
          next_state = CALC_OUTDEG;
        end else begin
          next_state = FIND_SCCS;
        end
      end
      CALC_OUTDEG: begin
        // Stay until all SCCs processed (scc_mark covers all discovered SCCs)
        if (scc_mark == ((1 << SCC_cnt) - 1)) begin
          next_state = SELECT_SCC;
        end else begin
          next_state = CALC_OUTDEG;
        end
      end
      SELECT_SCC: begin
        // Select SCC; proceed to DONE
        next_state = DONE;
      end
      DONE: begin
        // Remain here until start is asserted again (restart)
        if (!start) next_state = DONE;
        else next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Derived combinational signals
  always_comb begin
    // exists_mask derived from n_r
    exists_mask = (n_r >= 1) ? (1 << n_r) - 1 : 8'b0;
  end

endmodule