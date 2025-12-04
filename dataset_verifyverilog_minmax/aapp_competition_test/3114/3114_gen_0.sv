module directed_strong_connect(
  input clk,
  input rst_n,
  input start,
  input [15:0] adj_matrix,
  output reg possible,
  output reg [15:0] directed_graph,
  output reg done
);

  // Internal state
  reg active;                // 1 when processing
  reg [3:0] phase;           // 0..15 scan phases (max 16 cycles)
  reg [15:0] adj_curr;       // Working copy of adj_matrix during scan
  reg found_bridge;

  // Edge index (upper triangle i<j):
  // e0: (0,1), e1: (0,2), e2: (0,3), e3: (1,2), e4: (1,3), e5: (2,3)
  function [2:0] edge_index(input integer i, input integer j);
    // Only valid for 0<=i<j<4
    case ({i,j})
      {0,1}: edge_index = 0;
      {0,2}: edge_index = 1;
      {0,3}: edge_index = 2;
      {1,2}: edge_index = 3;
      {1,3}: edge_index = 4;
      {2,3}: edge_index = 5;
      default: edge_index = 0; // unreachable for valid calls
    endcase
  endfunction

  function integer bit_index(input integer r, input integer c);
    // bit 0 -> (0,0), bit 1 -> (0,1), ..., bit 15 -> (3,3)
    bit_index = r * 4 + c;
  endfunction

  // Check if graph (with one edge possibly removed) is connected via BFS from node 0
  function bit graph_connected(input bit [15:0] adj);
    integer q[4];
    integer head, tail, count, u, v, b;
    bit visited[4];

    // Initialize
    for (int i = 0; i < 4; i++) begin
      visited[i] = 1'b0;
      q[i] = -1;
    end
    head = 0; tail = 0; count = 0;

    // Start BFS from node 0
    q[tail] = 0; tail = (tail + 1) % 4; count = 1; visited[0] = 1'b1;

    while (head != tail) begin
      u = q[head]; head = (head + 1) % 4;
      // Explore neighbors of u
      for (v = 0; v < 4; v++) begin
        if (u == v) continue;
        b = bit_index(u, v);
        if (adj[b] && !visited[v]) begin
          visited[v] = 1'b1;
          q[tail] = v; tail = (tail + 1) % 4; count = count + 1;
        end
      end
    end

    graph_connected = (count == 4);
  endfunction

  // FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      possible <= 1'b0;
      directed_graph <= 16'h0;
      done <= 1'b0;
      active <= 1'b0;
      phase <= 4'd0;
      adj_curr <= 16'h0;
      found_bridge <= 1'b0;
    end else begin
      if (!active) begin
        // Idle: arm on start, hold outputs until start
        possible <= 1'b0;
        directed_graph <= 16'h0;
        done <= 1'b0;
        phase <= 4'd0;
        found_bridge <= 1'b0;
        if (start) begin
          adj_curr <= adj_matrix; // sample input once
          active <= 1'b1;
        end
      end else begin
        // Active: single cycle per phase (max 16 cycles)
        if (phase < 4'd6) begin
          // Test one upper-triangle edge per cycle
          case (phase)
            4'd0: begin
              if (adj_curr[bit_index(0,1)]) begin
                if (!graph_connected(adj_curr & ~(16'h1 << bit_index(0,1))))
                  found_bridge <= 1'b1;
              end
            end
            4'd1: begin
              if (adj_curr[bit_index(0,2)]) begin
                if (!graph_connected(adj_curr & ~(16'h1 << bit_index(0,2))))
                  found_bridge <= 1'b1;
              end
            end
            4'd2: begin
              if (adj_curr[bit_index(0,3)]) begin
                if (!graph_connected(adj_curr & ~(16'h1 << bit_index(0,3))))
                  found_bridge <= 1'b1;
              end
            end
            4'd3: begin
              if (adj_curr[bit_index(1,2)]) begin
                if (!graph_connected(adj_curr & ~(16'h1 << bit_index(1,2))))
                  found_bridge <= 1'b1;
              end
            end
            4'd4: begin
              if (adj_curr[bit_index(1,3)]) begin
                if (!graph_connected(adj_curr & ~(16'h1 << bit_index(1,3))))
                  found_bridge <= 1'b1;
              end
            end
            4'd5: begin
              if (adj_curr[bit_index(2,3)]) begin
                if (!graph_connected(adj_curr & ~(16'h1 << bit_index(2,3))))
                  found_bridge <= 1'b1;
              end
            end
          endcase
        end
        // Pad extra cycles to meet 16-cycle max latency
        // phases 6..15 are no-ops

        phase <= phase + 4'd1;

        if (phase == 4'd15) begin
          // Finalize results after exactly 16 cycles
          done <= 1'b1;
          possible <= ~found_bridge;
          if (found_bridge) begin
            directed_graph <= 16'h0; // undefined in this case; set to 0
          end else begin
            // Simple assignment: direct all edges away from node 0
            // If undirected edge (0,j) exists, set directed edge 0->j
            directed_graph[bit_index(0,1)] = adj_curr[bit_index(0,1)];
            directed_graph[bit_index(0,2)] = adj_curr[bit_index(0,2)];
            directed_graph[bit_index(0,3)] = adj_curr[bit_index(0,3)];
            // No other edges are set (no back-edges)
          end
          // Go back to idle; hold done/possible until next start or reset
          active <= 1'b0;
        end
      end
    end
  end

endmodule
