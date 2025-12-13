module transport_switch_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] t,
  input [2:0] n,
  input [31:0] min_dists [0:3],
  input [31:0] max_angles [0:3],
  input [31:0] dists [0:7],
  input [31:0] angles [0:7],
  output reg [3:0] switch_count,
  output reg done
);

  // Internal DP state
  reg [3:0] dp_switches [0:7];      // minimal switches to reach point i
  reg       dp_used_t  [0:7][0:3];  // dp_used_t[i][k]: transport k used on last segment ending at i
  reg       dp_valid   [0:7];       // reachability of point i

  // Control
  reg [3:0] iter_i;                 // 0..7 current end point index
  reg [3:0] iter_j;                 // 0..7 current start point index
  reg [1:0] iter_k;                 // 0..3 current transport index
  reg [1:0] state;

  localparam S_IDLE  = 2'd0;
  localparam S_INIT  = 2'd1;
  localparam S_DP    = 2'd2;
  localparam S_DONE  = 2'd3;

  // Segment accumulators for j->i
  reg [31:0] seg_dist;
  reg [31:0] seg_min_angle;
  reg [31:0] seg_max_angle;

  // Best candidate tracking for current (i,j)
  reg        cand_found;
  reg [3:0]  cand_switches;
  reg [1:0]  cand_transport;

  // Helper: large number for initialization
  localparam [3:0] INF_SW = 4'd15;

  integer x, y;

  // Combinational: compute segment properties for current (j,i)
  // and determine if each transport is valid; choose best for this (i,j)
  reg [31:0] dist_sum;
  reg [31:0] ang_min;
  reg [31:0] ang_max;
  reg [1:0]  best_k_for_j;
  reg        best_valid_for_j;
  reg [3:0]  best_sw_for_j;

  always @* begin
    // Default
    dist_sum = 32'd0;
    ang_min  = 32'h7FFFFFFF;
    ang_max  = 32'h80000000;

    // Only compute if indices are meaningful
    if (iter_i > iter_j) begin
      // Sum distances dists[j .. i-1] and angle stats angles[j .. i-1]
      for (x = 0; x < 8; x = x + 1) begin
        if ((x >= iter_j) && (x < iter_i)) begin
          dist_sum = dist_sum + dists[x];
          if (angles[x] < ang_min) ang_min = angles[x];
          if (angles[x] > ang_max) ang_max = angles[x];
        end
      end
    end else begin
      // No segment
      dist_sum = 32'd0;
      ang_min  = 32'h7FFFFFFF;
      ang_max  = 32'h80000000;
    end

    best_valid_for_j = 1'b0;
    best_sw_for_j    = INF_SW;
    best_k_for_j     = 2'd0;

    if ((iter_i > iter_j) && dp_valid[iter_j]) begin
      // Evaluate all transports in parallel (looped combinationally)
      for (y = 0; y < 4; y = y + 1) begin
        reg valid_t;
        reg [3:0] sw_inc;
        reg [3:0] total_sw;
        valid_t = 1'b0;
        sw_inc  = 4'd0;
        total_sw = INF_SW;

        // Check constraints
        if ((dist_sum >= min_dists[y]) && (ang_max != 32'h80000000)) begin
          if ((ang_max - ang_min) <= max_angles[y]) begin
            valid_t = 1'b1;
          end
        end

        if (valid_t) begin
          // Switch increment: 0 if same as previous segment's transport, else 1
          if (dp_used_t[iter_j][y]) begin
            sw_inc = 4'd0;
          end else begin
            // For start segment (j==0), if no previous transport used, this counts as 0 switches
            // Implemented by checking if any dp_used_t[0][*] is set when j==0
            if (iter_j == 0) begin
              reg any_prev;
              integer kk;
              any_prev = 1'b0;
              for (kk = 0; kk < 4; kk = kk + 1) begin
                if (dp_used_t[0][kk]) any_prev = 1'b1;
              end
              if (!any_prev) sw_inc = 4'd0; else sw_inc = 4'd1;
            end else begin
              sw_inc = 4'd1;
            end
          end

          if (dp_switches[iter_j] != INF_SW) begin
            total_sw = dp_switches[iter_j] + sw_inc;
          end

          // Pick best (min switches), tie-breaker: prefer given input t transport
          if (total_sw < best_sw_for_j) begin
            best_sw_for_j    = total_sw;
            best_k_for_j     = y[1:0];
            best_valid_for_j = 1'b1;
          end else if (total_sw == best_sw_for_j && best_valid_for_j) begin
            // Tie-break: prefer selected transport t
            if (y[1:0] == t && best_k_for_j != t) begin
              best_k_for_j = y[1:0];
            end
          end
        end
      end
    end
  end

  // Sequential control and DP update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      switch_count <= 4'd0;
      done         <= 1'b0;
      state        <= S_IDLE;
      iter_i       <= 4'd0;
      iter_j       <= 4'd0;
      iter_k       <= 2'd0;
      for (x = 0; x < 8; x = x + 1) begin
        dp_switches[x] <= INF_SW;
        dp_valid[x]    <= 1'b0;
        for (y = 0; y < 4; y = y + 1) begin
          dp_used_t[x][y] <= 1'b0;
        end
      end
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize DP for new computation
            for (x = 0; x < 8; x = x + 1) begin
              dp_switches[x] <= INF_SW;
              dp_valid[x]    <= 1'b0;
              for (y = 0; y < 4; y = y + 1) begin
                dp_used_t[x][y] <= 1'b0;
              end
            end
            // Starting point index 0
            dp_switches[0] <= 4'd0;
            dp_valid[0]    <= 1'b1;
            iter_i         <= 4'd1; // next point
            iter_j         <= 4'd0;
            state          <= S_DP;
          end
        end

        S_DP: begin
          // Process DP for current (iter_i, iter_j)
          if (iter_i < n) begin
            // For current i, examine candidate from j using combinational results
            if ((iter_i > iter_j) && best_valid_for_j) begin
              // Update candidate for dp[i]
              if (!dp_valid[iter_i] || (best_sw_for_j < dp_switches[iter_i])) begin
                dp_switches[iter_i] <= best_sw_for_j;
                dp_valid[iter_i]    <= 1'b1;
                // Clear previous transports and set chosen one
                for (x = 0; x < 4; x = x + 1) begin
                  dp_used_t[iter_i][x] <= 1'b0;
                end
                dp_used_t[iter_i][best_k_for_j] <= 1'b1;
              end else if (best_sw_for_j == dp_switches[iter_i]) begin
                // Allow multiple transports with same minimal switches
                dp_used_t[iter_i][best_k_for_j] <= 1'b1;
                dp_valid[iter_i]               <= 1'b1;
              end
            end

            // Move to next j or advance i
            if (iter_j + 1 < iter_i) begin
              iter_j <= iter_j + 1'b1;
            end else begin
              // Finished all j for this i, move to next i
              iter_i <= iter_i + 1'b1;
              iter_j <= 4'd0;
            end

          end else begin
            // All i processed
            state <= S_DONE;
          end
        end

        S_DONE: begin
          // Final result at point n-1
          if (n == 0 || n == 1) begin
            // No travel needed
            switch_count <= 4'd0;
          end else if (dp_valid[n-1] && dp_switches[n-1] != INF_SW) begin
            switch_count <= dp_switches[n-1];
          end else begin
            switch_count <= 4'd15; // IMPOSSIBLE
          end
          done  <= 1'b1;
          // Wait for next start; can go back to IDLE when start deasserted then asserted again
          if (!start) begin
            state <= S_IDLE;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule