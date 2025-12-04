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
  localparam IDLE = 2'b00;
  localparam BUILD_GRAPH = 2'b01;
  localparam SEARCH_CYCLES = 2'b10;
  localparam DONE = 2'b11;
  localparam MAX_CYCLES = 50; // fixed latency (cycles)

  reg [1:0] state, next_state;
  reg [5:0] cycle_counter;

  // 8x8 adjacency bitmasks (neighbors[i] is an 8-bit mask)
  reg [7:0] neighbors [0:7];
  integer i, j;

  // Combinational function to find the shortest cycle length in [3..8]
  // Returns 0 if no cycle exists.
  function [4:0] shortest_cycle;
    input [7:0] neigh [0:7];
    integer n, k, u, v;
    reg [7:0] visited;
    integer dist[0:7];
    integer q[0:7];
    integer qh, qt;
    integer parent[0:7];
    reg [3:0] min_len;
    reg found;
    reg [7:0] nbrs;
    begin
      shortest_cycle = 0;
      min_len = 4'd9;
      found = 1'b0;
      // BFS from each node as source
      for (n = 0; n < 8; n = n + 1) begin
        // skip isolated source (no edges)
        if (neigh[n] == 8'b0) begin
          continue;
        end
        // initialize BFS structures
        for (k = 0; k < 8; k = k + 1) begin
          visited[k] = 1'b0;
          dist[k] = -1;
          parent[k] = -1;
          q[k] = 0;
        end
        qh = 0; qt = 0;
        visited[n] = 1'b1;
        dist[n] = 0;
        q[qt] = n; qt = qt + 1;

        while (qh < qt) begin
          u = q[qh]; qh = qh + 1;
          nbrs = neigh[u];
          for (v = 0; v < 8; v = v + 1) begin
            if (nbrs[v]) begin
              // edge (u,v) exists
              if (parent[u] == v) begin
                // skip the edge back to parent
                continue;
              end
              if (visited[v]) begin
                // found a cycle; length = dist[u] + dist[v] + 1
                if (dist[v] >= 0) begin
                  if ((dist[u] + dist[v] + 1) <= 8) begin
                    if ((dist[u] + dist[v] + 1) < min_len) begin
                      min_len = dist[u] + dist[v] + 1;
                      found = 1'b1;
                    end
                  end
                end
              end else begin
                visited[v] = 1'b1;
                dist[v] = dist[u] + 1;
                parent[v] = u;
                q[qt] = v; qt = qt + 1;
              end
            end
          end
        end
      end
      if (found) shortest_cycle = min_len;
      else shortest_cycle = 0;
    end
  endfunction

  always_comb begin
    next_state = state;
    case (state)
      IDLE:     next_state = start ? BUILD_GRAPH : IDLE;
      BUILD_GRAPH: next_state = SEARCH_CYCLES;
      SEARCH_CYCLES: next_state = (cycle_counter == (MAX_CYCLES - 1)) ? DONE : SEARCH_CYCLES;
      DONE:     next_state = IDLE;
      default:  next_state = IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_counter <= 6'd0;
      cycle_len <= 5'd0;
      done <= 1'b0;
      for (i = 0; i < 8; i = i + 1) neighbors[i] <= 8'b0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          cycle_counter <= 6'd0;
          done <= 1'b0;
          cycle_len <= 5'd0;
          if (next_state == BUILD_GRAPH) begin
            // Build adjacency matrix: edge[i][j] = (ai & aj) != 0, i != j
            for (i = 0; i < 8; i = i + 1) begin
              neighbors[i] = 8'b0;
            end
            for (i = 0; i < 8; i = i + 1) begin
              for (j = 0; j < 8; j = j + 1) begin
                if (i != j) begin
                  case (i)
                    0: neighbors[i][j] = (a0 & (j==1?a1:j==2?a2:j==3?a3:j==4?a4:j==5?a5:j==6?a6:a7)) != 0;
                    1: neighbors[i][j] = (a1 & (j==0?a0:j==2?a2:j==3?a3:j==4?a4:j==5?a5:j==6?a6:a7)) != 0;
                    2: neighbors[i][j] = (a2 & (j==0?a0:j==1?a1:j==3?a3:j==4?a4:j==5?a5:j==6?a6:a7)) != 0;
                    3: neighbors[i][j] = (a3 & (j==0?a0:j==1?a1:j==2?a2:j==4?a4:j==5?a5:j==6?a6:a7)) != 0;
                    4: neighbors[i][j] = (a4 & (j==0?a0:j==1?a1:j==2?a2:j==3?a3:j==5?a5:j==6?a6:a7)) != 0;
                    5: neighbors[i][j] = (a5 & (j==0?a0:j==1?a1:j==2?a2:j==3?a3:j==4?a4:j==6?a6:a7)) != 0;
                    6: neighbors[i][j] = (a6 & (j==0?a0:j==1?a1:j==2?a2:j==3?a3:j==4?a4:j==5?a5:a7)) != 0;
                    7: neighbors[i][j] = (a7 & (j==0?a0:j==1?a1:j==2?a2:j==3?a3:j==4?a4:j==5?a5:a6)) != 0;
                  endcase
                end
              end
            end
          end
        end
        BUILD_GRAPH: begin
          // Hold steady for one cycle; next_state already set to SEARCH_CYCLES
        end
        SEARCH_CYCLES: begin
          cycle_counter <= cycle_counter + 1;
          if (cycle_counter == (MAX_CYCLES - 1)) begin
            cycle_len <= shortest_cycle(neighbors);
            done <= 1'b1;
          end
        end
        DONE: begin
          done <= 1'b0;
          cycle_counter <= 6'd0;
        end
      endcase
    end
  end
endmodule