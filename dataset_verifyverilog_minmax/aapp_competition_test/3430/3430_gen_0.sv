module network_optimizer (
  input clk,
  input rst_n,
  input start,
  input [2:0] size_A,
  input [2:0] size_B,
  input [63:0] adj_A,
  input [63:0] adj_B,
  output reg [15:0] min_cost,
  output reg done
);

  // Inner module: computes sum of squared distances and per-node SS values for one tree
  module tree_bfs (
    input clk,
    input rst_n,
    input start,
    input [2:0] size,
    input [63:0] adj,
    output reg [10:0] sum_sq_all,   // sum_{u<v} d(u,v)^2 (max 392)
    output reg [10:0] min_ss,       // min_u SS[u]
    output reg [2:0] min_idx,       // argmin_u SS[u]
    output reg done                 // 1-cycle pulse when done
  );

    function [3:0] bits_find_first (input [7:0] v);
      integer i;
      begin
        bits_find_first = 4'd0;
        for (i = 0; i < 8; i = i + 1) begin
          if (v[i]) begin
            bits_find_first = i[3:0];
            return;
          end
        end
        bits_find_first = 4'd0; // no bit set; caller should not use this value
      end
    endfunction

    // Distance matrix: dist[src][dst] in 4 bits, 0..7 (8 means unvisited, but BFS guarantees fill)
    reg [3:0] dist [0:7][0:7];
    integer i0, j0; // genvar replacements (simulation-compatible)

    // BFS control
    reg [2:0] state, next_state;
    reg [2:0] src;
    reg [7:0] visited;     // one-hot per node (when bit = 1, distance is finalized)
    reg [7:0] frontier;    // current BFS frontier (one-hot)
    reg [7:0] next_frontier;
    reg [3:0] dist_frontier; // distance of current frontier
    reg [3:0] cnt_remain;    // how many nodes are still unvisited (relative to this src)
    reg [10:0] sum_sq_src;   // sum of squared distances for current source

    localparam S_IDLE  = 3'd0;
    localparam S_BFS   = 3'd1;
    localparam S_NEXT  = 3'd2;
    localparam S_DONE  = 3'd3;

    // State update
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) state <= S_IDLE;
      else        state <= next_state;
    end

    // Next-state logic
    always @(*) begin
      next_state = state;
      case (state)
        S_IDLE: next_state = start ? S_BFS : S_IDLE;
        S_BFS:  next_state = (cnt_remain == 4'd0) ? S_NEXT : S_BFS;
        S_NEXT: next_state = (src == 3'd7) ? S_DONE : S_BFS;
        S_DONE: next_state = S_IDLE;
        default: next_state = S_IDLE;
      endcase
    end

    // BFS logic and accumulators
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        for (i0 = 0; i0 < 8; i0 = i0 + 1)
          for (j0 = 0; j0 < 8; j0 = j0 + 1)
            dist[i0][j0] <= 4'd8; // mark as unfilled (8 used as invalid since max BFS dist=7)
        src       <= 3'd0;
        visited   <= 8'd0;
        frontier  <= 8'd0;
        next_frontier <= 8'd0;
        dist_frontier <= 4'd0;
        cnt_remain <= 3'd0;
        sum_sq_src <= 11'd0;
        sum_sq_all <= 11'd0;
        min_ss     <= 11'd0;
        min_idx    <= 3'd0;
        done       <= 1'b0;
      end else begin
        // default: keep these stable unless updated below
        done       <= 1'b0;
        sum_sq_src <= sum_sq_src;
        sum_sq_all <= sum_sq_all;
        min_ss     <= min_ss;
        min_idx    <= min_idx;

        case (state)
          S_IDLE: begin
            // Clear memory and stats on start
            if (start) begin
              for (i0 = 0; i0 < 8; i0 = i0 + 1)
                for (j0 = 0; j0 < 8; j0 = j0 + 1)
                  dist[i0][j0] <= 4'd8;
              src         <= 3'd0;
              sum_sq_all  <= 11'd0;
              min_ss      <= 11'd0;
              min_idx     <= 3'd0;
              // BFS init will be done in S_BFS when we enter it
              visited     <= 8'd0;
              frontier    <= 8'd0;
              next_frontier <= 8'd0;
              dist_frontier <= 4'd0;
              cnt_remain  <= 3'd0;
              sum_sq_src  <= 11'd0;
            end
          end

          S_BFS: begin
            // Initialize BFS for this src on first entry to S_BFS for this src
            if (visited == 8'd0) begin
              dist[src][src] <= 4'd0;
              visited        <= 1 << src;
              frontier       <= 1 << src;
              dist_frontier  <= 4'd0;
              // All other nodes are unvisited; ensure distances are invalid for cleanliness
              for (j0 = 0; j0 < 8; j0 = j0 + 1) begin
                if (j0 != src) dist[src][j0] <= 4'd8;
              end
              cnt_remain <= size - 1; // number of nodes left to discover for this source
              sum_sq_src <= 11'd0;
            end

            // Expand one level: process current frontier
            if (frontier != 8'd0) begin
              // next_frontier are neighbors of current frontier not yet visited
              next_frontier <= 8'd0;
              for (i0 = 0; i0 < 8; i0 = i0 + 1) begin
                if (frontier[i0]) begin
                  // neighbors = adj[8*i0 +: 8] masked by ~visited
                  next_frontier <= next_frontier | (adj[8*i0 +: 8] & (~visited));
                end
              end
              // Distance to set for nodes in next frontier
              for (i0 = 0; i0 < 8; i0 = i0 + 1) begin
                if (next_frontier[i0]) begin
                  dist[src][i0] <= dist_frontier + 1;
                end
              end
              visited  <= visited | next_frontier;
              // Count how many new nodes were discovered
              cnt_remain <= cnt_remain - bits_count(next_frontier);
            end

            // Move to next frontier
            frontier <= next_frontier;
            dist_frontier <= dist_frontier + 1;

            if (cnt_remain == 4'd0) begin
              // BFS finished for this source
              // sum over destinations
              for (j0 = 0; j0 < 8; j0 = j0 + 1) begin
                if (j0 > src) begin
                  sum_sq_src <= sum_sq_src + ({7'd0, dist[src][j0]} * {7'd0, dist[src][j0]});
                end
              end
              // Update per-node SS and global min
              if (src == 3'd0) begin
                min_ss  <= sum_sq_src;
                min_idx <= 3'd0;
              end else begin
                if (sum_sq_src < min_ss) begin
                  min_ss  <= sum_sq_src;
                  min_idx <= src;
                end
              end
              // Accumulate sum_{u<v} d(u,v)^2 across all processed src
              sum_sq_all <= sum_sq_all + sum_sq_src;
            end
          end

          S_NEXT: begin
            // Prepare for next source
            src <= src + 1;
            visited   <= 8'd0;
            frontier  <= 8'd0;
            next_frontier <= 8'd0;
            dist_frontier <= 4'd0;
            cnt_remain <= 3'd0;
            sum_sq_src <= 11'd0;
          end

          S_DONE: begin
            done <= 1'b1; // 1-cycle pulse
          end

          default: begin
            // no-op
          end
        endcase
      end
    end

    // Count set bits in a byte (for 0..8)
    function [3:0] bits_count (input [7:0] v);
      integer k;
      begin
        bits_count = 4'd0;
        for (k = 0; k < 8; k = k + 1)
          if (v[k]) bits_count = bits_count + 1;
      end
    endfunction

  endmodule

  // Instantiate BFS modules for both trees
  wire doneA, doneB;
  wire [10:0] sum_sq_A, min_ss_A;
  wire [2:0] min_idx_A;
  wire [10:0] sum_sq_B, min_ss_B;
  wire [2:0] min_idx_B;

  tree_bfs bfsA (
    .clk        (clk),
    .rst_n      (rst_n),
    .start      (start),
    .size       (size_A),
    .adj        (adj_A),
    .sum_sq_all (sum_sq_A),
    .min_ss     (min_ss_A),
    .min_idx    (min_idx_A),
    .done       (doneA)
  );

  tree_bfs bfsB (
    .clk        (clk),
    .rst_n      (rst_n),
    .start      (start),
    .size       (size_B),
    .adj        (adj_B),
    .sum_sq_all (sum_sq_B),
    .min_ss     (min_ss_B),
    .min_idx    (min_idx_B),
    .done       (doneB)
  );

  // State machine to sequence the two trees and produce final result
  reg [1:0] state;
  reg [10:0] origA, origB;
  reg [10:0] sA, sB;
  reg [2:0] nA, nB;

  localparam S_IDLE = 2'd0;
  localparam S_RUN_A = 2'd1;
  localparam S_RUN_B = 2'd2;
  localparam S_DONE = 2'd3;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      origA   <= 11'd0;
      origB   <= 11'd0;
      sA      <= 11'd0;
      sB      <= 11'd0;
      nA      <= 3'd0;
      nB      <= 3'd0;
      min_cost <= 16'd0;
      done    <= 1'b0;
    end else begin
      done <= 1'b0; // default
      case (state)
        S_IDLE: begin
          if (start) begin
            state <= S_RUN_A;
            nA <= size_A;
            nB <= size_B;
            // Persist sizes while both run
          end
        end

        S_RUN_A: begin
          // BFS for A completed; store results and keep them until B is done
          if (doneA) begin
            origA <= sum_sq_A;   // sum_{u<v in A} d^2
            sA    <= min_ss_A;   // min SS in A
            // hold start high to keep A in a stable done state
          end
          if (doneA) state <= S_RUN_B; // move on
        end

        S_RUN_B: begin
          // BFS for B completed; we can now compute the final cost
          if (doneB) begin
            origB <= sum_sq_B;   // sum_{u<v in B} d^2
            sB    <= min_ss_B;   // min SS in B
            // Final cost: origA + origB + (|A|*|B|) + sA*|B| + sB*|A|
            min_cost <= {5'd0, origA} + {5'd0, origB}
                      + {8'd0, nA} * {8'd0, nB}
                      + {5'd0, sA} * {8'd0, nB}
                      + {5'd0, sB} * {8'd0, nA};
            state <= S_DONE;
          end
        end

        S_DONE: begin
          done <= 1'b1;      // pulse 1 cycle
          state <= S_IDLE;   // return to idle
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
