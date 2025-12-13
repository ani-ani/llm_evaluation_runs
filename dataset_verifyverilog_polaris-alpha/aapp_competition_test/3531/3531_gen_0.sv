module constrained_mst(
  input clk,
  input rst_n,
  input start,
  // Configuration
  input [2:0] num_nodes,
  input [3:0] num_edges,
  input [2:0] num_special,
  input [2:0] required_mix_edges,
  // Special nodes (3-bit IDs)
  input [2:0] special1,
  input [2:0] special2,
  input [2:0] special3,
  // Edge list (8 edges max)
  input [2:0] edge1_a, input [2:0] edge1_b, input [6:0] edge1_cost,
  input [2:0] edge2_a, input [2:0] edge2_b, input [6:0] edge2_cost,
  input [2:0] edge3_a, input [2:0] edge3_b, input [6:0] edge3_cost,
  input [2:0] edge4_a, input [2:0] edge4_b, input [6:0] edge4_cost,
  input [2:0] edge5_a, input [2:0] edge5_b, input [6:0] edge5_cost,
  input [2:0] edge6_a, input [2:0] edge6_b, input [6:0] edge6_cost,
  input [2:0] edge7_a, input [2:0] edge7_b, input [6:0] edge7_cost,
  input [2:0] edge8_a, input [2:0] edge8_b, input [6:0] edge8_cost,
  output reg [10:0] total_cost,
  output reg done,
  output reg error
);

  // Internal parameters
  localparam MAX_NODES = 8;
  localparam MAX_EDGES = 8;

  // FSM States
  typedef enum logic [3:0] {
    S_IDLE        = 4'd0,
    S_LOAD        = 4'd1,
    S_SORT_INIT   = 4'd2,
    S_SORT_OUTER  = 4'd3,
    S_SORT_INNER  = 4'd4,
    S_BUILD_FLAGS = 4'd5,
    S_INIT_UF     = 4'd6,
    S_SELECT_LOOP = 4'd7,
    S_FIND_U1     = 4'd8,
    S_FIND_U2     = 4'd9,
    S_UNION_DEC   = 4'd10,
    S_DONE        = 4'd11,
    S_FAIL        = 4'd12
  } state_t;

  state_t state, next_state;

  // Edge storage
  reg [2:0] e_u   [0:MAX_EDGES-1];
  reg [2:0] e_v   [0:MAX_EDGES-1];
  reg [6:0] e_w   [0:MAX_EDGES-1];
  reg       e_mix [0:MAX_EDGES-1]; // 1 if special-regular edge

  // Temporary registers for sorting (bubble sort)
  reg [2:0] tu, tv;
  reg [6:0] tw;

  // Sorting indices
  reg [3:0] i_outer;
  reg [3:0] j_inner;

  // Special node flags
  reg is_special_node [0:MAX_NODES-1];

  // Union-Find data
  reg [2:0] parent [0:MAX_NODES-1];
  reg [3:0] rank_r [0:MAX_NODES-1];

  // Current find/union context
  reg [2:0] find_x;
  reg [2:0] find_y;
  reg [2:0] root_x;
  reg [2:0] root_y;

  // Edge selection control
  reg [3:0] edge_idx;
  reg [3:0] edges_used;
  reg [3:0] mix_count;
  reg [10:0] cost_acc;

  // Config latches
  reg [2:0] cfg_num_nodes;
  reg [3:0] cfg_num_edges;
  reg [2:0] cfg_num_special;
  reg [2:0] cfg_req_mix;

  // Cycle counter to enforce 128-cycle latency window
  reg [6:0] cycle_cnt;

  // Helper wires/functions
  function automatic bit is_special(input [2:0] n);
    begin
      is_special = is_special_node[n];
    end
  endfunction

  // Sequential block
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      total_cost   <= 11'd0;
      done         <= 1'b0;
      error        <= 1'b0;
      cycle_cnt    <= 7'd0;
      cfg_num_nodes <= 3'd0;
      cfg_num_edges <= 4'd0;
      cfg_num_special <= 3'd0;
      cfg_req_mix  <= 3'd0;
      i_outer      <= 4'd0;
      j_inner      <= 4'd0;
      edge_idx     <= 4'd0;
      edges_used   <= 4'd0;
      mix_count    <= 4'd0;
      cost_acc     <= 11'd0;
      for (k = 0; k < MAX_NODES; k = k + 1) begin
        is_special_node[k] <= 1'b0;
        parent[k]          <= 3'd0;
        rank_r[k]          <= 4'd0;
      end
      for (k = 0; k < MAX_EDGES; k = k + 1) begin
        e_u[k]   <= 3'd0;
        e_v[k]   <= 3'd0;
        e_w[k]   <= 7'd0;
        e_mix[k] <= 1'b0;
      end
      tu <= 3'd0;
      tv <= 3'd0;
      tw <= 7'd0;
      find_x <= 3'd0;
      find_y <= 3'd0;
      root_x <= 3'd0;
      root_y <= 3'd0;
    end else begin
      // Default pulse outputs
      done  <= 1'b0;
      error <= 1'b0;

      // Cycle counter: counts while not idle, bounds to 127
      if (state != S_IDLE) begin
        if (cycle_cnt != 7'd127)
          cycle_cnt <= cycle_cnt + 7'd1;
      end else begin
        cycle_cnt <= 7'd0;
      end

      state <= next_state;

      case (state)
        S_IDLE: begin
          if (start) begin
            // Latch configuration and edges
            cfg_num_nodes   <= num_nodes;
            cfg_num_edges   <= num_edges;
            cfg_num_special <= num_special;
            cfg_req_mix     <= required_mix_edges;

            // Load edges in given order; unused entries left as 0
            e_u[0] <= edge1_a; e_v[0] <= edge1_b; e_w[0] <= edge1_cost;
            e_u[1] <= edge2_a; e_v[1] <= edge2_b; e_w[1] <= edge2_cost;
            e_u[2] <= edge3_a; e_v[2] <= edge3_b; e_w[2] <= edge3_cost;
            e_u[3] <= edge4_a; e_v[3] <= edge4_b; e_w[3] <= edge4_cost;
            e_u[4] <= edge5_a; e_v[4] <= edge5_b; e_w[4] <= edge5_cost;
            e_u[5] <= edge6_a; e_v[5] <= edge6_b; e_w[5] <= edge6_cost;
            e_u[6] <= edge7_a; e_v[6] <= edge7_b; e_w[6] <= edge7_cost;
            e_u[7] <= edge8_a; e_v[7] <= edge8_b; e_w[7] <= edge8_cost;

            // Clear specials (set in LOAD)
            for (k = 0; k < MAX_NODES; k = k + 1)
              is_special_node[k] <= 1'b0;

            cost_acc   <= 11'd0;
            edges_used <= 4'd0;
            mix_count  <= 4'd0;
            edge_idx   <= 4'd0;
            i_outer    <= 4'd0;
            j_inner    <= 4'd0;
          end
        end

        S_LOAD: begin
          // Build special node map from special1..3 using cfg_num_special
          // Only IDs < cfg_num_nodes are considered valid
          for (k = 0; k < MAX_NODES; k = k + 1)
            is_special_node[k] <= 1'b0;

          if (cfg_num_special > 3'd0 && special1 < cfg_num_nodes)
            is_special_node[special1] <= 1'b1;
          if (cfg_num_special > 3'd1 && special2 < cfg_num_nodes)
            is_special_node[special2] <= 1'b1;
          if (cfg_num_special > 3'd2 && special3 < cfg_num_nodes)
            is_special_node[special3] <= 1'b1;

          // Init sort indices
          i_outer <= 4'd0;
          j_inner <= 4'd0;
        end

        S_SORT_INIT: begin
          // Start bubble sort: i=0, j=0
          i_outer <= 4'd0;
          j_inner <= 4'd0;
        end

        S_SORT_OUTER: begin
          // Increment outer loop index
          if (i_outer < cfg_num_edges)
            j_inner <= 4'd0;
        end

        S_SORT_INNER: begin
          // Perform one bubble compare/swap per cycle for edges [j_inner] and [j_inner+1]
          if (j_inner + 1 < cfg_num_edges) begin
            if (e_w[j_inner] > e_w[j_inner+1]) begin
              tu                 <= e_u[j_inner];
              tv                 <= e_v[j_inner];
              tw                 <= e_w[j_inner];
              e_u[j_inner]       <= e_u[j_inner+1];
              e_v[j_inner]       <= e_v[j_inner+1];
              e_w[j_inner]       <= e_w[j_inner+1];
              e_u[j_inner+1]     <= tu;
              e_v[j_inner+1]     <= tv;
              e_w[j_inner+1]     <= tw;
            end
            j_inner <= j_inner + 4'd1;
          end
        end

        S_BUILD_FLAGS: begin
          // Build e_mix flags based on special/non-special endpoints
          for (k = 0; k < MAX_EDGES; k = k + 1) begin
            if (k < cfg_num_edges) begin
              if ((is_special(e_u[k]) && !is_special(e_v[k])) ||
                  (!is_special(e_u[k]) && is_special(e_v[k])))
                e_mix[k] <= 1'b1;
              else
                e_mix[k] <= 1'b0;
            end else begin
              e_mix[k] <= 1'b0;
            end
          end

          // Init Union-Find
          for (k = 0; k < MAX_NODES; k = k + 1) begin
            if (k < cfg_num_nodes) begin
              parent[k] <= k[2:0];
              rank_r[k] <= 4'd0;
            end else begin
              parent[k] <= 3'd0;
              rank_r[k] <= 4'd0;
            end
          end

          cost_acc   <= 11'd0;
          edges_used <= 4'd0;
          mix_count  <= 4'd0;
          edge_idx   <= 4'd0;
        end

        S_INIT_UF: begin
          // Nothing extra; UF already initialized in BUILD_FLAGS
        end

        S_SELECT_LOOP: begin
          // Check termination conditions or start find operations for next edge
          if (edges_used == (cfg_num_nodes - 1)) begin
            // Tree complete; in DONE/FAIL state we will check mix_count
          end else if (edge_idx >= cfg_num_edges) begin
            // No more edges; handled in next_state logic
          end else begin
            // Prepare find for current edge
            find_x <= e_u[edge_idx];
            find_y <= e_v[edge_idx];
          end
        end

        S_FIND_U1: begin
          // Path compression step for find_x
          if (parent[find_x] != find_x)
            find_x <= parent[find_x];
          else
            root_x <= find_x;
        end

        S_FIND_U2: begin
          // Path compression for find_y
          if (parent[find_y] != find_y)
            find_y <= parent[find_y];
          else
            root_y <= find_y;
        end

        S_UNION_DEC: begin
          // After roots determined, decide to include edge or skip
          if (root_x != root_y) begin
            // Edge can be added if constraint not violated
            if (!(e_mix[edge_idx] && (mix_count + 1 > cfg_req_mix))) begin
              // Union by rank
              if (rank_r[root_x] < rank_r[root_y]) begin
                parent[root_x] <= root_y;
              end else if (rank_r[root_x] > rank_r[root_y]) begin
                parent[root_y] <= root_x;
              end else begin
                parent[root_y] <= root_x;
                rank_r[root_x] <= rank_r[root_x] + 4'd1;
              end

              // Update accumulators
              cost_acc   <= cost_acc + e_w[edge_idx];
              edges_used <= edges_used + 4'd1;
              if (e_mix[edge_idx])
                mix_count <= mix_count + 4'd1;
            end
          end
          // Move to next edge
          edge_idx <= edge_idx + 4'd1;
        end

        S_DONE: begin
          done       <= 1'b1;
          total_cost <= cost_acc;
        end

        S_FAIL: begin
          done       <= 1'b1;
          error      <= 1'b1;
          total_cost <= 11'd0;
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
      S_IDLE: begin
        if (start)
          next_state = S_LOAD;
      end

      S_LOAD: begin
        next_state = S_SORT_INIT;
      end

      S_SORT_INIT: begin
        if (cfg_num_edges <= 4'd1)
          next_state = S_BUILD_FLAGS;
        else
          next_state = S_SORT_OUTER;
      end

      S_SORT_OUTER: begin
        if (i_outer >= cfg_num_edges)
          next_state = S_BUILD_FLAGS;
        else
          next_state = S_SORT_INNER;
      end

      S_SORT_INNER: begin
        if (j_inner + 1 >= cfg_num_edges) begin
          next_state = S_SORT_OUTER;
        end else begin
          next_state = S_SORT_INNER;
        end
      end

      S_BUILD_FLAGS: begin
        next_state = S_INIT_UF;
      end

      S_INIT_UF: begin
        next_state = S_SELECT_LOOP;
      end

      S_SELECT_LOOP: begin
        // Early abort if cycle limit (safety, but should not hit with small loops)
        if (cycle_cnt == 7'd127) begin
          // Decide based on current progress
          if (edges_used == (cfg_num_nodes - 1) && mix_count == cfg_req_mix)
            next_state = S_DONE;
          else
            next_state = S_FAIL;
        end else if (edges_used == (cfg_num_nodes - 1)) begin
          // Completed spanning tree: check mix_count
          if (mix_count == cfg_req_mix)
            next_state = S_DONE;
          else
            next_state = S_FAIL;
        end else if (edge_idx >= cfg_num_edges) begin
          // Not enough edges to complete tree
          next_state = S_FAIL;
        end else begin
          next_state = S_FIND_U1;
        end
      end

      S_FIND_U1: begin
        // determine if we are done with find_x
        if (parent[find_x] == find_x)
          next_state = S_FIND_U2;
        else
          next_state = S_FIND_U1;
      end

      S_FIND_U2: begin
        if (parent[find_y] == find_y)
          next_state = S_UNION_DEC;
        else
          next_state = S_FIND_U2;
      end

      S_UNION_DEC: begin
        next_state = S_SELECT_LOOP;
      end

      S_DONE: begin
        // Single-cycle done pulse then go idle
        next_state = S_IDLE;
      end

      S_FAIL: begin
        // Single-cycle error pulse then go idle
        next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase

    // Bubble sort outer loop advancement
    if (state == S_SORT_INNER && next_state == S_SORT_OUTER) begin
      // Completed inner loop: increment outer index
      // handled implicitly via seq: i_outer++ in OUTER, but we update here logically
    end
  end

  // Additional sequential logic for outer-loop increment separate from combinational
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i_outer <= 4'd0;
    end else begin
      if (state == S_SORT_INNER && j_inner + 1 >= cfg_num_edges) begin
        if (i_outer < cfg_num_edges)
          i_outer <= i_outer + 4'd1;
      end
    end
  end

endmodule