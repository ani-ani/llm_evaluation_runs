module ski_path_finder(
  input clk,
  input rst_n,
  input start,
  input [1:0] num_cabins,
  input [2:0] num_pistes,
  input [287:0] adjacency_input,
  output reg [127:0] results,
  output reg done
);

  // Parameters
  localparam ONE_Q16_16 = 32'h00010000;

  // Internal storage for adjacency matrix (4x4 of 32-bit fall probabilities)
  // adj[a][b] = probability of fall when going from a to b (Q16.16)
  reg [31:0] adj [0:3][0:3];

  // Latency counter (20-cycle fixed latency)
  reg [4:0] cycle_cnt;
  reg       active;

  // State DP: max survival probabilities for (cabin, walks_used)
  // walks_used: 0..3 (encoded in 2 bits)
  // We keep 2 banks: prev and next for relaxation
  reg [31:0] dp_prev [0:3][0:3];
  reg [31:0] dp_next [0:3][0:3];

  integer i, j, w;

  // Unpack adjacency_input into adj matrix on start
  // adjacency_input layout (row-major):
  // [ (0,0), (0,1), (0,2), (0,3), (1,0), ..., (3,3) ], each 32 bits
  // Index: idx = (row*4 + col)
  task load_adjacency;
    integer r, c, idx;
    begin
      for (r = 0; r < 4; r = r + 1) begin
        for (c = 0; c < 4; c = c + 1) begin
          idx = (r*4 + c);
          adj[r][c] = adjacency_input[32*idx +: 32];
        end
      end
    end
  endtask

  // Initialize dp_prev with starting conditions
  // Assumption: start from cabin 0 with 0 walks_used, probability 1.0
  task init_dp;
    integer c, wt;
    begin
      for (c = 0; c < 4; c = c + 1) begin
        for (wt = 0; wt < 4; wt = wt + 1) begin
          dp_prev[c][wt] = 32'd0;
        end
      end
      dp_prev[0][0] = ONE_Q16_16; // starting point
    end
  endtask

  // One relaxation step over all states
  // - Only cabins < num_cabins are considered; others forced to 0
  // - For each state (c, w), propagate via:
  //   (1) Ski edges (forward direction c->d) if d < num_cabins
  //       surv = dp_prev[c][w] * (1 - fall_prob[c][d])
  //   (2) Walk edges (reverse direction d->c) with 0% fall, cost in walks_used (+1)
  //       surv = dp_prev[d][w-1] (if w>0) allows moving "back" without loss
  // We do max over all ways to reach each (c, w).
  function [31:0] max32(input [31:0] a, input [31:0] b);
    begin
      max32 = (a >= b) ? a : b;
    end
  endfunction

  task relax_step;
    integer c, d, w_in, w_out;
    reg [31:0] new_dp [0:3][0:3];
    reg [31:0] base, surv, fallp, one_minus;
    begin
      // Initialize next DP to zero
      for (c = 0; c < 4; c = c + 1) begin
        for (w_in = 0; w_in < 4; w_in = w_in + 1) begin
          new_dp[c][w_in] = 32'd0;
        end
      end

      // Ignore cabins >= num_cabins by keeping them zero

      // Ski edges: forward direction with fall probability
      for (c = 0; c < 4; c = c + 1) begin
        if (c < num_cabins) begin
          for (w_in = 0; w_in < 4; w_in = w_in + 1) begin
            base = dp_prev[c][w_in];
            if (base != 32'd0) begin
              for (d = 0; d < 4; d = d + 1) begin
                if (d < num_cabins) begin
                  fallp = adj[c][d];
                  one_minus = ONE_Q16_16 - fallp;
                  // Q16.16 multiply: (base * one_minus) >> 16
                  surv = ( (base * one_minus) >> 16 );
                  if (surv > new_dp[d][w_in]) begin
                    new_dp[d][w_in] = surv;
                  end
                end
              end
            end
          end
        end
      end

      // Walk edges: reverse direction, 0% fall, consumes one walk
      // From dp_prev[d][w_in] we can reach c=d? No, walking allows reverse: c<-d
      // So to reach (c, w_out), we can come from any (d, w_out-1) where an edge c->d exists
      // but walking is zero-fall, so probability is unchanged.
      for (c = 0; c < 4; c = c + 1) begin
        if (c < num_cabins) begin
          for (w_out = 1; w_out < 4; w_out = w_out + 1) begin
            for (d = 0; d < 4; d = d + 1) begin
              if (d < num_cabins) begin
                // Use existence of piste between c and d in either direction as walk path basis
                // We check if there is any piste (non-zero fall prob treated as existence)
                if (adj[c][d] != 32'd0 || adj[d][c] != 32'd0) begin
                  base = dp_prev[d][w_out-1];
                  if (base > new_dp[c][w_out]) begin
                    new_dp[c][w_out] = base;
                  end
                end
              end
            end
          end
        end
      end

      // Write back
      for (c = 0; c < 4; c = c + 1) begin
        for (w_in = 0; w_in < 4; w_in = w_in + 1) begin
          dp_next[c][w_in] = new_dp[c][w_in];
        end
      end
    end
  endtask

  // Final aggregation into results:
  // For each k=0..3: results[k] = max over walks_used of dp_prev[k][w]
  // If k >= num_cabins, result is 0.
  task build_results;
    integer c, wt;
    reg [31:0] best;
    begin
      for (c = 0; c < 4; c = c + 1) begin
        if (c < num_cabins) begin
          best = 32'd0;
          for (wt = 0; wt < 4; wt = wt + 1) begin
            best = max32(best, dp_prev[c][wt]);
          end
          results[c*32 +: 32] = best;
        end else begin
          results[c*32 +: 32] = 32'd0;
        end
      end
    end
  end
  endtask

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done      <= 1'b0;
      active    <= 1'b0;
      cycle_cnt <= 5'd0;
      results   <= 128'd0;
      // Clear DP and adjacency
      for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          adj[i][j]     <= 32'd0;
          dp_prev[i][j] <= 32'd0;
          dp_next[i][j] <= 32'd0;
        end
      end
    end else begin
      if (start && !active) begin
        // Latch adjacency and initialize DP at start
        load_adjacency();
        init_dp();
        cycle_cnt <= 5'd0;
        active    <= 1'b1;
        done      <= 1'b0;
      end else if (active) begin
        cycle_cnt <= cycle_cnt + 5'd1;

        // Perform relaxations for cycles 0..17 (18 iterations as example)
        // Then finalize at cycle 19, assert done at cycle 20 boundary.
        if (cycle_cnt < 5'd18) begin
          relax_step();
          // swap dp_prev and dp_next
          for (i = 0; i < 4; i = i + 1) begin
            for (w = 0; w < 4; w = w + 1) begin
              dp_prev[i][w] <= dp_next[i][w];
            end
          end
        end else if (cycle_cnt == 5'd18) begin
          // Build results from current dp_prev
          build_results();
        end else if (cycle_cnt == 5'd19) begin
          done   <= 1'b1;
          active <= 1'b0;
        end
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule