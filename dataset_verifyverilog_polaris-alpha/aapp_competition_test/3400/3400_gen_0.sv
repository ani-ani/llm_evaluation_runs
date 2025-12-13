module rabbit_pathfinder(
  input clk,
  input rst_n,
  input start,
  input [1:0] alice_node,
  input [1:0] hole_node,
  input [3:0] trip1_d, input [1:0] trip1_p, input [1:0] trip1_seq [0:3],
  input [3:0] trip2_d, input [1:0] trip2_p, input [1:0] trip2_seq [0:3],
  input [3:0] trip3_d, input [1:0] trip3_p, input [1:0] trip3_seq [0:3],
  output reg [7:0] shortest_time,
  output reg done
);

  // Internal edge weight storage (4x4), 8-bit, 0 means unknown/not used, except diagonal is 0
  reg [7:0] edge_w [0:3][0:3];

  // FSM states (enough to span 20 cycles total)
  typedef enum logic [4:0] {
    S_IDLE      = 5'd0,
    S_INIT      = 5'd1,
    S_TRIP1_0   = 5'd2,
    S_TRIP1_1   = 5'd3,
    S_TRIP1_2   = 5'd4,
    S_TRIP2_0   = 5'd5,
    S_TRIP2_1   = 5'd6,
    S_TRIP2_2   = 5'd7,
    S_TRIP3_0   = 5'd8,
    S_TRIP3_1   = 5'd9,
    S_TRIP3_2   = 5'd10,
    S_BUILD     = 5'd11,
    S_DIJK_0    = 5'd12,
    S_DIJK_1    = 5'd13,
    S_DIJK_2    = 5'd14,
    S_DIJK_3    = 5'd15,
    S_DONE      = 5'd16
  } state_t;

  state_t state, next_state;

  // Dijkstra internal signals
  reg [7:0] dist [0:3];
  reg       visited [0:3];

  reg [1:0] cur_node;
  reg [7:0] cur_dist;

  integer i,j;

  // Combinational helper: compute 8-bit edge time from (d, p)
  // Rule: real_time = (p * 12) + d
  function automatic [7:0] edge_time_from_dp;
    input [3:0] d;
    input [1:0] p;
    reg [7:0] base;
    begin
      base = {6'd0, p} * 8'd12; // p * 12 (p up to 3)
      edge_time_from_dp = base + {4'd0, d};
    end
  endfunction

  // Combinational: pick next node with minimum dist among unvisited
  function automatic [1:0] pick_min_node;
    input [7:0] d0, d1, d2, d3;
    input v0, v1, v2, v3;
    reg [7:0] min_val;
    reg [1:0] min_idx;
    begin
      min_val = 8'hFF;
      min_idx = 2'd0;
      if (!v0 && d0 < min_val) begin min_val = d0; min_idx = 2'd0; end
      if (!v1 && d1 < min_val) begin min_val = d1; min_idx = 2'd1; end
      if (!v2 && d2 < min_val) begin min_val = d2; min_idx = 2'd2; end
      if (!v3 && d3 < min_val) begin min_val = d3; min_idx = 2'd3; end
      pick_min_node = min_idx;
    end
  endfunction

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      shortest_time <= 8'd0;
      // Clear edge weights, dist, visited
      for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          edge_w[i][j] <= (i == j) ? 8'd0 : 8'd0; // 0 as unknown/off-diagonal
        end
        dist[i] <= 8'hFF;
        visited[i] <= 1'b0;
      end
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // prepare to initialize
          end
        end

        S_INIT: begin
          // Clear edge weights and Dijkstra data
          done <= 1'b0;
          for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
              edge_w[i][j] <= (i == j) ? 8'd0 : 8'd0;
            end
            dist[i] <= 8'hFF;
            visited[i] <= 1'b0;
          end
        end

        // Trip 1 processing: 3 edges (0-1,1-2,2-3 in sequence)
        S_TRIP1_0: begin
          if (trip1_p > 0) begin
            // edge between seq[0] and seq[1]
            edge_w[trip1_seq[0]][trip1_seq[1]] <= edge_time_from_dp(trip1_d, trip1_p);
            edge_w[trip1_seq[1]][trip1_seq[0]] <= edge_time_from_dp(trip1_d, trip1_p);
          end
        end
        S_TRIP1_1: begin
          if (trip1_p > 1) begin
            edge_w[trip1_seq[1]][trip1_seq[2]] <= edge_time_from_dp(trip1_d, trip1_p);
            edge_w[trip1_seq[2]][trip1_seq[1]] <= edge_time_from_dp(trip1_d, trip1_p);
          end
        end
        S_TRIP1_2: begin
          if (trip1_p > 2) begin
            edge_w[trip1_seq[2]][trip1_seq[3]] <= edge_time_from_dp(trip1_d, trip1_p);
            edge_w[trip1_seq[3]][trip1_seq[2]] <= edge_time_from_dp(trip1_d, trip1_p);
          end
        end

        // Trip 2 processing
        S_TRIP2_0: begin
          if (trip2_p > 0) begin
            edge_w[trip2_seq[0]][trip2_seq[1]] <= edge_time_from_dp(trip2_d, trip2_p);
            edge_w[trip2_seq[1]][trip2_seq[0]] <= edge_time_from_dp(trip2_d, trip2_p);
          end
        end
        S_TRIP2_1: begin
          if (trip2_p > 1) begin
            edge_w[trip2_seq[1]][trip2_seq[2]] <= edge_time_from_dp(trip2_d, trip2_p);
            edge_w[trip2_seq[2]][trip2_seq[1]] <= edge_time_from_dp(trip2_d, trip2_p);
          end
        end
        S_TRIP2_2: begin
          if (trip2_p > 2) begin
            edge_w[trip2_seq[2]][trip2_seq[3]] <= edge_time_from_dp(trip2_d, trip2_p);
            edge_w[trip2_seq[3]][trip2_seq[2]] <= edge_time_from_dp(trip2_d, trip2_p);
          end
        end

        // Trip 3 processing
        S_TRIP3_0: begin
          if (trip3_p > 0) begin
            edge_w[trip3_seq[0]][trip3_seq[1]] <= edge_time_from_dp(trip3_d, trip3_p);
            edge_w[trip3_seq[1]][trip3_seq[0]] <= edge_time_from_dp(trip3_d, trip3_p);
          end
        end
        S_TRIP3_1: begin
          if (trip3_p > 1) begin
            edge_w[trip3_seq[1]][trip3_seq[2]] <= edge_time_from_dp(trip3_d, trip3_p);
            edge_w[trip3_seq[2]][trip3_seq[1]] <= edge_time_from_dp(trip3_d, trip3_p);
          end
        end
        S_TRIP3_2: begin
          if (trip3_p > 2) begin
            edge_w[trip3_seq[2]][trip3_seq[3]] <= edge_time_from_dp(trip3_d, trip3_p);
            edge_w[trip3_seq[3]][trip3_seq[2]] <= edge_time_from_dp(trip3_d, trip3_p);
          end
        end

        // Build step: finalize adjacency if needed (here edges already set)
        S_BUILD: begin
          // No extra work; reserved for possible normalization
        end

        // Dijkstra iteration 0: initialize
        S_DIJK_0: begin
          dist[0] <= 8'hFF;
          dist[1] <= 8'hFF;
          dist[2] <= 8'hFF;
          dist[3] <= 8'hFF;
          dist[alice_node] <= 8'd0;
          visited[0] <= 1'b0;
          visited[1] <= 1'b0;
          visited[2] <= 1'b0;
          visited[3] <= 1'b0;
        end

        // Dijkstra iteration 1
        S_DIJK_1: begin
          // pick min
          cur_node <= pick_min_node(dist[0], dist[1], dist[2], dist[3], visited[0], visited[1], visited[2], visited[3]);
          cur_dist <= dist[pick_min_node(dist[0], dist[1], dist[2], dist[3], visited[0], visited[1], visited[2], visited[3])];
          visited[cur_node] <= 1'b1;
          // relax neighbors
          for (j = 0; j < 4; j = j + 1) begin
            if (!visited[j] && edge_w[cur_node][j] != 8'd0) begin
              if (cur_dist + edge_w[cur_node][j] < dist[j]) begin
                dist[j] <= cur_dist + edge_w[cur_node][j];
              end
            end
          end
        end

        // Dijkstra iteration 2
        S_DIJK_2: begin
          cur_node <= pick_min_node(dist[0], dist[1], dist[2], dist[3], visited[0], visited[1], visited[2], visited[3]);
          cur_dist <= dist[pick_min_node(dist[0], dist[1], dist[2], dist[3], visited[0], visited[1], visited[2], visited[3])];
          visited[cur_node] <= 1'b1;
          for (j = 0; j < 4; j = j + 1) begin
            if (!visited[j] && edge_w[cur_node][j] != 8'd0) begin
              if (cur_dist + edge_w[cur_node][j] < dist[j]) begin
                dist[j] <= cur_dist + edge_w[cur_node][j];
              end
            end
          end
        end

        // Dijkstra iteration 3
        S_DIJK_3: begin
          cur_node <= pick_min_node(dist[0], dist[1], dist[2], dist[3], visited[0], visited[1], visited[2], visited[3]);
          cur_dist <= dist[pick_min_node(dist[0], dist[1], dist[2], dist[3], visited[0], visited[1], visited[2], visited[3])];
          visited[cur_node] <= 1'b1;
          for (j = 0; j < 4; j = j + 1) begin
            if (!visited[j] && edge_w[cur_node][j] != 8'd0) begin
              if (cur_dist + edge_w[cur_node][j] < dist[j]) begin
                dist[j] <= cur_dist + edge_w[cur_node][j];
              end
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          shortest_time <= dist[hole_node];
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic (combinational)
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE:    next_state = start ? S_INIT : S_IDLE;
      S_INIT:    next_state = S_TRIP1_0;
      S_TRIP1_0: next_state = S_TRIP1_1;
      S_TRIP1_1: next_state = S_TRIP1_2;
      S_TRIP1_2: next_state = S_TRIP2_0;
      S_TRIP2_0: next_state = S_TRIP2_1;
      S_TRIP2_1: next_state = S_TRIP2_2;
      S_TRIP2_2: next_state = S_TRIP3_0;
      S_TRIP3_0: next_state = S_TRIP3_1;
      S_TRIP3_1: next_state = S_TRIP3_2;
      S_TRIP3_2: next_state = S_BUILD;
      S_BUILD:   next_state = S_DIJK_0;
      S_DIJK_0:  next_state = S_DIJK_1;
      S_DIJK_1:  next_state = S_DIJK_2;
      S_DIJK_2:  next_state = S_DIJK_3;
      S_DIJK_3:  next_state = S_DONE;
      S_DONE:    next_state = start ? S_INIT : S_DONE;
      default:   next_state = S_IDLE;
    endcase
  end

endmodule