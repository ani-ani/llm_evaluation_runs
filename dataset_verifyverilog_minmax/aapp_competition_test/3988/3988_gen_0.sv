module graph_reachability_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] start_node,
  input [2:0] graph_nodes [0:15][0:2],
  input [3:0] edge_count,
  output reg [3:0] max_reachable,
  output reg [3:0] min_reachable,
  output reg [15:0] max_orient,
  output reg [15:0] min_orient,
  output reg done
);

  // States
  localparam ST_IDLE       = 2'd0;
  localparam ST_PROCESS_MAX= 2'd1;
  localparam ST_PROCESS_MIN= 2'd2;
  localparam ST_DONE       = 2'd3;

  // BFS queues and visited sets
  reg [2:0] max_queue [0:7];
  reg [2:0] min_queue [0:7];
  reg [2:0] max_q_head, max_q_tail, max_q_len;
  reg [2:0] min_q_head, min_q_tail, min_q_len;
  reg [7:0] max_visited, min_visited;
  reg [7:0] max_vis_snapshot, min_vis_snapshot;

  // Internal control/state
  reg [1:0] state, next_state;
  reg [3:0] cycle_cnt;
  reg [3:0] e_idx, e_idx_next;
  reg [3:0] max_reach_cnt, min_reach_cnt;
  reg [15:0] max_orient_next, min_orient_next;
  reg [3:0] max_reach_next, min_reach_next;
  reg [2:0] cur_node_max, cur_node_min;
  reg pop_max, pop_min;
  reg pop_max_d, pop_min_d;

  // Edges (decoded)
  wire [2:0] e_u, e_v;
  wire       e_t_directed;  // 1 if directed (t==1), 0 if undirected (t==2)

  assign e_u         = graph_nodes[e_idx][1];
  assign e_v         = graph_nodes[e_idx][2];
  assign e_t_directed = (graph_nodes[e_idx][0] == 3'd1);

  // State transition
  always @(*) begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (start) next_state = ST_PROCESS_MAX;
      end
      ST_PROCESS_MAX: begin
        if (cycle_cnt == 4'd31 || (e_idx == edge_count && max_q_len == 3'd0))
          next_state = ST_PROCESS_MIN;
      end
      ST_PROCESS_MIN: begin
        if (cycle_cnt == 4'd31 || (e_idx == edge_count && min_q_len == 3'd0))
          next_state = ST_DONE;
      end
      ST_DONE: begin
        next_state = ST_IDLE;
      end
      default: next_state = ST_IDLE;
    endcase
  end

  // Registers update on clock
  always @(posedge clk) begin
    if (!rst_n) begin
      state          <= ST_IDLE;
      cycle_cnt      <= 4'd0;
      e_idx          <= 4'd0;
      max_q_head     <= 3'd0;
      max_q_tail     <= 3'd0;
      max_q_len      <= 3'd0;
      min_q_head     <= 3'd0;
      min_q_tail     <= 3'd0;
      min_q_len      <= 3'd0;
      max_visited    <= 8'd0;
      min_visited    <= 8'd0;
      max_reachable  <= 4'd0;
      min_reachable  <= 4'd0;
      max_orient     <= 16'd0;
      min_orient     <= 16'd0;
      done           <= 1'b0;
    end else begin
      state          <= next_state;
      done           <= (next_state == ST_DONE);
      pop_max_d      <= pop_max;
      pop_min_d      <= pop_min;

      // Cycle counter
      if (state == ST_IDLE)
        cycle_cnt <= 4'd0;
      else if (next_state == ST_PROCESS_MAX || next_state == ST_PROCESS_MIN)
        cycle_cnt <= cycle_cnt + 4'd1;
      else
        cycle_cnt <= cycle_cnt;

      // Default edge index progression
      e_idx_next <= e_idx;
      if (state == ST_IDLE) begin
        e_idx <= 4'd0;
      end else begin
        if (e_idx == edge_count) begin
          if (next_state == ST_PROCESS_MIN || next_state == ST_DONE)
            e_idx <= 4'd0;
          else
            e_idx <= e_idx; // hold at end during max
        end else begin
          e_idx <= e_idx + 4'd1;
        end
      end

      // MAX plan queues/visited/orientation
      if (state == ST_IDLE) begin
        max_q_head <= 3'd0;
        max_q_tail <= 3'd0;
        max_q_len  <= 3'd0;
        max_visited<= 8'd0;
        max_orient <= 16'd0;
        max_reach_cnt <= 4'd0;
        max_reach_next <= 4'd0;
        max_orient_next <= 16'd0;
      end else if (state == ST_PROCESS_MAX) begin
        // Queue management for MAX
        if (pop_max && max_q_len > 3'd0) begin
          max_q_head <= max_q_head + 3'd1;
          max_q_len  <= max_q_len - 3'd1;
        end
        if (!pop_max) begin
          if (max_q_len == 3'd0 && max_visited != 8'hFF) begin
            // Seed with first unvisited node
            if (!max_visited[0]) begin
              max_queue[0] <= 3'd0;
            end else if (!max_visited[1]) begin
              max_queue[0] <= 3'd1;
            end else if (!max_visited[2]) begin
              max_queue[0] <= 3'd2;
            end else if (!max_visited[3]) begin
              max_queue[0] <= 3'd3;
            end else if (!max_visited[4]) begin
              max_queue[0] <= 3'd4;
            end else if (!max_visited[5]) begin
              max_queue[0] <= 3'd5;
            end else if (!max_visited[6]) begin
              max_queue[0] <= 3'd6;
            end else begin
              max_queue[0] <= 3'd7;
            end
            max_q_head <= 3'd0;
            max_q_tail <= 3'd1;
            max_q_len  <= 3'd1;
          end else if (max_q_len < 3'd8) begin
            // Push cur_node_max (already deduped if visited)
            max_queue[max_q_tail] <= cur_node_max;
            max_q_tail <= max_q_tail + 3'd1;
            max_q_len  <= max_q_len + 3'd1;
          end
        end

        // Orientation and visited updates (combinational with pipeline of pop)
        if (pop_max_d) begin
          if (e_t_directed) begin
            if (cur_node_max == e_u) begin
              if (!max_visited[e_v]) begin
                max_visited[e_v] <= 1'b1;
                max_reach_cnt    <= max_reach_cnt + 4'd1;
              end
            end
          end else begin
            // Undirected: orient to maximize (send to neighbor)
            if (cur_node_max == e_u) begin
              if (!max_visited[e_v]) begin
                max_visited[e_v] <= 1'b1;
                max_orient_next  <= (max_orient_next | (16'b1 << e_idx));
                max_reach_cnt    <= max_reach_cnt + 4'd1;
              end
            end else if (cur_node_max == e_v) begin
              if (!max_visited[e_u]) begin
                max_visited[e_u] <= 1'b1;
                max_orient_next  <= (max_orient_next & ~(16'b1 << e_idx));
                max_reach_cnt    <= max_reach_cnt + 4'd1;
              end
            end
          end
        end
      end else if (next_state == ST_PROCESS_MIN) begin
        // Save MAX results when leaving MAX
        max_orient      <= max_orient_next;
        max_reachable   <= max_reach_next;
        e_idx           <= 4'd0; // reset for MIN
      end

      // MIN plan queues/visited/orientation
      if (state == ST_PROCESS_MIN) begin
        // Queue management for MIN
        if (pop_min && min_q_len > 3'd0) begin
          min_q_head <= min_q_head + 3'd1;
          min_q_len  <= min_q_len - 3'd1;
        end
        if (!pop_min) begin
          if (min_q_len == 3'd0 && min_visited != 8'hFF) begin
            if (!min_visited[0]) begin
              min_queue[0] <= 3'd0;
            end else if (!min_visited[1]) begin
              min_queue[0] <= 3'd1;
            end else if (!min_visited[2]) begin
              min_queue[0] <= 3'd2;
            end else if (!min_visited[3]) begin
              min_queue[0] <= 3'd3;
            end else if (!min_visited[4]) begin
              min_queue[0] <= 3'd4;
            end else if (!min_visited[5]) begin
              min_queue[0] <= 3'd5;
            end else if (!min_visited[6]) begin
              min_queue[0] <= 3'd6;
            end else begin
              min_queue[0] <= 3'd7;
            end
            min_q_head <= 3'd0;
            min_q_tail <= 3'd1;
            min_q_len  <= 3'd1;
          end else if (min_q_len < 3'd8) begin
            min_queue[min_q_tail] <= cur_node_min;
            min_q_tail <= min_q_tail + 3'd1;
            min_q_len  <= min_q_len + 3'd1;
          end
        end

        // Orientation and visited updates for MIN
        if (pop_min_d) begin
          if (e_t_directed) begin
            if (cur_node_min == e_u) begin
              if (!min_visited[e_v]) begin
                min_visited[e_v] <= 1'b1;
                min_reach_cnt    <= min_reach_cnt + 4'd1;
              end
            end
          end else begin
            // Undirected: orient to minimize (send to neighbor that leads to fewer new nodes)
            // Gain if u->v: 1 if v unvisited, else 0 (symmetric)
            if (cur_node_min == e_u) begin
              if (!min_visited[e_v]) begin
                min_visited[e_v] <= 1'b1;
                // Choose orientation for MIN: send to the neighbor with smaller immediate gain
                // Gain if v->u would be: 1 if u unvisited, else 0
                // Here both are symmetric; to "minimize" we prefer the opposite of MAX
                min_orient_next  <= (min_orient_next & ~(16'b1 << e_idx));
                min_reach_cnt    <= min_reach_cnt + 4'd1;
              end
            end else if (cur_node_min == e_v) begin
              if (!min_visited[e_u]) begin
                min_visited[e_u] <= 1'b1;
                min_orient_next  <= (min_orient_next | (16'b1 << e_idx));
                min_reach_cnt    <= min_reach_cnt + 4'd1;
              end
            end
          end
        end
      end else if (next_state == ST_DONE) begin
        // Save MIN results when leaving MIN
        min_orient     <= min_orient_next;
        min_reachable  <= min_reach_next;
        e_idx          <= 4'd0;
      end

      // Initialize per-phase
      if (state == ST_IDLE) begin
        min_visited    <= 8'd0;
        min_orient     <= 16'd0;
        min_reach_cnt  <= 4'd0;
        min_reach_next <= 4'd0;
        min_orient_next<= 16'd0;
      end

      // Defaults for next-cycle tracking
      max_reach_next   <= (state == ST_PROCESS_MAX) ? max_reach_cnt : max_reachable;
      min_reach_next   <= (state == ST_PROCESS_MIN) ? min_reach_cnt : min_reachable;
      max_orient_next  <= (state == ST_PROCESS_MAX) ? max_orient_next : max_orient;
      min_orient_next  <= (state == ST_PROCESS_MIN) ? min_orient_next : min_orient;
    end
  end

  // Edge scanning clocking (pipeline to meet timing)
  always @(posedge clk) begin
    if (!rst_n || state == ST_IDLE) begin
      cur_node_max <= 3'd0;
      cur_node_min <= 3'd0;
      pop_max      <= 1'b0;
      pop_min      <= 1'b0;
    end else begin
      // Current node for MAX
      if (state == ST_PROCESS_MAX) begin
        if (max_q_len > 3'd0)
          cur_node_max <= max_queue[max_q_head];
        pop_max <= (max_q_len > 3'd0);
      end else begin
        pop_max <= 1'b0;
      end

      // Current node for MIN
      if (state == ST_PROCESS_MIN) begin
        if (min_q_len > 3'd0)
          cur_node_min <= min_queue[min_q_head];
        pop_min <= (min_q_len > 3'd0);
      end else begin
        pop_min <= 1'b0;
      end
    end
  end

endmodule