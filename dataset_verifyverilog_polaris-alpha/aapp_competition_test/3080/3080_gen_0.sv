module snack_distribution(
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] adjacency,
  input [2:0] k,
  input [2:0] a,
  input [2:0][2:0] targets,
  output reg [6:0] count,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE          = 3'd0,
    INIT          = 3'd1,
    PATH_COMPUTE  = 3'd2,
    SUBSET_GEN    = 3'd3,
    VALIDATE      = 3'd4,
    UPDATE_COUNT  = 3'd5,
    DONE          = 3'd6
  } state_t;

  state_t state, next_state;

  // Path / reachability related
  // has_path_to_target[v]: node v is on some path from root (0) to at least one target
  reg [7:0] has_path_to_target;
  // temp_next used for fixpoint iteration
  reg [7:0] temp_next;

  // Iteration control for PATH_COMPUTE
  reg [3:0] path_iter;        // enough for convergence on 8 nodes
  reg [2:0] pc_u;             // node index for PATH_COMPUTE outer loop
  reg [2:0] pc_v;             // node index for PATH_COMPUTE inner loop

  // Subset generation
  reg [2:0] subset[3:0];      // holds up to 4 selected node IDs
  reg [2:0] i_sel;            // general-purpose selection index
  reg [2:0] cur_node;         // current node for subset generation

  // For generating combinations depending on k
  // We interpret subset[0..k-1] as strictly increasing node IDs in range 0..7

  // Validation flags
  reg valid_subset;
  reg [7:0] snack_mask;       // mask of selected snack nodes

  // Helper indices
  reg [2:0] idx_target;
  reg [2:0] idx_node;

  // Latch for k and a (to keep stable during operation)
  reg [2:0] k_latched;
  reg [2:0] a_latched;
  reg [2:0][2:0] targets_latched;

  //========================================================================
  // Combinational next-state logic
  //========================================================================
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        next_state = PATH_COMPUTE;
      end

      PATH_COMPUTE: begin
        // After fixed number of iterations (bounded for 8-node DAG), move on
        if (path_iter == 4'd8 && pc_u == 3'd7 && pc_v == 3'd7)
          next_state = SUBSET_GEN;
      end

      SUBSET_GEN: begin
        // Directly go to VALIDATE after generating/setting current subset
        next_state = VALIDATE;
      end

      VALIDATE: begin
        next_state = UPDATE_COUNT;
      end

      UPDATE_COUNT: begin
        // If no more subsets, go DONE; else loop back to SUBSET_GEN
        if (!has_more_subsets)
          next_state = DONE;
        else
          next_state = SUBSET_GEN;
      end

      DONE: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  //========================================================================
  // Helper function: check if more subsets exist (combinational)
  //========================================================================
  // We implement as a function driven by current subset[] and k_latched
  function automatic logic has_more_subsets_func;
    input [2:0] kf;
    input [2:0] s0;
    input [2:0] s1;
    input [2:0] s2;
    input [2:0] s3;
    logic res;
    begin
      res = 1'b0;
      unique case (kf)
        3'd1: begin
          if (s0 < 3'd7) res = 1'b1;
        end
        3'd2: begin
          if (!(s0 == 3'd6 && s1 == 3'd7)) res = 1'b1;
        end
        3'd3: begin
          if (!(s0 == 3'd5 && s1 == 3'd6 && s2 == 3'd7)) res = 1'b1;
        end
        3'd4: begin
          if (!(s0 == 3'd4 && s1 == 3'd5 && s2 == 3'd6 && s3 == 3'd7)) res = 1'b1;
        end
        default: res = 1'b0;
      endcase
      has_more_subsets_func = res;
    end
  endfunction

  wire has_more_subsets;
  assign has_more_subsets = has_more_subsets_func(k_latched, subset[0], subset[1], subset[2], subset[3]);

  //========================================================================
  // Helper task: advance subset (next k-combination in lexicographic order)
  //========================================================================
  task automatic next_subset_task;
    inout [2:0] kf;
    inout [2:0] s0;
    inout [2:0] s1;
    inout [2:0] s2;
    inout [2:0] s3;
    reg [2:0] i;
    begin
      unique case (kf)
        3'd1: begin
          if (s0 < 3'd7) s0 = s0 + 3'd1;
        end
        3'd2: begin
          if (s1 < 3'd7) begin
            s1 = s1 + 3'd1;
          end else if (s0 < 3'd6) begin
            s0 = s0 + 3'd1;
            s1 = s0 + 3'd1;
          end
        end
        3'd3: begin
          if (s2 < 3'd7) begin
            s2 = s2 + 3'd1;
          end else if (s1 < 3'd6) begin
            s1 = s1 + 3'd1;
            s2 = s1 + 3'd1;
          end else if (s0 < 3'd5) begin
            s0 = s0 + 3'd1;
            s1 = s0 + 3'd1;
            s2 = s1 + 3'd1;
          end
        end
        3'd4: begin
          if (s3 < 3'd7) begin
            s3 = s3 + 3'd1;
          end else if (s2 < 3'd6) begin
            s2 = s2 + 3'd1;
            s3 = s2 + 3'd1;
          end else if (s1 < 3'd5) begin
            s1 = s1 + 3'd1;
            s2 = s1 + 3'd1;
            s3 = s2 + 3'd1;
          end else if (s0 < 3'd4) begin
            s0 = s0 + 3'd1;
            s1 = s0 + 3'd1;
            s2 = s1 + 3'd1;
            s3 = s2 + 3'd1;
          end
        end
        default: ;
      endcase
    end
  endtask

  //========================================================================
  // Validation logic (combinational, uses current subset and has_path_to_target)
  // Requirements:
  // 1) For each target area t: every path from root(0) to t has exactly 1 snack.
  //    (We approximate with parallel check: for each simple path implied by adjacency,
  //     use dynamic programming over parents.)
  // 2) Every snack is on some path to a target.
  // For hardware efficiency and given small DAG, implement DP style in one cycle.
  //========================================================================

  // Build snack_mask from subset
  always @(*) begin
    snack_mask = 8'b0;
    if (k_latched >= 3'd1) snack_mask[subset[0]] = 1'b1;
    if (k_latched >= 3'd2) snack_mask[subset[1]] = 1'b1;
    if (k_latched >= 3'd3) snack_mask[subset[2]] = 1'b1;
    if (k_latched >= 3'd4) snack_mask[subset[3]] = 1'b1;
  end

  // DP: ways_one_snack[v] = 1 if all paths 0->v have exactly one snack
  //      ways_zero_snack[v] = 1 if all paths 0->v have zero snacks
  //      ways_multi_snack[v] = 1 if any path 0->v has != (0 or 1) snacks (i.e., >1)
  // We only need consistent condition: for targets, exactly-one on all paths.

  reg ways_zero_snack[7:0];
  reg ways_one_snack[7:0];
  reg ways_multi_snack[7:0];

  integer iu, iv;

  always @(*) begin
    // Initialize for node 0 (root)
    for (iu = 0; iu < 8; iu = iu + 1) begin
      ways_zero_snack[iu]  = 1'b0;
      ways_one_snack[iu]   = 1'b0;
      ways_multi_snack[iu] = 1'b0;
    end

    if (snack_mask[0]) begin
      ways_zero_snack[0]  = 1'b0;
      ways_one_snack[0]   = 1'b1;  // path with root snack
      ways_multi_snack[0] = 1'b0;
    end else begin
      ways_zero_snack[0]  = 1'b1;  // zero snack at start
      ways_one_snack[0]   = 1'b0;
      ways_multi_snack[0] = 1'b0;
    end

    // Topological assumption: nodes are numbered in a valid topological order for the DAG.
    // So we propagate from 0..7 using adjacency[u][v] implying u < v for edges.
    for (iu = 0; iu < 8; iu = iu + 1) begin
      for (iv = iu + 1; iv < 8; iv = iv + 1) begin
        if (adjacency[iu][iv]) begin
          // propagate from iu to iv
          // combine paths counts in a conservative logical manner
          // new_zero: all incoming paths to iv have zero snacks
          // new_one: all incoming paths to iv have exactly one snack
          // new_multi: any incoming path invalid/multi or mixing causes multi

          // For first contributing parent, just assign; for others, merge.
          if (!(ways_zero_snack[iv] | ways_one_snack[iv] | ways_multi_snack[iv])) begin
            // first parent
            if (!snack_mask[iv]) begin
              ways_zero_snack[iv]  = ways_zero_snack[iu];
              ways_one_snack[iv]   = ways_one_snack[iu];
              ways_multi_snack[iv] = ways_multi_snack[iu];
            end else begin
              // adding snack at iv
              ways_zero_snack[iv]  = 1'b0;
              ways_one_snack[iv]   = ways_zero_snack[iu];
              ways_multi_snack[iv] = ways_one_snack[iu] | ways_multi_snack[iu];
            end
          end else begin
            // merge with existing
            reg nz, no, nm;
            nz = ways_zero_snack[iv];
            no = ways_one_snack[iv];
            nm = ways_multi_snack[iv];

            if (!snack_mask[iv]) begin
              // propagate states from iu without new snack
              // Candidate states from this parent
              reg cz, co, cm;
              cz = ways_zero_snack[iu];
              co = ways_one_snack[iu];
              cm = ways_multi_snack[iu];

              // Merge: if any inconsistency or multi appears -> multi
              // zero-only if previously zero and new is zero
              // one-only if previously one and new is one

              // Combine zero
              nz = nz & cz; // still zero-only paths only if all parents zero-only
              // Combine one
              no = no & co; // still one-only if all parents one-only
              // Any mixing or multi -> multi
              if (nm | cm |
                  (nz & (co | cm)) |
                  (no & (cz | cm)) |
                  ((cz & co))) begin
                nm = 1'b1;
                nz = 1'b0;
                no = 1'b0;
              end

            end else begin
              // snack at iv: add 1 snack to all parent paths
              reg cz, co, cm;
              cz = ways_zero_snack[iu];
              co = ways_one_snack[iu];
              cm = ways_multi_snack[iu];

              // After adding snack: zero->one, one/multi->multi
              reg pz, po, pm;
              pz = 1'b0;
              po = cz;
              pm = co | cm;

              // Merge with existing
              // existing states (nz,no,nm) vs new (pz,po,pm)
              // If any conflict or multi -> multi
              if (nm | pm |
                  (nz & (po | pm)) |
                  (no & (pz | pm)) |
                  ((pz & po))) begin
                nm = 1'b1;
                nz = 1'b0;
                no = 1'b0;
              end else begin
                nz = nz & pz;
                no = no & po;
              end
            end

            ways_zero_snack[iv]  = nz;
            ways_one_snack[iv]   = no;
            ways_multi_snack[iv] = nm;
          end
        end
      end
    end
  end

  // Final validity check
  always @(*) begin
    valid_subset = 1'b1;

    // 1) Every snack must be on some path to a target (using has_path_to_target)
    for (iu = 0; iu < 8; iu = iu + 1) begin
      if (snack_mask[iu] && !has_path_to_target[iu]) begin
        valid_subset = 1'b0;
      end
    end

    // 2) For each target, all paths must have exactly one snack
    for (iu = 0; iu < 8; iu = iu + 1) begin
      if (iu < a_latched) begin
        // actual target node id
        reg [2:0] tnode;
        tnode = targets_latched[iu];
        // Must have ways_one and not zero/multi
        if (!(ways_one_snack[tnode] && !ways_zero_snack[tnode] && !ways_multi_snack[tnode])) begin
          valid_subset = 1'b0;
        end
      end
    end
  end

  //========================================================================
  // Sequential logic
  //========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 7'd0;
      done  <= 1'b0;
      has_path_to_target <= 8'b0;
      path_iter <= 4'd0;
      pc_u <= 3'd0;
      pc_v <= 3'd0;
      k_latched <= 3'd0;
      a_latched <= 3'd0;
      subset[0] <= 3'd0;
      subset[1] <= 3'd0;
      subset[2] <= 3'd0;
      subset[3] <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done  <= 1'b0;
          count <= 7'd0;
          if (start) begin
            // latch params
            k_latched <= k;
            a_latched <= a;
            targets_latched <= targets;
          end
        end

        INIT: begin
          // Initialize has_path_to_target using backward propagation from targets
          // Start with targets themselves
          has_path_to_target <= 8'b0;
          for (iu = 0; iu < 8; iu = iu + 1) begin
            if (iu < a_latched) begin
              has_path_to_target[targets_latched[iu]] <= 1'b1;
            end
          end
          // Include direct edges towards currently marked nodes (one pass init)
          path_iter <= 4'd0;
          pc_u <= 3'd0;
          pc_v <= 3'd0;
        end

        PATH_COMPUTE: begin
          // Iteratively propagate has_path_to_target backward through DAG
          // For bounded 8 nodes, 8 iterations are sufficient
          if (path_iter < 4'd8) begin
            // Simple full scan per iteration
            reg [7:0] new_mask;
            new_mask = has_path_to_target;
            for (iu = 0; iu < 8; iu = iu + 1) begin
              for (iv = 0; iv < 8; iv = iv + 1) begin
                if (adjacency[iu][iv] && has_path_to_target[iv]) begin
                  new_mask[iu] = 1'b1;
                end
              end
            end
            has_path_to_target <= new_mask;
            path_iter <= path_iter + 4'd1;
          end
        end

        SUBSET_GEN: begin
          // Initialize or advance subset based on k_latched
          if (count == 7'd0 && !has_more_subsets_func(k_latched, subset[0], subset[1], subset[2], subset[3])) begin
            // first subset initialization
            case (k_latched)
              3'd1: begin
                subset[0] <= 3'd0;
              end
              3'd2: begin
                subset[0] <= 3'd0;
                subset[1] <= 3'd1;
              end
              3'd3: begin
                subset[0] <= 3'd0;
                subset[1] <= 3'd1;
                subset[2] <= 3'd2;
              end
              3'd4: begin
                subset[0] <= 3'd0;
                subset[1] <= 3'd1;
                subset[2] <= 3'd2;
                subset[3] <= 3'd3;
              end
              default: ;
            endcase
          end else begin
            // advance to next subset if not first call
            reg [2:0] s0,s1,s2,s3;
            s0 = subset[0];
            s1 = subset[1];
            s2 = subset[2];
            s3 = subset[3];
            next_subset_task(k_latched, s0, s1, s2, s3);
            subset[0] <= s0;
            subset[1] <= s1;
            subset[2] <= s2;
            subset[3] <= s3;
          end
        end

        VALIDATE: begin
          // purely combinational validity already computed in valid_subset
        end

        UPDATE_COUNT: begin
          if (valid_subset)
            count <= count + 7'd1;
        end

        DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule