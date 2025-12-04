module network_optimizer(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] size_A,
  input  [2:0] size_B,
  input  [63:0] adj_A,
  input  [63:0] adj_B,
  output reg [15:0] min_cost,
  output reg done
);

  // Internal parameters
  localparam IDLE            = 4'd0;
  localparam INIT_BFS_A      = 4'd1;
  localparam BFS_A           = 4'd2;
  localparam NEXT_SRC_A      = 4'd3;
  localparam INIT_BFS_B      = 4'd4;
  localparam BFS_B           = 4'd5;
  localparam NEXT_SRC_B      = 4'd6;
  localparam FIND_MIN_SSA    = 4'd7;
  localparam FIND_MIN_SSB    = 4'd8;
  localparam CALC_COST       = 4'd9;
  localparam DONE_ST         = 4'd10;

  // Registers
  reg [3:0] state, next_state;

  // Common BFS registers
  reg  [2:0] src_idx;          // current BFS source index
  reg  [2:0] node_idx;         // node index iterator
  reg  [2:0] nb_idx;           // neighbor index iterator
  reg        using_A;          // 1 if operating on graph A, 0 for B

  // Distances and control
  reg  [3:0] dist   [0:7];     // BFS distances (4-bit per node)
  reg        visited[0:7];
  reg  [7:0] q_mem;            // simple linear queue storing node indices (3 bits needed)
  reg  [3:0] q_head, q_tail;   // queue pointers (0-8)
  reg        bfs_active;       // indicates BFS still running
  reg        bfs_init_phase;   // to separate init from run inside state

  // Partial sums
  reg [10:0] ssa      [0:7];   // SSA for each node in A (max 392)
  reg [10:0] ssb      [0:7];   // SSA for each node in B
  reg [10:0] ssa_min;
  reg [2:0]  ssa_min_idx;
  reg [10:0] ssb_min;
  reg [2:0]  ssb_min_idx;

  // Original cost sums (sum of squared distances over all ordered pairs)
  // Size: at most 8 nodes, max dist 7, so 8*7*7*8 ~= 3136 < 2^12; but use extra bits.
  reg [15:0] original_cost_A;
  reg [15:0] original_cost_B;

  // Current BFS accumulation
  reg [10:0] cur_ss_sum;       // sum of squared distances for current source

  // Latched sizes
  reg [2:0] size_A_r, size_B_r;

  // Helper wires
  wire [5:0] idx_A = {node_idx, nb_idx}; // 3+3 =6 bits
  wire [5:0] idx_B = {node_idx, nb_idx};

  // Functions
  function automatic [3:0] sq;
    input [3:0] v;
    begin
      sq = v * v;
    end
  endfunction

  // Synchronous state and registers
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      min_cost        <= 16'd0;
      done            <= 1'b0;
      size_A_r        <= 3'd0;
      size_B_r        <= 3'd0;
      src_idx         <= 3'd0;
      node_idx        <= 3'd0;
      nb_idx          <= 3'd0;
      q_mem           <= 8'd0;
      q_head          <= 4'd0;
      q_tail          <= 4'd0;
      bfs_active      <= 1'b0;
      bfs_init_phase  <= 1'b0;
      using_A         <= 1'b1;
      cur_ss_sum      <= 11'd0;
      original_cost_A <= 16'd0;
      original_cost_B <= 16'd0;
      ssa_min         <= 11'h7ff;
      ssb_min         <= 11'h7ff;
      ssa_min_idx     <= 3'd0;
      ssb_min_idx     <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        dist[i]    <= 4'd0;
        visited[i] <= 1'b0;
        ssa[i]     <= 11'd0;
        ssb[i]     <= 11'd0;
      end
    end else begin
      state <= next_state;

      // Default strobes
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            size_A_r        <= size_A;
            size_B_r        <= size_B;
            original_cost_A <= 16'd0;
            original_cost_B <= 16'd0;
            for (i = 0; i < 8; i = i + 1) begin
              ssa[i] <= 11'd0;
              ssb[i] <= 11'd0;
            end
            ssa_min     <= 11'h7ff;
            ssb_min     <= 11'h7ff;
            ssa_min_idx <= 3'd0;
            ssb_min_idx <= 3'd0;
          end
        end

        // Initialize BFS for all sources in A
        INIT_BFS_A: begin
          using_A        <= 1'b1;
          bfs_init_phase <= 1'b1;
          bfs_active     <= 1'b1;
          // Initialize distances and visited
          for (i = 0; i < 8; i = i + 1) begin
            if (i == src_idx)
              dist[i] <= 4'd0;
            else
              dist[i] <= 4'd15; // INF
            visited[i] <= (i == src_idx);
          end
          // Queue with src
          q_mem[2:0] <= src_idx;
          q_head     <= 4'd0;
          q_tail     <= 4'd1;
          cur_ss_sum <= 11'd0;
          node_idx   <= 3'd0;
          nb_idx     <= 3'd0;
        end

        // BFS for current src in A or B
        BFS_A, BFS_B: begin
          if (bfs_active) begin
            // If queue not empty: process front node
            if (q_head < q_tail) begin
              // Load current node
              node_idx <= q_mem[ (q_head[2:0]) ];
              // Iterate neighbors over subsequent cycles via nb_idx

              // Neighbor exploration: one neighbor per cycle
              if (nb_idx < 3'd7) begin
                nb_idx <= nb_idx + 3'd1;
              end else begin
                nb_idx <= 3'd0;
                q_head <= q_head + 4'd1; // move to next queued node in next cycles
              end

              // Determine current node and neighbor
              // Using blocking-style temporaries to compute index
              // For synthesis safety, we rely on registered node_idx and nb_idx from prior cycle.

              begin : BFS_BODY
                reg [2:0] u;
                reg [2:0] v;
                reg [5:0] idx;
                reg       edge;
                reg [3:0] new_dist;
                u = node_idx;
                v = nb_idx;
                idx = {u, v};
                if (using_A)
                  edge = adj_A[idx];
                else
                  edge = adj_B[idx];

                if (edge && (u < (using_A ? size_A_r : size_B_r)) && (v < (using_A ? size_A_r : size_B_r))) begin
                  if (!visited[v]) begin
                    visited[v] <= 1'b1;
                    new_dist   = dist[u] + 4'd1;
                    dist[v]    <= new_dist;
                    // enqueue v
                    q_mem[ q_tail[2:0] ] <= v;
                    q_tail <= q_tail + 4'd1;
                  end
                end
              end

            end else begin
              // Queue empty: BFS done for this source
              bfs_active <= 1'b0;
              // Accumulate SSA for this source and original cost contribution
              cur_ss_sum <= 11'd0;
              node_idx   <= 3'd0;
            end

            // When BFS just finished (queue empty and we turned off active), next cycles will sum
          end else begin
            // Sum squared distances over all nodes for this source
            if (node_idx < (using_A ? size_A_r : size_B_r)) begin
              if (dist[node_idx] != 4'd15 && dist[node_idx] != 4'd0) begin
                cur_ss_sum <= cur_ss_sum + sq(dist[node_idx]);
                if (using_A)
                  original_cost_A <= original_cost_A + sq(dist[node_idx]);
                else
                  original_cost_B <= original_cost_B + sq(dist[node_idx]);
              end
              node_idx <= node_idx + 3'd1;
            end else begin
              // Store SSA/SSB for this source
              if (using_A)
                ssa[src_idx] <= cur_ss_sum;
              else
                ssb[src_idx] <= cur_ss_sum;
            end
          end
        end

        // After BFS_A state, we increment src for A in NEXT_SRC_A
        NEXT_SRC_A: begin
          if (src_idx + 3'd1 < size_A_r) begin
            src_idx <= src_idx + 3'd1;
          end
        end

        // After BFS_B state, we increment src for B in NEXT_SRC_B
        NEXT_SRC_B: begin
          if (src_idx + 3'd1 < size_B_r) begin
            src_idx <= src_idx + 3'd1;
          end
        end

        // Find minimum SSA among valid nodes in A
        FIND_MIN_SSA: begin
          for (i = 0; i < 8; i = i + 1) begin
            if (i < size_A_r) begin
              if (ssa[i] < ssa_min) begin
                ssa_min     <= ssa[i];
                ssa_min_idx <= i[2:0];
              end
            end
          end
        end

        // Find minimum SSB among valid nodes in B
        FIND_MIN_SSB: begin
          for (i = 0; i < 8; i = i + 1) begin
            if (i < size_B_r) begin
              if (ssb[i] < ssb_min) begin
                ssb_min     <= ssb[i];
                ssb_min_idx <= i[2:0];
              end
            end
          end
        end

        // Calculate final minimal cost based on technical note:
        // min_cost = original_cost_A + original_cost_B + |A|*|B| + ssa_min*|B| + ssb_min*|A|
        CALC_COST: begin
          // Use wider temporaries to prevent overflow; final truncated to 16 bits
          reg [15:0] term_A;
          reg [15:0] term_B;
          reg [15:0] term_AB;
          term_A  = ssa_min * size_B_r;
          term_B  = ssb_min * size_A_r;
          term_AB = size_A_r * size_B_r;
          min_cost <= original_cost_A + original_cost_B + term_AB + term_A + term_B;
        end

        DONE_ST: begin
          done <= 1'b1;
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
      IDLE: begin
        if (start)
          next_state = (size_A != 0) ? INIT_BFS_A : INIT_BFS_B;
      end

      INIT_BFS_A: begin
        next_state = BFS_A;
      end

      BFS_A: begin
        if (!bfs_active && (node_idx >= size_A_r)) begin
          // Finished BFS and summation for this src
          if (src_idx + 3'd1 < size_A_r)
            next_state = NEXT_SRC_A;
          else
            next_state = INIT_BFS_B;
        end else begin
          next_state = BFS_A;
        end
      end

      NEXT_SRC_A: begin
        next_state = INIT_BFS_A;
      end

      INIT_BFS_B: begin
        using_A    = 1'b0;
        src_idx    = 3'd0;
        next_state = (size_B_r != 0) ? BFS_B : FIND_MIN_SSA;
      end

      BFS_B: begin
        if (!bfs_active && (node_idx >= size_B_r)) begin
          if (src_idx + 3'd1 < size_B_r)
            next_state = NEXT_SRC_B;
          else
            next_state = FIND_MIN_SSA;
        end else begin
          next_state = BFS_B;
        end
      end

      NEXT_SRC_B: begin
        next_state = INIT_BFS_B;
      end

      FIND_MIN_SSA: begin
        next_state = FIND_MIN_SSB;
      end

      FIND_MIN_SSB: begin
        next_state = CALC_COST;
      end

      CALC_COST: begin
        next_state = DONE_ST;
      end

      DONE_ST: begin
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule