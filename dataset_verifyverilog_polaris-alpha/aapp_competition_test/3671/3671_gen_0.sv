module job_scheduler(
  input clk,
  input rst_n,
  input start,
  input [2:0] job_count,
  input [31:0] job_times [7:0],
  output reg [5:0] total_cookies,
  output reg done
);

  // Internal storage for job times (sorted subset)
  reg [31:0] times_reg [7:0];
  reg [31:0] sorted_times [7:0];

  // DP arrays
  reg [5:0] max_cookies [7:0];        // max cookies including jobs up to i
  reg [2:0] compat_idx  [7:0];        // precomputed latest compatible job index for each i

  // Control
  reg [6:0] cycle_cnt;               // up to >= 80
  reg [2:0] n_jobs;                  // latched job count (1-8)
  reg busy;

  // Local params
  localparam LAT_SORT_END    = 7'd9;   // cycles 0-9 for sort (10 cycles total, using 0-based count)
  localparam LAT_COMPAT_END  = 7'd17;  // cycles 10-17 for compat precompute (8 cycles)
  localparam LAT_DP_END      = 7'd25;  // cycles 18-25 for DP core (8 cycles)
  localparam LAT_MARGIN_END  = 7'd79;  // cycles up to 79, done at 80th cycle (0-based)
  localparam COOKIE_PER_JOB  = 6'd4;
  localparam [31:0] DUR      = 32'd400000;

  integer i, j;

  // Main sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt      <= 7'd0;
      n_jobs         <= 3'd0;
      busy           <= 1'b0;
      total_cookies  <= 6'd0;
      done           <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        times_reg[i]    <= 32'd0;
        sorted_times[i] <= 32'd0;
        max_cookies[i]  <= 6'd0;
        compat_idx[i]   <= 3'd0;
      end
    end else begin
      // Default: keep outputs stable
      done <= 1'b0;

      // Start pulse handling
      if (start && !busy) begin
        busy          <= 1'b1;
        cycle_cnt     <= 7'd0;
        n_jobs        <= (job_count == 3'd0) ? 3'd1 : job_count; // ensure >=1 per spec

        // Latch inputs
        for (i = 0; i < 8; i = i + 1) begin
          times_reg[i]    <= job_times[i];
          sorted_times[i] <= job_times[i];
          max_cookies[i]  <= 6'd0;
          compat_idx[i]   <= 3'd0;
        end
      end else if (busy) begin
        cycle_cnt <= cycle_cnt + 7'd1;

        // 1) Sorting phase: simple bubble sort over first n_jobs entries
        // Perform one bubble pass per cycle for simplicity; only first n_jobs elements are relevant.
        if (cycle_cnt <= LAT_SORT_END) begin
          // Bubble one pass
          for (i = 0; i < 7; i = i + 1) begin
            if (i < n_jobs-1) begin
              if (sorted_times[i] > sorted_times[i+1]) begin
                // swap
                {sorted_times[i], sorted_times[i+1]} <= {sorted_times[i+1], sorted_times[i]};
              end
            end
          end
        end

        // 2) Precompute compatibility indices (parallel comparators style, but iterated each cycle by i)
        // Use cycles 10-17 (8 cycles) to compute compat_idx for each job index i.
        if (cycle_cnt >= (LAT_SORT_END + 1) && cycle_cnt <= LAT_COMPAT_END) begin
          // Map cycle to job index
          i = cycle_cnt - (LAT_SORT_END + 1);
          if (i < n_jobs) begin
            // Find largest j < i such that sorted_times[i] >= sorted_times[j] + DUR
            compat_idx[i] <= 3'd0;
            for (j = 0; j < 8; j = j + 1) begin
              if (j < i) begin
                if (sorted_times[i] >= sorted_times[j] + DUR) begin
                  compat_idx[i] <= j[2:0];
                end
              end
            end
          end
        end

        // 3) DP phase (weighted interval-like scheduling with uniform 4 cookies)
        // Use cycles 18-25 (8 cycles) to compute max_cookies[i].
        if (cycle_cnt >= (LAT_COMPAT_END + 1) && cycle_cnt <= LAT_DP_END) begin
          i = cycle_cnt - (LAT_COMPAT_END + 1);
          if (i < n_jobs) begin
            if (i == 0) begin
              // Base case: either take job 0 (4 cookies) or 0; taking is always better
              max_cookies[0] <= COOKIE_PER_JOB;
            end else begin
              // Compute include and exclude
              // include_val = 4 + max_cookies[compat_idx[i]] (if compatible)
              // exclude_val = max_cookies[i-1]
              reg [5:0] include_val;
              reg [5:0] exclude_val;
              include_val = COOKIE_PER_JOB + max_cookies[compat_idx[i]];
              exclude_val = max_cookies[i-1];
              max_cookies[i] <= (include_val > exclude_val) ? include_val : exclude_val;
            end
          end
        end

        // 4) Margin and finalize result
        if (cycle_cnt == LAT_MARGIN_END) begin
          // Result from last valid job index n_jobs-1
          if (n_jobs != 3'd0)
            total_cookies <= max_cookies[n_jobs-1];
          else
            total_cookies <= 6'd0;
          done <= 1'b1;
          busy <= 1'b0;
        end
      end
    end
  end

endmodule