module min_cost_max_flow(
  input clk,
  input rst_n,
  input start,
  input [1:0] node_cnt,
  input [2:0] edge_cnt,
  input [1:0] src,
  input [1:0] sink,
  input [15:0] u_in,
  input [15:0] v_in,
  input [15:0] c_in,
  input [15:0] w_in,
  output reg [15:0] max_flow,
  output reg [31:0] min_cost,
  output reg done,
  output reg busy
);

  // Parameters
  localparam MAX_EDGES      = 8;
  localparam MAX_NODES      = 4;
  localparam INF16          = 16'h7FFF;
  localparam INF32          = 32'h7FFFFFFF;
  localparam STATE_IDLE     = 3'd0;
  localparam STATE_LOAD     = 3'd1;
  localparam STATE_INIT     = 3'd2;
  localparam STATE_BF_DIST  = 3'd3;
  localparam STATE_CHECK    = 3'd4;
  localparam STATE_AUGMENT  = 3'd5;
  localparam STATE_FINISH   = 3'd6;

  // Edge storage (original edges as forward residual edges)
  reg [1:0]  u_mem   [0:MAX_EDGES-1];
  reg [1:0]  v_mem   [0:MAX_EDGES-1];
  reg [15:0] cap_mem [0:MAX_EDGES-1];
  reg [15:0] cost_mem[0:MAX_EDGES-1];

  // Residual capacity for these edges and implicit reverse edges
  reg [15:0] fwd_res_cap [0:MAX_EDGES-1]; // residual capacity u->v
  reg [15:0] rev_res_cap [0:MAX_EDGES-1]; // residual capacity v->u

  // For Bellman-Ford
  reg [31:0] dist [0:MAX_NODES-1];
  reg [1:0]  parent_node [0:MAX_NODES-1];
  reg [3:0]  parent_eidx [0:MAX_NODES-1]; // edge index used in path
  reg        parent_is_rev[0:MAX_NODES-1]; // 0=fwd edge, 1=rev edge

  // State and control
  reg [2:0] state, next_state;
  reg [2:0] load_idx;
  reg [2:0] iter_cnt;        // Bellman-Ford iterations (0..node_cnt-1)
  reg [3:0] relax_edge_idx;  // edge index for relaxation
  reg       updated;         // whether any dist updated in an iteration
  reg [15:0] path_flow;      // bottleneck on found path

  // Internal signals
  wire src_eq_sink = (src == sink);

  integer i;

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= STATE_IDLE;
      max_flow   <= 16'd0;
      min_cost   <= 32'd0;
      done       <= 1'b0;
      busy       <= 1'b0;
      load_idx   <= 3'd0;
      iter_cnt   <= 3'd0;
      relax_edge_idx <= 4'd0;
      path_flow  <= 16'd0;
      for (i=0; i<MAX_EDGES; i=i+1) begin
        u_mem[i]        <= 2'd0;
        v_mem[i]        <= 2'd0;
        cap_mem[i]      <= 16'd0;
        cost_mem[i]     <= 16'd0;
        fwd_res_cap[i]  <= 16'd0;
        rev_res_cap[i]  <= 16'd0;
      end
      for (i=0; i<MAX_NODES; i=i+1) begin
        dist[i]         <= INF32;
        parent_node[i]  <= 2'd0;
        parent_eidx[i]  <= 4'd0;
        parent_is_rev[i]<= 1'b0;
      end
      updated <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        STATE_IDLE: begin
          done <= 1'b0;
          if (start) begin
            busy     <= 1'b1;
            load_idx <= 3'd0;
            // clear memories for safety
            for (i=0; i<MAX_EDGES; i=i+1) begin
              u_mem[i]        <= 2'd0;
              v_mem[i]        <= 2'd0;
              cap_mem[i]      <= 16'd0;
              cost_mem[i]     <= 16'd0;
              fwd_res_cap[i]  <= 16'd0;
              rev_res_cap[i]  <= 16'd0;
            end
          end
        end

        STATE_LOAD: begin
          // Load edges for edge_cnt cycles
          if (load_idx < edge_cnt) begin
            u_mem[load_idx]       <= u_in[1:0];
            v_mem[load_idx]       <= v_in[1:0];
            cap_mem[load_idx]     <= c_in;
            cost_mem[load_idx]    <= w_in;
            fwd_res_cap[load_idx] <= c_in;  // initial residual = capacity
            rev_res_cap[load_idx] <= 16'd0; // no reverse capacity initially
            load_idx              <= load_idx + 3'd1;
          end
        end

        STATE_INIT: begin
          // Initialize for new augmenting path search
          // If src == sink, outputs will be forced to 0 in FINISH
          for (i=0; i<MAX_NODES; i=i+1) begin
            dist[i]         <= INF32;
            parent_node[i]  <= 2'd0;
            parent_eidx[i]  <= 4'd0;
            parent_is_rev[i]<= 1'b0;
          end
          if (!src_eq_sink) begin
            dist[src] <= 32'd0;
          end
          iter_cnt        <= 3'd0;
          relax_edge_idx  <= 4'd0;
          updated         <= 1'b0;
        end

        STATE_BF_DIST: begin
          // Bellman-Ford relaxation: one edge per cycle
          // Relax forward edges (u->v) if residual capacity > 0
          // and reverse edges (v->u) if residual capacity > 0 with negative cost
          if (relax_edge_idx < edge_cnt) begin
            // forward edge
            if (fwd_res_cap[relax_edge_idx] != 16'd0 && dist[u_mem[relax_edge_idx]] != INF32) begin
              if (dist[u_mem[relax_edge_idx]] + cost_mem[relax_edge_idx] < dist[v_mem[relax_edge_idx]]) begin
                dist[v_mem[relax_edge_idx]]        <= dist[u_mem[relax_edge_idx]] + cost_mem[relax_edge_idx];
                parent_node[v_mem[relax_edge_idx]] <= u_mem[relax_edge_idx];
                parent_eidx[v_mem[relax_edge_idx]] <= relax_edge_idx[3:0];
                parent_is_rev[v_mem[relax_edge_idx]] <= 1'b0;
                updated <= 1'b1;
              end
            end
            // reverse edge (v->u) with cost = -w
            if (rev_res_cap[relax_edge_idx] != 16'd0 && dist[v_mem[relax_edge_idx]] != INF32) begin
              if (dist[v_mem[relax_edge_idx]] - cost_mem[relax_edge_idx] < dist[u_mem[relax_edge_idx]]) begin
                dist[u_mem[relax_edge_idx]]        <= dist[v_mem[relax_edge_idx]] - cost_mem[relax_edge_idx];
                parent_node[u_mem[relax_edge_idx]] <= v_mem[relax_edge_idx];
                parent_eidx[u_mem[relax_edge_idx]] <= relax_edge_idx[3:0];
                parent_is_rev[u_mem[relax_edge_idx]] <= 1'b1;
                updated <= 1'b1;
              end
            end
            relax_edge_idx <= relax_edge_idx + 4'd1;
          end else begin
            // End of one full relaxation pass over all edges
            relax_edge_idx <= 4'd0;
            iter_cnt <= iter_cnt + 3'd1;
            // updated flag will be checked in STATE_CHECK
          end
        end

        STATE_CHECK: begin
          // Nothing updated here; next_state decides
        end

        STATE_AUGMENT: begin
          // Using parent arrays, find path_flow and update residual capacities
          // Step 1: compute bottleneck
          // We'll walk back in a simple sequential manner in this state
          // Implementation: one pass to find bottleneck, second to apply
          // For simplicity and determinism, do both in one combinational-like
          // but registered approach across cycles by using an internal loop.
          // Here we'll implement as if done in one cycle (small graph, ASIC):
          reg [1:0] cur;
          reg [15:0] bneck;
          reg [3:0] eidx;
          reg       is_rev;
          bneck = 16'hFFFF;
          cur   = sink;
          if (dist[sink] == INF32 || src_eq_sink) begin
            // No path or trivial case should not be here; handled in CHECK
            path_flow <= 16'd0;
          end else begin
            // Find bottleneck
            while (cur != src) begin
              eidx  = parent_eidx[cur];
              is_rev= parent_is_rev[cur];
              if (!is_rev) begin
                if (fwd_res_cap[eidx] < bneck)
                  bneck = fwd_res_cap[eidx];
                cur = parent_node[cur];
              end else begin
                if (rev_res_cap[eidx] < bneck)
                  bneck = rev_res_cap[eidx];
                cur = parent_node[cur];
              end
            end
            path_flow <= bneck;

            // Apply augmentation
            cur = sink;
            while (cur != src) begin
              eidx  = parent_eidx[cur];
              is_rev= parent_is_rev[cur];
              if (!is_rev) begin
                // forward edge u->v
                fwd_res_cap[eidx] <= fwd_res_cap[eidx] - bneck;
                rev_res_cap[eidx] <= rev_res_cap[eidx] + bneck;
                // cost += bneck * w
                min_cost <= min_cost + ({{16{1'b0}}, bneck} * cost_mem[eidx]);
                cur = parent_node[cur];
              end else begin
                // reverse edge v->u (reducing previous flow)
                rev_res_cap[eidx] <= rev_res_cap[eidx] - bneck;
                fwd_res_cap[eidx] <= fwd_res_cap[eidx] + bneck;
                // cost -= bneck * w
                min_cost <= min_cost - ({{16{1'b0}}, bneck} * cost_mem[eidx]);
                cur = parent_node[cur];
              end
            end
            // update total flow
            max_flow <= max_flow + bneck;
          end
        end

        STATE_FINISH: begin
          done <= 1'b1;
          busy <= 1'b0;
          // If src==sink, override to (0,0)
          if (src_eq_sink) begin
            max_flow <= 16'd0;
            min_cost <= 32'd0;
          end
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
      STATE_IDLE: begin
        if (start)
          next_state = (edge_cnt == 0) ? STATE_FINISH : STATE_LOAD;
      end

      STATE_LOAD: begin
        if (load_idx >= edge_cnt)
          next_state = STATE_INIT;
      end

      STATE_INIT: begin
        if (src_eq_sink) begin
          next_state = STATE_FINISH;
        end else begin
          next_state = STATE_BF_DIST;
        end
      end

      STATE_BF_DIST: begin
        // When a full pass over edges completes, we are at end of iteration
        if (relax_edge_idx == 0 && iter_cnt != 0) begin
          // Completed one iteration
          if (iter_cnt >= node_cnt - 1) begin
            // Completed all required iterations
            next_state = STATE_CHECK;
          end else begin
            // Prepare next iteration: updated flag kept, but we continue
            next_state = STATE_BF_DIST;
          end
        end
      end

      STATE_CHECK: begin
        // If no path to sink or distance is INF, we're done
        if (dist[sink] == INF32 || src_eq_sink) begin
          next_state = STATE_FINISH;
        end else begin
          // We have shortest path, augment
          next_state = STATE_AUGMENT;
        end
      end

      STATE_AUGMENT: begin
        // After applying one augmentation, start another BF for next path
        next_state = STATE_INIT;
      end

      STATE_FINISH: begin
        // Stay in finish until next start (handled via reset or external logic)
        if (!start)
          next_state = STATE_IDLE;
      end

      default: begin
        next_state = STATE_IDLE;
      end
    endcase
  end

endmodule