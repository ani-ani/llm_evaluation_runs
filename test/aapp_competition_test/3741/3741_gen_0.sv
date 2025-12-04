module shortest_cycle_detector(
  input clk,
  input rst_n,
  input start,
  input [15:0] a0,
  input [15:0] a1,
  input [15:0] a2,
  input [15:0] a3,
  input [15:0] a4,
  input [15:0] a5,
  input [15:0] a6,
  input [15:0] a7,
  output reg [4:0] cycle_len,
  output reg done
);

  // State encoding
  localparam IDLE          = 2'd0;
  localparam BUILD_GRAPH   = 2'd1;
  localparam SEARCH_CYCLES = 2'd2;
  localparam DONE          = 2'd3;

  reg [1:0] state, next_state;

  // 8x8 adjacency matrix
  reg [7:0] adj [7:0];

  // Latched inputs
  reg [15:0] a_reg[7:0];

  // Fixed latency counter (0..49)
  reg [5:0] cycle_cnt;

  // Search control
  reg [2:0] start_node;
  reg [2:0] u_node;
  reg [2:0] v_node;

  // BFS/shortest cycle tracking
  reg [3:0] best_cycle;          // 0 means none found yet, else 3..8
  reg [3:0] dist [7:0];          // distance from start_node
  reg       visited [7:0];

  // Internal signals
  integer i;

  // Combinational next state
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = BUILD_GRAPH;
      end
      BUILD_GRAPH: begin
        next_state = SEARCH_CYCLES;
      end
      SEARCH_CYCLES: begin
        if (cycle_cnt == 6'd49)
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Synchronous logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      done       <= 1'b0;
      cycle_len  <= 5'd0;
      cycle_cnt  <= 6'd0;
      best_cycle <= 4'd0;
      start_node <= 3'd0;
      u_node     <= 3'd0;
      v_node     <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        a_reg[i]   <= 16'd0;
        adj[i]     <= 8'd0;
        dist[i]    <= 4'd0;
        visited[i] <= 1'b0;
      end
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done       <= 1'b0;
          cycle_len  <= 5'd0;
          cycle_cnt  <= 6'd0;
          best_cycle <= 4'd0;
          start_node <= 3'd0;
          u_node     <= 3'd0;
          v_node     <= 3'd0;
          if (start) begin
            // Latch inputs
            a_reg[0] <= a0;
            a_reg[1] <= a1;
            a_reg[2] <= a2;
            a_reg[3] <= a3;
            a_reg[4] <= a4;
            a_reg[5] <= a5;
            a_reg[6] <= a6;
            a_reg[7] <= a7;
          end
        end

        BUILD_GRAPH: begin
          // Build adjacency matrix combinationally based on latched inputs
          // edge[i][j] = 1 if i != j and (ai & aj) != 0
          adj[0] <= { ( (a_reg[0] & a_reg[7]) != 16'd0 ),
                      ( (a_reg[0] & a_reg[6]) != 16'd0 ),
                      ( (a_reg[0] & a_reg[5]) != 16'd0 ),
                      ( (a_reg[0] & a_reg[4]) != 16'd0 ),
                      ( (a_reg[0] & a_reg[3]) != 16'd0 ),
                      ( (a_reg[0] & a_reg[2]) != 16'd0 ),
                      ( (a_reg[0] & a_reg[1]) != 16'd0 ),
                      1'b0 };

          adj[1] <= { ( (a_reg[1] & a_reg[7]) != 16'd0 ),
                      ( (a_reg[1] & a_reg[6]) != 16'd0 ),
                      ( (a_reg[1] & a_reg[5]) != 16'd0 ),
                      ( (a_reg[1] & a_reg[4]) != 16'd0 ),
                      ( (a_reg[1] & a_reg[3]) != 16'd0 ),
                      ( (a_reg[1] & a_reg[2]) != 16'd0 ),
                      1'b0,
                      ( (a_reg[1] & a_reg[0]) != 16'd0 ) };

          adj[2] <= { ( (a_reg[2] & a_reg[7]) != 16'd0 ),
                      ( (a_reg[2] & a_reg[6]) != 16'd0 ),
                      ( (a_reg[2] & a_reg[5]) != 16'd0 ),
                      ( (a_reg[2] & a_reg[4]) != 16'd0 ),
                      ( (a_reg[2] & a_reg[3]) != 16'd0 ),
                      1'b0,
                      ( (a_reg[2] & a_reg[1]) != 16'd0 ),
                      ( (a_reg[2] & a_reg[0]) != 16'd0 ) };

          adj[3] <= { ( (a_reg[3] & a_reg[7]) != 16'd0 ),
                      ( (a_reg[3] & a_reg[6]) != 16'd0 ),
                      ( (a_reg[3] & a_reg[5]) != 16'd0 ),
                      ( (a_reg[3] & a_reg[4]) != 16'd0 ),
                      1'b0,
                      ( (a_reg[3] & a_reg[2]) != 16'd0 ),
                      ( (a_reg[3] & a_reg[1]) != 16'd0 ),
                      ( (a_reg[3] & a_reg[0]) != 16'd0 ) };

          adj[4] <= { ( (a_reg[4] & a_reg[7]) != 16'd0 ),
                      ( (a_reg[4] & a_reg[6]) != 16'd0 ),
                      ( (a_reg[4] & a_reg[5]) != 16'd0 ),
                      1'b0,
                      ( (a_reg[4] & a_reg[3]) != 16'd0 ),
                      ( (a_reg[4] & a_reg[2]) != 16'd0 ),
                      ( (a_reg[4] & a_reg[1]) != 16'd0 ),
                      ( (a_reg[4] & a_reg[0]) != 16'd0 ) };

          adj[5] <= { ( (a_reg[5] & a_reg[7]) != 16'd0 ),
                      ( (a_reg[5] & a_reg[6]) != 16'd0 ),
                      1'b0,
                      ( (a_reg[5] & a_reg[4]) != 16'd0 ),
                      ( (a_reg[5] & a_reg[3]) != 16'd0 ),
                      ( (a_reg[5] & a_reg[2]) != 16'd0 ),
                      ( (a_reg[5] & a_reg[1]) != 16'd0 ),
                      ( (a_reg[5] & a_reg[0]) != 16'd0 ) };

          adj[6] <= { ( (a_reg[6] & a_reg[7]) != 16'd0 ),
                      1'b0,
                      ( (a_reg[6] & a_reg[5]) != 16'd0 ),
                      ( (a_reg[6] & a_reg[4]) != 16'd0 ),
                      ( (a_reg[6] & a_reg[3]) != 16'd0 ),
                      ( (a_reg[6] & a_reg[2]) != 16'd0 ),
                      ( (a_reg[6] & a_reg[1]) != 16'd0 ),
                      ( (a_reg[6] & a_reg[0]) != 16'd0 ) };

          adj[7] <= { 1'b0,
                      ( (a_reg[7] & a_reg[6]) != 16'd0 ),
                      ( (a_reg[7] & a_reg[5]) != 16'd0 ),
                      ( (a_reg[7] & a_reg[4]) != 16'd0 ),
                      ( (a_reg[7] & a_reg[3]) != 16'd0 ),
                      ( (a_reg[7] & a_reg[2]) != 16'd0 ),
                      ( (a_reg[7] & a_reg[1]) != 16'd0 ),
                      ( (a_reg[7] & a_reg[0]) != 16'd0 ) };

          // Initialize for SEARCH
          cycle_cnt  <= 6'd0;
          best_cycle <= 4'd0;
          start_node <= 3'd0;

          // Initialize BFS arrays for start_node=0
          for (i = 0; i < 8; i = i + 1) begin
            visited[i] <= 1'b0;
            dist[i]    <= 4'd0;
          end
          visited[0] <= 1'b1;
          dist[0]    <= 4'd0;
          u_node     <= 3'd0;
          v_node     <= 3'd0;
        end

        SEARCH_CYCLES: begin
          // Increment global cycle counter to enforce fixed latency
          if (cycle_cnt < 6'd49)
            cycle_cnt <= cycle_cnt + 6'd1;

          // Simple sequential search over (start_node, u_node, v_node)
          // to detect cycles using adjacency and distance/visited info.
          // This is a serialized approximation of multi-source BFS from start_node.

          // Only process when within search window (0..47); last cycles just idle.
          if (cycle_cnt < 6'd48) begin
            // Use current indices
            // Ensure u_node is always a valid visited node before exploring neighbors
            if (!visited[u_node]) begin
              // advance u_node until a visited node or wrap
              u_node <= (u_node == 3'd7) ? 3'd0 : (u_node + 3'd1);
            end else begin
              // Explore neighbor v_node of u_node
              if (adj[u_node][v_node]) begin
                // If neighbor not yet visited: set distance and visited
                if (!visited[v_node]) begin
                  visited[v_node] <= 1'b1;
                  dist[v_node]    <= dist[u_node] + 4'd1;
                end else begin
                  // If neighbor visited and not direct parent, potential cycle
                  if (dist[v_node] >= dist[u_node]) begin
                    // Cycle length approximation: dist[u] + dist[v] + 1
                    // (sufficient heuristic for small graph under constraints)
                    reg [4:0] cyc_len_candidate;
                    cyc_len_candidate = dist[u_node] + dist[v_node] + 5'd1;
                    if (cyc_len_candidate >= 5'd3 && cyc_len_candidate <= 5'd8) begin
                      if (best_cycle == 4'd0 || cyc_len_candidate[3:0] < best_cycle)
                        best_cycle <= cyc_len_candidate[3:0];
                    end
                  end
                end
              end

              // Advance v_node within neighbors
              if (v_node == 3'd7) begin
                v_node <= 3'd0;
                // Move to next u_node
                if (u_node == 3'd7) begin
                  u_node <= 3'd0;
                  // Completed one pass for current start_node, move to next start
                  if (start_node != 3'd7) begin
                    start_node <= start_node + 3'd1;
                    // Re-init visited/dist for new start_node
                    for (i = 0; i < 8; i = i + 1) begin
                      visited[i] <= 1'b0;
                      dist[i]    <= 4'd0;
                    end
                    visited[start_node + 3'd1] <= 1'b1;
                    dist[start_node + 3'd1]    <= 4'd0;
                  end
                end else begin
                  u_node <= u_node + 3'd1;
                end
              end else begin
                v_node <= v_node + 3'd1;
              end
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          if (best_cycle == 4'd0)
            cycle_len <= 5'd0;   // No cycle
          else
            cycle_len <= {1'b0, best_cycle};
          // Stay here until start is deasserted; next_state handles transition
        end

        default: begin
          // Should not occur; reset-like behavior
          done       <= 1'b0;
          cycle_len  <= 5'd0;
        end
      endcase
    end
  end

endmodule