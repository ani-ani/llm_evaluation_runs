module loda_teleportations(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0]  string_count,
  input  [15:0][7:0] strings [0:7],
  input  [4:0] lengths [0:7],
  output reg [3:0] max_length,
  output reg       done
);

  // Internal signals
  reg [7:0] adj [0:7];          // adj[i][j] == 1 if edge i->j exists
  reg [7:0] node_valid;         // indicates valid nodes (0..string_count-1)
  reg [3:0] dp   [0:7];         // longest path length ending at node i

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_BUILD_ADJ = 3'd1,
    S_DP_INIT   = 3'd2,
    S_DP_RUN    = 3'd3,
    S_DONE      = 3'd4
  } state_t;

  state_t state, next_state;

  // Counters and control
  reg [2:0] i_idx, j_idx;       // indices for adjacency building
  reg       build_done;

  reg [2:0] dp_i;               // outer index for DP
  reg [2:0] dp_j;               // inner index for DP
  reg [3:0] best_for_i;         // temp best for current i
  reg       dp_outer_done;
  reg       dp_inner_done;

  // Helpers for comparisons
  reg [4:0] li, lj;
  reg       cmp_active;
  reg [4:0] pos_start;
  reg [4:0] pos_end;
  reg       prefix_ok;
  reg       suffix_ok;

  // Combinational: determine valid nodes mask
  integer k;
  always @* begin
    node_valid = 8'b0;
    for (k = 0; k < 8; k = k + 1) begin
      if (k < string_count && lengths[k] != 5'd0)
        node_valid[k] = 1'b1;
      else
        node_valid[k] = 1'b0;
    end
  end

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= S_IDLE;
    else
      state <= next_state;
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_BUILD_ADJ;
      end

      S_BUILD_ADJ: begin
        if (build_done)
          next_state = S_DP_INIT;
      end

      S_DP_INIT: begin
        next_state = S_DP_RUN;
      end

      S_DP_RUN: begin
        if (dp_outer_done)
          next_state = S_DONE;
      end

      S_DONE: begin
        // done is 1-cycle pulse, go back to idle
        next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Adjacency computation control
  // We perform character comparisons sequentially over multiple cycles.

  // Comparison engine: compares strings[i_idx] and strings[j_idx]
  // to decide if strings[j_idx] starts with AND ends with strings[i_idx]

  // li, lj: lengths
  always @* begin
    li = lengths[i_idx];
    lj = lengths[j_idx];
  end

  // Comparison FSM (embedded): when cmp_active is set, we iterate pos_start
  // for prefix and pos_end for suffix checks.

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i_idx       <= 3'd0;
      j_idx       <= 3'd0;
      build_done  <= 1'b0;
      cmp_active  <= 1'b0;
      pos_start   <= 5'd0;
      pos_end     <= 5'd0;
      prefix_ok   <= 1'b0;
      suffix_ok   <= 1'b0;
      for (k = 0; k < 8; k = k + 1) begin
        adj[k] <= 8'b0;
      end
    end else begin
      case (state)
        S_IDLE: begin
          // Clear adjacency on new start
          if (start) begin
            for (k = 0; k < 8; k = k + 1) begin
              adj[k] <= 8'b0;
            end
            i_idx      <= 3'd0;
            j_idx      <= 3'd0;
            build_done <= 1'b0;
            cmp_active <= 1'b0;
            pos_start  <= 5'd0;
            pos_end    <= 5'd0;
            prefix_ok  <= 1'b0;
            suffix_ok  <= 1'b0;
          end else begin
            build_done <= 1'b0;
          end
        end

        S_BUILD_ADJ: begin
          if (!cmp_active) begin
            // Move to next (i,j) pair or start comparison
            if (i_idx >= 3'd7 || (i_idx >= string_count[2:0] && string_count < 8)) begin
              build_done <= 1'b1;
            end else begin
              // Skip invalid i
              if (!node_valid[i_idx]) begin
                if (i_idx == 3'd7) begin
                  build_done <= 1'b1;
                end else begin
                  i_idx <= i_idx + 3'd1;
                  j_idx <= i_idx + 3'd1;
                end
              end else begin
                // Ensure j_idx > i_idx and within bounds
                if (j_idx <= i_idx || j_idx > 3'd7 || j_idx >= string_count[2:0]) begin
                  if (i_idx == 3'd7) begin
                    build_done <= 1'b1;
                  end else begin
                    i_idx <= i_idx + 3'd1;
                    j_idx <= i_idx + 3'd2;
                  end
                end else if (!node_valid[j_idx]) begin
                  // Skip invalid j, advance j
                  if (j_idx == 3'd7) begin
                    if (i_idx == 3'd7) begin
                      build_done <= 1'b1;
                    end else begin
                      i_idx <= i_idx + 3'd1;
                      j_idx <= i_idx + 3'd2;
                    end
                  end else begin
                    j_idx <= j_idx + 3'd1;
                  end
                end else begin
                  // Valid (i,j), start comparison
                  cmp_active <= 1'b1;
                  pos_start  <= 5'd0;
                  prefix_ok  <= 1'b1; // assume ok, clear on mismatch
                  // pos_end will be set when prefix done
                  suffix_ok  <= 1'b1; // assume ok, clear on mismatch
                end
              end
            end
          end else begin
            // Comparison in progress
            if (prefix_ok && pos_start < li && li != 0 && lj >= li) begin
              // Check prefix: strings[j][pos_start] vs strings[i][pos_start]
              if (strings[j_idx][pos_start] != strings[i_idx][pos_start]) begin
                prefix_ok <= 1'b0;
              end
              pos_start <= pos_start + 5'd1;
            end else if (prefix_ok && (pos_start >= li || li == 0)) begin
              // Prefix done; now do suffix
              if (li == 0 || lj < li) begin
                suffix_ok <= 1'b0;
                // directly finish
                // record edge if both ok below
              end else begin
                pos_end <= 5'd0;
                // next cycles: check suffix
                // suffix_ok already 1, clear on mismatch
              end
              // Move to suffix stage immediately (handled next)
              prefix_ok <= prefix_ok; // keep
            end else if (prefix_ok && suffix_ok && pos_end < li && li != 0 && lj >= li) begin
              // Check suffix: strings[j][lj-li+pos_end] vs strings[i][pos_end]
              if (strings[j_idx][lj - li + pos_end] != strings[i_idx][pos_end]) begin
                suffix_ok <= 1'b0;
              end
              pos_end <= pos_end + 5'd1;
            end

            // Termination condition for comparison
            if (!prefix_ok || !suffix_ok || (prefix_ok && suffix_ok && pos_end >= li && li != 0)) begin
              // Decide edge
              if (prefix_ok && suffix_ok && li != 0 && lj >= li)
                adj[i_idx][j_idx] <= 1'b1;

              // Advance to next j
              cmp_active <= 1'b0;
              if (j_idx == 3'd7 || j_idx + 3'd1 >= string_count[2:0]) begin
                // go to next i
                if (i_idx == 3'd7 || i_idx + 3'd1 >= string_count[2:0]) begin
                  build_done <= 1'b1;
                end else begin
                  i_idx <= i_idx + 3'd1;
                  j_idx <= i_idx + 3'd2;
                end
              end else begin
                j_idx <= j_idx + 3'd1;
              end
            end
          end
        end

        default: begin
          // No adjacency changes in other states
        end
      endcase
    end
  end

  // DP computation: longest path in DAG with edges i->j for j>i.
  // We assume nodes are already in topological order (0..N-1).

  integer m;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (m = 0; m < 8; m = m + 1) begin
        dp[m] <= 4'd0;
      end
      dp_i          <= 3'd0;
      dp_j          <= 3'd0;
      best_for_i    <= 4'd0;
      dp_outer_done <= 1'b0;
      dp_inner_done <= 1'b0;
      max_length    <= 4'd0;
      done          <= 1'b0;
    end else begin
      case (state)
        S_DP_INIT: begin
          // Initialize DP for valid nodes
          for (m = 0; m < 8; m = m + 1) begin
            if (node_valid[m])
              dp[m] <= 4'd1; // path of length 1 (node itself)
            else
              dp[m] <= 4'd0;
          end
          dp_i          <= 3'd0;
          dp_j          <= 3'd0;
          best_for_i    <= 4'd0;
          dp_inner_done <= 1'b0;
          dp_outer_done <= 1'b0;
          max_length    <= 4'd0;
          done          <= 1'b0;
        end

        S_DP_RUN: begin
          if (!dp_outer_done) begin
            if (!node_valid[dp_i]) begin
              // skip invalid node
              if (dp_i == 3'd7 || dp_i + 3'd1 >= string_count[2:0]) begin
                dp_outer_done <= 1'b1;
              end else begin
                dp_i          <= dp_i + 3'd1;
                dp_j          <= 3'd0;
                best_for_i    <= dp[dp_i + 3'd1];
                dp_inner_done <= 1'b0;
              end
            end else if (!dp_inner_done) begin
              // Iterate over all k < i for dp update
              if (dp_j < dp_i) begin
                if (node_valid[dp_j] && adj[dp_j][dp_i]) begin
                  if (dp[dp_j] + 4'd1 > best_for_i)
                    best_for_i <= dp[dp_j] + 4'd1;
                end
                dp_j <= dp_j + 3'd1;
              end else begin
                // inner done, update dp[dp_i]
                if (best_for_i > dp[dp_i])
                  dp[dp_i] <= best_for_i;
                dp_inner_done <= 1'b1;
              end
            end else begin
              // move to next i
              if (dp_i == 3'd7 || dp_i + 3'd1 >= string_count[2:0]) begin
                dp_outer_done <= 1'b1;
              end else begin
                dp_i          <= dp_i + 3'd1;
                dp_j          <= 3'd0;
                best_for_i    <= dp[dp_i + 3'd1];
                dp_inner_done <= 1'b0;
              end
            end
          end
        end

        S_DONE: begin
          // Compute max_length from dp
          max_length <= 4'd0;
          for (m = 0; m < 8; m = m + 1) begin
            if (dp[m] > max_length)
              max_length <= dp[m];
          end
          done <= 1'b1; // 1-cycle pulse
        end

        S_IDLE: begin
          done <= 1'b0;
        end

        default: begin
          // no-op
        end
      endcase
    end
  end

endmodule