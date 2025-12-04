module min_cost_max_flow(
  input clk,            // Clock
  input rst_n,          // Active-low reset
  input start,          // Start computation
  input [1:0] node_cnt, // Number of nodes (2-4)
  input [1:0] edge_cnt, // Number of edges (0-8)
  input [1:0] src,      // Source node (0-3)
  input [1:0] sink,     // Sink node (0-3)
  input [15:0] u_in,    // Edge source node (2 bits used)
  input [15:0] v_in,    // Edge destination node (2 bits used)
  input [15:0] c_in,    // Edge capacity (1-10000)
  input [15:0] w_in,    // Edge cost (1-1000)
  output reg [15:0] max_flow,  // Maximum flow F
  output reg [31:0] min_cost,  // Minimum cost
  output reg done,      // Computation complete
  output reg busy       // Module processing data
);
  // Parameters
  localparam NODE_W = 2;
  localparam CAP_W  = 16;
  localparam COST_W = 16;
  localparam MAX_NODES = 4;
  localparam MAX_EDGES = 8;
  localparam INF32 = 32'h3fffffff; // large positive for 32-bit signed

  // Edge storage (forward edges only)
  reg [MAX_EDGES-1:0] e_valid;
  reg [NODE_W-1:0]    e_u [0:MAX_EDGES-1];
  reg [NODE_W-1:0]    e_v [0:MAX_EDGES-1];
  reg [CAP_W-1:0]     e_cap [0:MAX_EDGES-1];
  reg [COST_W-1:0]    e_cost [0:MAX_EDGES-1];
  // Reverse edge indices and flow tracking for all edges (forward + reverse)
  reg [NODE_W-1:0]    rev_idx [0:2*MAX_EDGES-1]; // For index i, rev index stored here
  reg [CAP_W-1:0]     edge_flow [0:2*MAX_EDGES-1]; // current flow on each directed edge
  reg [CAP_W-1:0]     edge_cap [0:2*MAX_EDGES-1];  // capacity for each directed edge
  reg [COST_W-1:0]    edge_cost [0:2*MAX_EDGES-1]; // cost for each directed edge

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE = 3'b000,
    S_LOAD = 3'b001,
    S_COMPUTE = 3'b010,
    S_DONE = 3'b111
  } state_t;
  state_t state, next_state;

  // Edge load counter
  reg [3:0] load_cnt;        // counts 0..7 (sufficient for up to 8 edges)
  reg [15:0] edge_cnt_reg;
  reg [1:0] node_cnt_reg;
  reg [1:0] src_reg, sink_reg;

  // Bellman-Ford working variables (32-bit signed distances)
  reg [31:0] dist [0:MAX_NODES-1];     // distance from src
  reg [31:0] dist_next [0:MAX_NODES-1];
  reg [15:0] dist_cap [0:MAX_NODES-1]; // bottleneck along best path
  reg [15:0] dist_cap_next [0:MAX_NODES-1];
  reg [7:0]  prev_edge [0:MAX_NODES-1]; // edge index (0..2*MAX_EDGES-1) to reach node
  reg [7:0]  prev_edge_next [0:MAX_NODES-1];
  reg [7:0]  bf_iter;        // 0..3 (relax 0..3 times)
  reg [7:0]  relax_idx;      // 0..15 (max 16 directed edges)
  reg [15:0] aug_bottleneck; // bottleneck found in this augmentation
  reg [31:0] aug_cost;       // total path cost for this augmentation
  reg [31:0] total_cost;     // accumulated min cost
  reg [15:0] total_flow;     // accumulated max flow

  // Helper: check if we have reached the sink in current dist
  reg reached_sink;

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      busy <= 1'b0;
      max_flow <= 16'h0;
      min_cost <= 32'h0;
      load_cnt <= 4'd0;
      edge_cnt_reg <= 16'h0;
      node_cnt_reg <= 2'd0;
      src_reg <= 2'd0;
      sink_reg <= 2'd0;
      // Clear edge memory
      e_valid <= 8'h00;
      for (int i=0;i<MAX_EDGES;i++) begin
        e_u[i]    <= 2'd0;
        e_v[i]    <= 2'd0;
        e_cap[i]  <= 16'd0;
        e_cost[i] <= 16'd0;
      end
      for (int i=0;i<2*MAX_EDGES;i++) begin
        rev_idx[i]     <= 2'd0;
        edge_flow[i]   <= 16'd0;
        edge_cap[i]    <= 16'd0;
        edge_cost[i]   <= 16'd0;
      end
      // Clear BF state
      for (int n=0;n<MAX_NODES;n++) begin
        dist[n]       <= INF32;
        dist_next[n]  <= INF32;
        dist_cap[n]   <= 16'd0;
        dist_cap_next[n] <= 16'd0;
        prev_edge[n]  <= 8'd0;
        prev_edge_next[n] <= 8'd0;
      end
      bf_iter    <= 8'd0;
      relax_idx  <= 8'd0;
      aug_bottleneck <= 16'd0;
      aug_cost   <= 32'd0;
      reached_sink <= 1'b0;
      total_flow <= 16'd0;
      total_cost <= 32'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          busy <= 1'b0;
          // On idle, hold everything cleared
        end

        S_LOAD: begin
          busy <= 1'b1;
          done <= 1'b0;
          if (load_cnt < edge_cnt_reg) begin
            // Store forward edge
            e_valid[load_cnt] <= 1'b1;
            e_u[load_cnt]     <= u_in[1:0];
            e_v[load_cnt]     <= v_in[1:0];
            e_cap[load_cnt]   <= c_in;
            e_cost[load_cnt]  <= w_in;
            load_cnt <= load_cnt + 1;
          end else begin
            // Move to compute, initialize residual network
            // Build reverse edge mappings and residual capacities
            for (int i=0;i<2*MAX_EDGES;i++) begin
              edge_flow[i]  <= 16'd0;
              edge_cap[i]   <= 16'd0;
              edge_cost[i]  <= 16'd0;
              rev_idx[i]    <= 2'd0;
            end
            for (int i=0;i<edge_cnt_reg; i++) begin
              if (e_valid[i]) begin
                // forward edge index = 2*i
                edge_cap[2*i]   <= e_cap[i];
                edge_cost[2*i]  <= e_cost[i];
                // reverse edge index = 2*i+1
                edge_cap[2*i+1] <= 16'd0;
                edge_cost[2*i+1] <= (~e_cost[i] + 1); // negative cost for reverse
                rev_idx[2*i]   <= 2'(i) + 1;  // index of reverse edge
                rev_idx[2*i+1] <= 2'(i);      // index of forward edge
              end
            end
            // Initialize BF state
            for (int n=0;n<MAX_NODES;n++) begin
              dist[n]      <= INF32;
              dist_next[n] <= INF32;
              dist_cap[n]  <= 16'd0;
              dist_cap_next[n] <= 16'd0;
              prev_edge[n] <= 8'd0;
              prev_edge_next[n] <= 8'd0;
            end
            dist[src_reg] <= 32'd0;
            dist_cap[src_reg] <= 16'hFFFF; // will be reduced by min() later; for source it's fine
            bf_iter   <= 8'd0;
            relax_idx <= 8'd0;
            reached_sink <= 1'b0;
            aug_bottleneck <= 16'd0;
            aug_cost   <= 32'd0;
            total_flow <= 16'd0;
            total_cost <= 32'd0;
          end
        end

        S_COMPUTE: begin
          busy <= 1'b1;
          done <= 1'b0;
          // If src == sink, early finish with (0,0)
          if (src_reg == sink_reg) begin
            max_flow <= 16'd0;
            min_cost <= 32'd0;
            next_state <= S_DONE;
          end else begin
            // Bellman-Ford iterations for this augmentation
            if (bf_iter < node_cnt_reg) begin // up to 3 iterations for 4 nodes
              if (relax_idx < (edge_cnt_reg * 2)) begin
                // Process each directed edge idx
                // Edge i is the edge to relax from: from node = u(i), to node = v(i)
                // But we need to know endpoints for each directed edge.
                // For forward edges (even index), u = e_u[i/2], v = e_v[i/2]
                // For reverse edges (odd index), u = e_v[i/2], v = e_u[i/2]
                int eidx;
                logic [NODE_W-1:0] from_node, to_node;
                logic [COST_W-1:0] dir_cost;
                logic [15:0] from_cap;
                eidx = relax_idx;
                if (eidx[0] == 1'b0) begin // forward edge
                  from_node = e_u[eidx>>1];
                  to_node   = e_v[eidx>>1];
                  dir_cost  = edge_cost[eidx];
                  from_cap  = edge_cap[eidx];
                end else begin // reverse edge
                  from_node = e_v[eidx>>1];
                  to_node   = e_u[eidx>>1];
                  dir_cost  = edge_cost[eidx];
                  from_cap  = edge_cap[eidx];
                end
                // Try relaxation if from_node has finite distance and edge has capacity
                if ((dist[from_node] != INF32) && (from_cap != 16'd0)) begin
                  logic [31:0] ndist;
                  logic [15:0] ncap;
                  logic [31:0] sum;
                  sum = dist[from_node] + $signed({1'b0, dir_cost});
                  if (sum < dist_next[to_node]) begin
                    ndist = sum;
                    // bottleneck = min(dist_cap[from_node], from_cap)
                    ncap = dist_cap[from_node] < from_cap ? dist_cap[from_node] : from_cap;
                    dist_next[to_node] <= ndist;
                    dist_cap_next[to_node] <= ncap;
                    prev_edge_next[to_node] <= eidx[7:0];
                    if (to_node == sink_reg) begin
                      reached_sink <= 1'b1;
                    end
                  end
                end
                relax_idx <= relax_idx + 1;
              end else begin
                // Move to next iteration: copy next to current, clear next, increment iter
                for (int n=0;n<MAX_NODES;n++) begin
                  dist[n]      <= dist_next[n];
                  dist_cap[n]  <= dist_cap_next[n];
                  prev_edge[n] <= prev_edge_next[n];
                end
                // Clear next arrays
                for (int n=0;n<MAX_NODES;n++) begin
                  dist_next[n]     <= INF32;
                  dist_cap_next[n] <= 16'd0;
                  prev_edge_next[n]<= 8'd0;
                end
                relax_idx <= 8'd0;
                bf_iter   <= bf_iter + 1;
              end
            end else begin
              // All iterations done: check if augmenting path exists
              if (dist[sink_reg] != INF32) begin
                // Reconstruct path to get aug_cost and aug_bottleneck
                logic [31:0] path_cost;
                logic [15:0] bottleneck;
                logic [7:0] ewalk;
                logic [NODE_W-1:0] curnode;
                path_cost = 32'd0;
                bottleneck = 16'hFFFF;
                curnode = sink_reg;
                ewalk = prev_edge[curnode];
                while (ewalk != 8'd0) begin
                  // accumulate cost
                  path_cost = path_cost + $signed({1'b0, edge_cost[ewalk]});
                  // bottleneck = min(bottleneck, edge_cap[ewalk])
                  if (edge_cap[ewalk] < bottleneck) bottleneck = edge_cap[ewalk];
                  // move to previous node
                  if (ewalk[0] == 1'b0) begin // came via forward edge (u->v)
                    curnode = e_u[ewalk>>1];
                  end else begin               // came via reverse edge (v->u)
                    curnode = e_v[ewalk>>1];
                  end
                  ewalk = (curnode == src_reg) ? 8'd0 : prev_edge[curnode];
                end
                aug_bottleneck <= bottleneck;
                aug_cost <= path_cost;
                // Apply augmentation
                // Walk again to update flows/caps
                curnode = sink_reg;
                ewalk = prev_edge[curnode];
                while (ewalk != 8'd0) begin
                  if (edge_cap[ewalk] >= bottleneck) begin
                    edge_cap[ewalk]  <= edge_cap[ewalk] - bottleneck;
                    edge_flow[ewalk] <= edge_flow[ewalk] + bottleneck;
                  end
                  // Update reverse edge index
                  rev_idx[ewalk] <= rev_idx[ewalk]; // no change
                  // reverse edge index
                  if (ewalk[0] == 1'b0) begin
                    // reverse of forward is odd
                    edge_cap[ewalk+1]  <= edge_cap[ewalk+1] + bottleneck;
                    edge_flow[ewalk+1] <= edge_flow[ewalk+1] - bottleneck; // will be <= 0
                  end else begin
                    // reverse of reverse is even
                    edge_cap[ewalk-1]  <= edge_cap[ewalk-1] + bottleneck;
                    edge_flow[ewalk-1] <= edge_flow[ewalk-1] - bottleneck; // will be <= 0
                  end
                  // Move backward in path
                  if (ewalk[0] == 1'b0) begin
                    curnode = e_u[ewalk>>1];
                  end else begin
                    curnode = e_v[ewalk>>1];
                  end
                  ewalk = (curnode == src_reg) ? 8'd0 : prev_edge[curnode];
                end
                // Update totals
                total_flow <= total_flow + bottleneck;
                // Accumulate cost: path_cost can be negative (due to reverse edges), keep signed
                total_cost <= total_cost + path_cost;
                // Prepare for next augmentation: reset BF state
                for (int n=0;n<MAX_NODES;n++) begin
                  dist[n]      <= INF32;
                  dist_next[n] <= INF32;
                  dist_cap[n]  <= 16'd0;
                  dist_cap_next[n] <= 16'd0;
                  prev_edge[n] <= 8'd0;
                  prev_edge_next[n] <= 8'd0;
                end
                dist[src_reg] <= 32'd0;
                dist_cap[src_reg] <= 16'hFFFF;
                bf_iter    <= 8'd0;
                relax_idx  <= 8'd0;
                reached_sink <= 1'b0;
              end else begin
                // No augmenting path: done
                max_flow <= total_flow;
                min_cost <= total_cost;
                next_state <= S_DONE;
              end
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          busy <= 1'b0;
        end

        default: begin
          // stay idle on unexpected
          state <= S_IDLE;
        end
      endcase
    end
  end

  // Next-state logic
  always_comb begin
    case (state)
      S_IDLE: begin
        if (start) next_state = S_LOAD;
        else next_state = S_IDLE;
      end
      S_LOAD: begin
        if (load_cnt >= edge_cnt_reg) next_state = S_COMPUTE;
        else next_state = S_LOAD;
      end
      S_COMPUTE: begin
        // If src==sink, we finish in S_COMPUTE block
        if (src_reg == sink_reg) next_state = S_DONE;
        else if (dist[sink_reg] == INF32) next_state = S_DONE;
        else next_state = S_COMPUTE;
      end
      S_DONE: begin
        if (start) next_state = S_LOAD; // allow re-start after done
        else next_state = S_DONE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Register inputs when entering LOAD to keep them stable
  always @(posedge clk) begin
    if (state == S_IDLE && start) begin
      edge_cnt_reg <= edge_cnt;
      node_cnt_reg <= node_cnt;
      src_reg <= src;
      sink_reg <= sink;
      load_cnt <= 4'd0;
    end
  end

endmodule
