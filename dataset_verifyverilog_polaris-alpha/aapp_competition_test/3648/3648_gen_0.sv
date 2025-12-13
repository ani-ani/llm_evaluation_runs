module secure_telecom_network(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0]  num_buildings,
  input  [3:0]  num_edges,
  input  [2:0]  num_insecure,
  input  [7:0]  insecure_mask,
  input  [2:0]  edge_src [0:15],
  input  [2:0]  edge_dst [0:15],
  input  [15:0] edge_cost[0:15],
  output reg [15:0] total_cost,
  output reg        done
);

  // Internal state machine
  typedef enum logic [3:0] {
    S_IDLE      = 4'd0,
    S_INIT      = 4'd1,
    S_SORT_INIT = 4'd2,
    S_SORT_LOAD = 4'd3,
    S_SORT_INS  = 4'd4,
    S_MST_INIT  = 4'd5,
    S_MST_PROC  = 4'd6,
    S_VALIDATE  = 4'd7,
    S_DONE      = 4'd8
  } state_t;

  state_t state, next_state;

  // Sorted edge arrays
  reg [2:0]  s_src  [0:15];
  reg [2:0]  s_dst  [0:15];
  reg [15:0] s_cost [0:15];

  // Temporary registers for sort
  reg [3:0] sort_i;       // index of element being inserted (1..num_edges-1)
  reg [3:0] sort_j;       // scan index during insertion
  reg [2:0] key_src;
  reg [2:0] key_dst;
  reg [15:0] key_cost;
  reg        inserting;

  // Union-Find for up to 8 buildings
  reg [2:0] parent [0:7];
  reg [2:0] rank_r [0:7];

  // Degrees and insecure flags
  reg [3:0] degree [0:7];

  // MST construction
  reg [3:0] edge_idx;     // index over sorted edges
  reg [3:0] edges_used;   // number of edges in MST
  reg [15:0] cost_accum;

  // Control / helper
  reg [2:0] n_nodes;      // cached num_buildings (1..8)
  reg [3:0] m_edges;      // cached num_edges

  // Validation
  reg        valid_mst;
  reg [2:0]  val_idx;

  // Internal for union-find operations
  reg [2:0] uf_u, uf_v;
  reg [2:0] uf_ru, uf_rv;
  reg       uf_do_union;
  reg       uf_cycle;

  // Helper functions
  function automatic [2:0] find_root(
    input [2:0] node,
    input [2:0] p0,
    input [2:0] p1,
    input [2:0] p2,
    input [2:0] p3,
    input [2:0] p4,
    input [2:0] p5,
    input [2:0] p6,
    input [2:0] p7
  );
    reg [2:0] cur;
    reg [2:0] nxt;
    begin
      cur = node;
      while (1) begin
        case (cur)
          3'd0: nxt = p0;
          3'd1: nxt = p1;
          3'd2: nxt = p2;
          3'd3: nxt = p3;
          3'd4: nxt = p4;
          3'd5: nxt = p5;
          3'd6: nxt = p6;
          default: nxt = p7;
        endcase
        if (nxt == cur)
          break;
        else
          cur = nxt;
      end
      find_root = cur;
    end
  endfunction

  // Combinational next-state and some control
  always @(*) begin
    next_state = state;
    uf_do_union = 1'b0;
    uf_cycle    = 1'b0;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_SORT_INIT;
      end

      S_SORT_INIT: begin
        if (m_edges == 0)
          next_state = S_MST_INIT;
        else
          next_state = S_SORT_LOAD;
      end

      S_SORT_LOAD: begin
        // after loading initial edges, start insertion sort
        if (sort_i >= m_edges)
          next_state = S_MST_INIT;
        else
          next_state = S_SORT_INS;
      end

      S_SORT_INS: begin
        // perform insertion steps over cycles
        if (!inserting) begin
          // finished current insertion
          if (sort_i + 1 < m_edges)
            next_state = S_SORT_INS; // will start next insertion in seq block
          else
            next_state = S_MST_INIT;
        end else begin
          // keep inserting until place found
          next_state = S_SORT_INS;
        end
      end

      S_MST_INIT: begin
        next_state = S_MST_PROC;
      end

      S_MST_PROC: begin
        // iterate edges; stop when all checked or MST complete
        if (edge_idx >= m_edges || edges_used == (n_nodes > 0 ? (n_nodes - 1) : 0))
          next_state = S_VALIDATE;
        else
          next_state = S_MST_PROC;
      end

      S_VALIDATE: begin
        // after validation iterations, go DONE
        if (val_idx >= n_nodes)
          next_state = S_DONE;
        else
          next_state = S_VALIDATE;
      end

      S_DONE: begin
        // stay done until next start pulse
        if (start)
          next_state = S_INIT;
        else
          next_state = S_DONE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  integer i;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      total_cost <= 16'hFFFF;
      done       <= 1'b0;
      n_nodes    <= 3'd0;
      m_edges    <= 4'd0;
      sort_i     <= 4'd0;
      sort_j     <= 4'd0;
      inserting  <= 1'b0;
      edge_idx   <= 4'd0;
      edges_used <= 4'd0;
      cost_accum <= 16'h0000;
      valid_mst  <= 1'b0;
      val_idx    <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        parent[i] <= 3'(i[2:0]);
        rank_r[i] <= 3'd0;
        degree[i] <= 4'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          total_cost <= 16'hFFFF;
          if (start) begin
            // latch inputs
            n_nodes <= (num_buildings == 0) ? 3'd0 : num_buildings;
            m_edges <= num_edges;
          end
        end

        S_INIT: begin
          // Initialize structures for new run
          done       <= 1'b0;
          total_cost <= 16'hFFFF;
          sort_i     <= 4'd1;   // insertion sort from index 1
          sort_j     <= 4'd0;
          inserting  <= 1'b0;
          edge_idx   <= 4'd0;
          edges_used <= 4'd0;
          cost_accum <= 16'h0000;
          valid_mst  <= 1'b1;   // assume valid until proven otherwise
          val_idx    <= 3'd0;
          // init union-find & degree
          for (i = 0; i < 8; i = i + 1) begin
            parent[i] <= 3'(i[2:0]);
            rank_r[i] <= 3'd0;
            degree[i] <= 4'd0;
          end
        end

        S_SORT_INIT: begin
          // Load unsorted edges directly into s_* arrays
          for (i = 0; i < 16; i = i + 1) begin
            if (i < m_edges) begin
              s_src[i]  <= (edge_src[i] == 3'd0) ? 3'd0 : (edge_src[i] - 3'd1);
              s_dst[i]  <= (edge_dst[i] == 3'd0) ? 3'd0 : (edge_dst[i] - 3'd1);
              s_cost[i] <= edge_cost[i];
            end else begin
              s_src[i]  <= 3'd0;
              s_dst[i]  <= 3'd0;
              s_cost[i] <= 16'hFFFF;
            end
          end
          sort_i    <= (m_edges > 1) ? 4'd1 : m_edges;
          sort_j    <= 4'd0;
          inserting <= 1'b0;
        end

        S_SORT_LOAD: begin
          // prepare for insertion sort; actual data already loaded
          if (m_edges <= 1) begin
            // nothing to sort
          end else begin
            // start first insertion
            key_src   <= s_src[sort_i];
            key_dst   <= s_dst[sort_i];
            key_cost  <= s_cost[sort_i];
            sort_j    <= sort_i - 1;
            inserting <= 1'b1;
          end
        end

        S_SORT_INS: begin
          if (m_edges <= 1) begin
            inserting <= 1'b0;
          end else begin
            if (inserting) begin
              // Compare key with s_cost[sort_j]
              if (s_cost[sort_j] > key_cost && sort_j < 4'd15) begin
                // shift element up
                s_src[sort_j+1]  <= s_src[sort_j];
                s_dst[sort_j+1]  <= s_dst[sort_j];
                s_cost[sort_j+1] <= s_cost[sort_j];
                if (sort_j == 0) begin
                  // place key at position 0
                  s_src[0]  <= key_src;
                  s_dst[0]  <= key_dst;
                  s_cost[0] <= key_cost;
                  inserting <= 1'b0;
                end else begin
                  sort_j <= sort_j - 1;
                end
              end else begin
                // place key at position sort_j+1
                s_src[sort_j+1]  <= key_src;
                s_dst[sort_j+1]  <= key_dst;
                s_cost[sort_j+1] <= key_cost;
                inserting <= 1'b0;
              end
            end else begin
              // finished one insertion; move to next if any
              if (sort_i + 1 < m_edges) begin
                sort_i    <= sort_i + 1;
                key_src   <= s_src[sort_i + 1];
                key_dst   <= s_dst[sort_i + 1];
                key_cost  <= s_cost[sort_i + 1];
                sort_j    <= sort_i;
                inserting <= 1'b1;
              end
            end
          end
        end

        S_MST_INIT: begin
          // Ensure UF and degree are reset (already in INIT, but safe)
          for (i = 0; i < 8; i = i + 1) begin
            parent[i] <= 3'(i[2:0]);
            rank_r[i] <= 3'd0;
            degree[i] <= 4'd0;
          end
          edge_idx   <= 4'd0;
          edges_used <= 4'd0;
          cost_accum <= 16'h0000;
          // Edge cases: if n_nodes <=1, MST cost=0 if consistent
          if (n_nodes <= 1) begin
            valid_mst <= 1'b1;
          end else begin
            valid_mst <= 1'b1;
          end
        end

        S_MST_PROC: begin
          if (edge_idx < m_edges && edges_used < (n_nodes > 0 ? (n_nodes - 1) : 0)) begin
            // process edge edge_idx
            uf_u = s_src[edge_idx];
            uf_v = s_dst[edge_idx];

            // Ignore edges with endpoints >= n_nodes
            if (uf_u < n_nodes && uf_v < n_nodes) begin
              uf_ru = find_root(uf_u,
                               parent[0], parent[1], parent[2], parent[3],
                               parent[4], parent[5], parent[6], parent[7]);
              uf_rv = find_root(uf_v,
                               parent[0], parent[1], parent[2], parent[3],
                               parent[4], parent[5], parent[6], parent[7]);

              if (uf_ru != uf_rv) begin
                // union by rank
                if (rank_r[uf_ru] < rank_r[uf_rv]) begin
                  parent[uf_ru] <= uf_rv;
                end else if (rank_r[uf_ru] > rank_r[uf_rv]) begin
                  parent[uf_rv] <= uf_ru;
                end else begin
                  parent[uf_rv] <= uf_ru;
                  rank_r[uf_ru] <= rank_r[uf_ru] + 1'b1;
                end

                // increment degrees
                degree[uf_u] <= degree[uf_u] + 1'b1;
                degree[uf_v] <= degree[uf_v] + 1'b1;

                // accumulate cost
                cost_accum   <= cost_accum + s_cost[edge_idx];
                edges_used   <= edges_used + 1'b1;
              end
            end

            edge_idx <= edge_idx + 1'b1;
          end
        end

        S_VALIDATE: begin
          // Check MST completion and constraints over multiple cycles
          if (val_idx == 0) begin
            // First cycle: basic MST validity
            if (n_nodes == 0) begin
              valid_mst <= 1'b0;
            end else if (n_nodes == 1) begin
              // single node: no edges needed, always valid, unless insecure leaf rule breaks (degree 0 is leaf)
              valid_mst <= 1'b1;
            end else begin
              // Need exactly n_nodes-1 edges
              if (edges_used != (n_nodes - 1)) begin
                valid_mst <= 1'b0;
              end else begin
                // Check connectivity: all nodes share same root
                reg [2:0] root0;
                reg [2:0] rtmp;
                integer k;
                root0 = find_root(3'd0,
                                  parent[0], parent[1], parent[2], parent[3],
                                  parent[4], parent[5], parent[6], parent[7]);
                for (k = 1; k < 8; k = k + 1) begin
                  if (k < n_nodes) begin
                    rtmp = find_root(k[2:0],
                                     parent[0], parent[1], parent[2], parent[3],
                                     parent[4], parent[5], parent[6], parent[7]);
                    if (rtmp != root0) begin
                      valid_mst <= 1'b0;
                    end
                  end
                end
              end
            end
            val_idx <= val_idx + 1'b1;
          end else if (val_idx <= n_nodes && n_nodes != 0) begin
            // For each node, enforce insecure leaf rule
            // note: insecure_mask[0] corresponds to bldg1 => node index 0
            // bit i => building i+1 => node index i
            if (val_idx-1 < n_nodes) begin
              if (insecure_mask[val_idx-1]) begin
                if (degree[val_idx-1] != 4'd1) begin
                  valid_mst <= 1'b0;
                end
              end
            end
            val_idx <= val_idx + 1'b1;
          end else begin
            // done validation
            val_idx <= n_nodes; // hold
          end
        end

        S_DONE: begin
          done <= 1'b1;
          if (valid_mst)
            total_cost <= cost_accum;
          else
            total_cost <= 16'hFFFF;
          // allow restart on start pulse handled via next_state
        end

        default: begin
          // should not happen, go idle
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule