module airline_review_cost(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [2:0] R,
  input [2:0] F,
  input [5:0][13:0] req_flights,
  input [5:0][13:0] add_flights,
  output reg [16:0] minimal_cost,
  output reg done
);

  // State encoding
  localparam IDLE          = 3'd0;
  localparam SUM_REQ_CALC  = 3'd1;
  localparam BUILD_GRAPH   = 3'd2;
  localparam PRIM_INIT     = 3'd3;
  localparam PRIM_MST      = 3'd4;
  localparam COMPLETE      = 3'd5;

  reg [2:0] state, next_state;

  // Internal registers
  reg [16:0] req_sum;
  reg [16:0] mst_cost;

  // Indexing
  reg [2:0] idx_req;       // up to 5
  reg [2:0] idx_add;       // up to 5
  reg [2:0] node_i;        // 1..8, stored 0..7
  reg [2:0] scan_idx;      // for Prim PQ scan

  // For edges
  reg [3:0] a, b;
  reg [13:0] c;            // cost up to 16383

  // Adjacency matrix (1-based node index mapped to 0..7)
  // Using 14-bit cost, 0 means no edge
  reg [13:0] adj_cost [0:7][0:7];

  // Prim's algorithm data
  reg visited [0:7];
  reg [13:0] dist [0:7];       // min edge cost to tree
  reg [2:0]  dist_src [0:7];   // not strictly needed, but kept simple

  // Misc
  reg [5:0] cycle_cnt;
  reg start_d;
  wire start_rise;

  // Start edge detection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end

  assign start_rise = start & ~start_d;

  // Sequential state register and cycle counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      cycle_cnt  <= 6'd0;
    end else begin
      state <= next_state;
      if (state == IDLE && start_rise)
        cycle_cnt <= 6'd0;
      else if (state != IDLE && state != COMPLETE)
        cycle_cnt <= cycle_cnt + 6'd1;
      else if (state == COMPLETE)
        cycle_cnt <= cycle_cnt;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_rise)
          next_state = SUM_REQ_CALC;
      end

      SUM_REQ_CALC: begin
        if (idx_req == R)
          next_state = BUILD_GRAPH;
      end

      BUILD_GRAPH: begin
        if (idx_add == F)
          next_state = PRIM_INIT;
      end

      PRIM_INIT: begin
        next_state = PRIM_MST;
      end

      PRIM_MST: begin
        // Move to COMPLETE either when MST done (all reachable visited)
        // or bounded by cycle count (safety <= 40 cycles)
        if (mst_done || cycle_cnt >= 6'd39)
          next_state = COMPLETE;
      end

      COMPLETE: begin
        // Wait until start goes low then high again
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Helper: minimal function
  function [13:0] min14;
    input [13:0] x;
    input [13:0] y;
    begin
      if (y != 14'd0 && (x == 14'd0 || y < x))
        min14 = y;
      else
        min14 = x;
    end
  endfunction

  // Wires and regs for Prim progress detection
  reg [3:0] visited_count;
  reg mst_done;

  integer i, j;

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      minimal_cost <= 17'd0;
      done         <= 1'b0;
      req_sum      <= 17'd0;
      mst_cost     <= 17'd0;
      idx_req      <= 3'd0;
      idx_add      <= 3'd0;
      node_i       <= 3'd0;
      scan_idx     <= 3'd0;
      visited_count<= 4'd0;
      mst_done     <= 1'b0;
      // reset adj and prim data
      for (i = 0; i < 8; i = i + 1) begin
        visited[i]   <= 1'b0;
        dist[i]      <= 14'd0;
        dist_src[i]  <= 3'd0;
        for (j = 0; j < 8; j = j + 1) begin
          adj_cost[i][j] <= 14'd0;
        end
      end
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          minimal_cost <= 17'd0;
          req_sum      <= 17'd0;
          mst_cost     <= 17'd0;
          idx_req      <= 3'd0;
          idx_add      <= 3'd0;
          node_i       <= 3'd0;
          scan_idx     <= 3'd0;
          visited_count<= 4'd0;
          mst_done     <= 1'b0;
          // Clear graph and prim data on new start edge
          if (start_rise) begin
            for (i = 0; i < 8; i = i + 1) begin
              visited[i]  <= 1'b0;
              dist[i]     <= 14'd0;
              dist_src[i] <= 3'd0;
              for (j = 0; j < 8; j = j + 1) begin
                adj_cost[i][j] <= 14'd0;
              end
            end
          end
        end

        // Sum required flights sequentially
        SUM_REQ_CALC: begin
          if (idx_req < R) begin
            // Extract {a,b,c} from packed 14-bit: [13:10]=a, [9:6]=b, [5:0] part of c? Provided spec inconsistent.
            // Use given: 4 bits a, 4 bits b, 14 bits c -> here total >14; to align with 14-bit input, interpret as:
            // [13:10]=a, [9:6]=b, [5:0]=upper 6 bits of cost assumed; but spec text dominates: assume lowest 10 bits used.
            // To avoid inconsistency, treat [13:10]=a, [9:6]=b, [5:0]=cost (up to 63). This keeps logic valid.
            a = req_flights[idx_req][13:10];
            b = req_flights[idx_req][9:6];
            c = {8'd0, req_flights[idx_req][5:0]};
            if (a != 4'd0 && b != 4'd0 && a <= N && b <= N) begin
              req_sum <= req_sum + c;
            end
            idx_req <= idx_req + 3'd1;
          end
        end

        // Build adjacency matrix from additional flights
        BUILD_GRAPH: begin
          if (idx_add < F) begin
            a = add_flights[idx_add][13:10];
            b = add_flights[idx_add][9:6];
            c = {8'd0, add_flights[idx_add][5:0]};
            if (a != 4'd0 && b != 4'd0 && a <= N && b <= N && a != b) begin
              // 1-based to 0-based indices
              i = a - 1;
              j = b - 1;
              // keep minimal cost edge if multiple
              adj_cost[i][j] <= min14(adj_cost[i][j], c);
              adj_cost[j][i] <= min14(adj_cost[j][i], c);
            end
            idx_add <= idx_add + 3'd1;
          end
        end

        // Initialize Prim's algorithm
        PRIM_INIT: begin
          mst_cost      <= 17'd0;
          mst_done      <= 1'b0;
          visited_count <= 4'd0;
          // Reset visited and dist
          for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
              visited[i] <= 1'b0;
              dist[i]    <= 14'd0;
            end else begin
              visited[i] <= 1'b1; // mark unused nodes as visited
              dist[i]    <= 14'd0;
            end
          end
          // Start MST from node 0 if N>0
          if (N != 0) begin
            visited[0]      <= 1'b1;
            visited_count   <= 4'd1;
            // initialize dist[] from node 0
            for (j = 0; j < 8; j = j + 1) begin
              if (j < N) begin
                dist[j] <= adj_cost[0][j];
              end else begin
                dist[j] <= 14'd0;
              end
            end
            dist[0] <= 14'd0;
          end else begin
            mst_done <= 1'b1;
          end
          scan_idx <= 3'd0;
        end

        // Prim's MST main loop: one node selection/relax per iteration
        PRIM_MST: begin
          if (!mst_done && N != 0) begin
            // Find unvisited node with minimal dist
            reg [13:0] best_cost;
            reg [2:0]  best_node;
            best_cost = 14'd0;
            best_node = 3'd0;

            for (i = 0; i < 8; i = i + 1) begin
              if (i < N && !visited[i] && dist[i] != 14'd0) begin
                if (best_cost == 14'd0 || dist[i] < best_cost) begin
                  best_cost = dist[i];
                  best_node = i[2:0];
                end
              end
            end

            if (best_cost == 14'd0) begin
              // No reachable nodes remain; MST complete for reachable set
              mst_done <= 1'b1;
            end else begin
              // Include best_node in MST
              visited[best_node] <= 1'b1;
              visited_count      <= visited_count + 4'd1;
              mst_cost           <= mst_cost + best_cost;

              // Relax neighbors of best_node
              for (j = 0; j < 8; j = j + 1) begin
                if (j < N && !visited[j]) begin
                  if (adj_cost[best_node][j] != 14'd0) begin
                    if (dist[j] == 14'd0 || adj_cost[best_node][j] < dist[j]) begin
                      dist[j]     <= adj_cost[best_node][j];
                      dist_src[j] <= best_node[2:0];
                    end
                  end
                end
              end

              // If all N nodes visited, MST done
              if (visited_count + 4'd1 >= N[3:0]) begin
                mst_done <= 1'b1;
              end
            end
          end
        end

        COMPLETE: begin
          minimal_cost <= req_sum + mst_cost;
          done         <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule