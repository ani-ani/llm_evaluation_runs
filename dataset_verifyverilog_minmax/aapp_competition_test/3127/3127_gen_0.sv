module network_switch_analyzer (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] m,
  input [2:0] edges [15:0][2:0], // [a, b, len_high] (a,b: 1..8)
  input [15:0] len_low [15:0],    // 16 len_low values (msb is len_low[15])
  output reg [7:0] unused_mask,
  output reg done
);

  // Constants
  localparam NODES = 8;
  localparam MAX_EDGES = 16;
  localparam CYCLE_LIMIT = 256;
  localparam BIG = 24'hF00000; // larger than any possible path length (<= 8*2^24-1)

  // Registered inputs (latched on start)
  reg [2:0] n_r, m_r;
  reg [2:0] edges_r [MAX_EDGES][2:0]; // [a,b]
  reg [15:0] len_low_r [MAX_EDGES];

  // Control and timing
  reg [8:0] cycle_cnt;     // counts cycles after enter_active
  reg active;              // computation state
  reg done_d1;             // pipeline for done

  // Floyd-Warshall matrices (0..7 -> nodes 1..8)
  integer dist [0:7][0:7];
  integer dist_next [0:7][0:7];
  reg [7:0] pred [0:7][0:7]; // predecessor bitmasks: which node was directly before j on a shortest path to j

  // Reconstructed path masks (for source=0, target=n_r-1)
  reg [7:0] path_mask_d1, path_mask_d2, path_mask_d3;

  // Internal indices
  reg [3:0] k_idx, i_idx, j_idx; // 0..7, fits in 4 bits

  // Helper functions
  function [7:0] path_nodes;
    input [7:0] src; // source node index (0..7)
    input [7:0] dst; // target node index (0..7)
    reg [7:0] mask;
    integer v, u;
    reg found;
    begin
      mask = 8'b0;
      v = dst;
      found = 1'b0;
      while (v >= 0 && v < 8) begin
        mask = mask | (1 << v);
        if (v == src) begin
          found = 1'b1;
          break;
        end
        // If multiple predecessors possible, pick the lowest-index predecessor to traverse
        if (pred[v][src] == 8'b0) begin
          found = 1'b0; // unreachable in recorded paths
          break;
        end
        for (u = 0; u < 8; u = u + 1) begin
          if (pred[v][src] & (1 << u)) begin
            v = u;
            // choose the lowest-index one (deterministic)
            break;
          end
        end
      end
      path_nodes = found ? mask : 8'b0;
    end
  endfunction

  function [7:0] rev_path_nodes;
    input [7:0] src;
    input [7:0] dst;
    reg [7:0] mask;
    integer v, u;
    reg found;
    begin
      mask = 8'b0;
      v = src;
      found = 1'b0;
      while (v >= 0 && v < 8) begin
        mask = mask | (1 << v);
        if (v == dst) begin
          found = 1'b1;
          break;
        end
        if (pred[src][v] == 8'b0) begin
          found = 1'b0;
          break;
        end
        for (u = 0; u < 8; u = u + 1) begin
          if (pred[src][v] & (1 << u)) begin
            v = u; // lowest-index predecessor
            break;
          end
        end
      end
      rev_path_nodes = found ? mask : 8'b0;
    end
  endfunction

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      unused_mask <= 8'b0;
      done <= 1'b0;
      done_d1 <= 1'b0;
      active <= 1'b0;
      cycle_cnt <= 9'b0;
      n_r <= 3'd0;
      m_r <= 3'd0;
      k_idx <= 4'd0;
      i_idx <= 4'd0;
      j_idx <= 4'd0;
      path_mask_d1 <= 8'b0;
      path_mask_d2 <= 8'b0;
      path_mask_d3 <= 8'b0;
    end else begin
      // Default: hold done one cycle
      done <= done_d1;
      done_d1 <= 1'b0;
      path_mask_d1 <= 8'b0;
      path_mask_d2 <= 8'b0;
      path_mask_d3 <= 8'b0;

      if (start && !active) begin
        // Latch inputs
        n_r <= n;
        m_r <= m;
        edges_r[0][0] <= edges[0][0];
        edges_r[0][1] <= edges[0][1];
        edges_r[1][0] <= edges[1][0];
        edges_r[1][1] <= edges[1][1];
        edges_r[2][0] <= edges[2][0];
        edges_r[2][1] <= edges[2][1];
        edges_r[3][0] <= edges[3][0];
        edges_r[3][1] <= edges[3][1];
        edges_r[4][0] <= edges[4][0];
        edges_r[4][1] <= edges[4][1];
        edges_r[5][0] <= edges[5][0];
        edges_r[5][1] <= edges[5][1];
        edges_r[6][0] <= edges[6][0];
        edges_r[6][1] <= edges[6][1];
        edges_r[7][0] <= edges[7][0];
        edges_r[7][1] <= edges[7][1];
        edges_r[8][0] <= edges[8][0];
        edges_r[8][1] <= edges[8][1];
        edges_r[9][0] <= edges[9][0];
        edges_r[9][1] <= edges[9][1];
        edges_r[10][0] <= edges[10][0];
        edges_r[10][1] <= edges[10][1];
        edges_r[11][0] <= edges[11][0];
        edges_r[11][1] <= edges[11][1];
        edges_r[12][0] <= edges[12][0];
        edges_r[12][1] <= edges[12][1];
        edges_r[13][0] <= edges[13][0];
        edges_r[13][1] <= edges[13][1];
        edges_r[14][0] <= edges[14][0];
        edges_r[14][1] <= edges[14][1];
        edges_r[15][0] <= edges[15][0];
        edges_r[15][1] <= edges[15][1];

        len_low_r[0] <= len_low[0];
        len_low_r[1] <= len_low[1];
        len_low_r[2] <= len_low[2];
        len_low_r[3] <= len_low[3];
        len_low_r[4] <= len_low[4];
        len_low_r[5] <= len_low[5];
        len_low_r[6] <= len_low[6];
        len_low_r[7] <= len_low[7];
        len_low_r[8] <= len_low[8];
        len_low_r[9] <= len_low[9];
        len_low_r[10] <= len_low[10];
        len_low_r[11] <= len_low[11];
        len_low_r[12] <= len_low[12];
        len_low_r[13] <= len_low[13];
        len_low_r[14] <= len_low[14];
        len_low_r[15] <= len_low[15];

        // Enter active computation
        active <= 1'b1;
        cycle_cnt <= 9'd1; // after 1 cycle, k_idx=0,i_idx=0,j_idx=0 iteration runs
        k_idx <= 4'd0;
        i_idx <= 4'd0;
        j_idx <= 4'd0;
        done_d1 <= 1'b0;
      end else if (active) begin
        if (cycle_cnt == 9'd1) begin
          // Initialize dist and pred
          for (integer ii = 0; ii < 8; ii = ii + 1) begin
            for (integer jj = 0; jj < 8; jj = jj + 1) begin
              dist[ii][jj] <= (ii == jj) ? 0 : BIG;
              pred[ii][jj] <= 8'b0;
            end
          end
          // Load edges in the same cycle (read once per edge, steady for this active window)
          for (integer e = 0; e < 16; e = e + 1) begin
            if (e < m_r) begin
              integer a, b, len;
              reg [23:0] concat_len;
              a = edges_r[e][0]; // 1..8
              b = edges_r[e][1]; // 1..8
              if (a >= 1 && a <= 8 && b >= 1 && b <= 8) begin
                a = a - 1;
                b = b - 1;
                concat_len = {edges_r[e][2], len_low_r[e][15:0]}; // 24-bit length
                len = $unsigned(concat_len);
                if (len < dist[a][b]) begin
                  dist[a][b] <= len;
                  dist[b][a] <= len;
                  pred[a][b] <= (1 << b);
                  pred[b][a] <= (1 << a);
                end else if (len == dist[a][b]) begin
                  // tie-breaker: add predecessor to mask
                  pred[a][b] <= pred[a][b] | (1 << b);
                  pred[b][a] <= pred[b][a] | (1 << a);
                end
              end
            end
          end
        end else begin
          // One iteration of Floyd-Warshall per cycle (k outer, i middle, j inner)
          for (integer ii = 0; ii < 8; ii = ii + 1) begin
            for (integer jj = 0; jj < 8; jj = jj + 1) begin
              dist_next[ii][jj] <= dist[ii][jj];
            end
          end

          // Perform one (k,i,j) update
          dist_next[i_idx][j_idx] <= dist[i_idx][j_idx];
          if ((dist[i_idx][k_idx] + dist[k_idx][j_idx]) < dist[i_idx][j_idx]) begin
            dist_next[i_idx][j_idx] <= dist[i_idx][k_idx] + dist[k_idx][j_idx];
            pred[i_idx][j_idx] <= pred[k_idx][j_idx];
          end else if ((dist[i_idx][k_idx] + dist[k_idx][j_idx]) == dist[i_idx][j_idx]) begin
            dist_next[i_idx][j_idx] <= dist[i_idx][j_idx];
            pred[i_idx][j_idx] <= pred[i_idx][j_idx] | pred[k_idx][j_idx];
          end

          for (integer ii = 0; ii < 8; ii = ii + 1) begin
            for (integer jj = 0; jj < 8; jj = jj + 1) begin
              dist[ii][jj] <= dist_next[ii][jj];
            end
          end

          // Advance indices
          j_idx <= j_idx + 1;
          if (j_idx == 7) begin
            j_idx <= 0;
            i_idx <= i_idx + 1;
            if (i_idx == 7) begin
              i_idx <= 0;
              k_idx <= k_idx + 1;
              if (k_idx == 7) begin
                // Completed 8*8*8 = 512 updates; on last update, reconstruction begins
                // Reconstruct path mask: forward (0 -> n-1) and reverse (n-1 -> 0)
                if (n_r >= 1 && n_r <= 8) begin
                  path_mask_d1 <= path_nodes(0, n_r - 1);
                  path_mask_d2 <= rev_path_nodes(0, n_r - 1);
                end
              end
            end
          end
        end

        // Timing: results valid after 256 cycles max.
        // We need one extra cycle to capture the final reconstruction (path masks are ready in cycle 256/257).
        cycle_cnt <= cycle_cnt + 1;
        if (cycle_cnt == 9'd255) begin
          unused_mask <= ~(path_mask_d1 | path_mask_d2);
          done_d1 <= 1'b1;
          active <= 1'b0;
        end
      end
    end
  end

endmodule
