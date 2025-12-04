module median_calculator(
  input  logic              clk,
  input  logic              rst_n,
  input  logic [3:0]        n,
  input  logic signed [7:0][15:0] data,
  input  logic              start_trig,
  output logic signed [15:0] result,
  output logic              done
);

  // Internal registers
  logic [3:0]                n_reg;
  logic signed [15:0]        arr      [7:0];
  logic signed [15:0]        sort_arr [7:0];

  logic [2:0]                cycle_cnt;
  logic                      busy;

  // Sorting indices
  integer i, j;

  // Latched start pulse
  logic start_pend;

  // Sequential control and datapath
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_reg      <= 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        arr[i]      <= '0;
        sort_arr[i] <= '0;
      end
      cycle_cnt <= 3'd0;
      busy      <= 1'b0;
      done      <= 1'b0;
      result    <= 16'sd0;
      start_pend <= 1'b0;
    end else begin
      // Latch start trigger (single-cycle pulse expected; pending if busy)
      if (start_trig && !busy && !start_pend) begin
        start_pend <= 1'b1;
      end

      // Start operation on pending start when not busy
      if (start_pend && !busy) begin
        // Capture n (limit to max 8, min 1)
        if (n == 4'd0)
          n_reg <= 4'd1;
        else if (n > 4'd8)
          n_reg <= 4'd8;
        else
          n_reg <= n;

        // Capture input data into working array
        for (i = 0; i < 8; i = i + 1) begin
          arr[i] <= data[i];
        end

        cycle_cnt <= 3'd0;
        busy      <= 1'b1;
        done      <= 1'b0;
        result    <= 16'sd0;
        start_pend <= 1'b0;
      end else if (busy) begin
        // Fixed-latency pipeline: perform operations over 8 cycles
        cycle_cnt <= cycle_cnt + 3'd1;

        // Simple bubble sort executed iteratively each cycle
        // For small N<=8 and fixed 8-cycle latency, we can perform
        // a full bubble sort by iterating comparisons each cycle.

        // Copy arr to sort_arr at first cycle of busy
        if (cycle_cnt == 3'd0) begin
          for (i = 0; i < 8; i = i + 1) begin
            sort_arr[i] <= arr[i];
          end
        end else begin
          // Perform one bubble-sort pass segment per cycle
          // This is a simple iterative approach; in 7 cycles we
          // can complete sorting for up to 8 elements.
          for (i = 0; i < 7; i = i + 1) begin
            if (i < n_reg-1) begin
              if (sort_arr[i] > sort_arr[i+1]) begin
                // swap
                logic signed [15:0] tmp;
                tmp             = sort_arr[i];
                sort_arr[i]     <= sort_arr[i+1];
                sort_arr[i+1]   <= tmp;
              end
            end
          end
        end

        // On final (8th) cycle, compute median and assert done
        if (cycle_cnt == 3'd7) begin
          // n_eff: ensure within 1..8 (already clamped into n_reg)
          logic [3:0] n_eff;
          n_eff = n_reg;

          if (n_eff[0] == 1'b1) begin
            // Odd n: median is middle element at index (n-1)/2
            logic [2:0] mid_idx;
            mid_idx = (n_eff - 4'd1) >> 1;
            result  <= sort_arr[mid_idx];
          end else begin
            // Even n: median is average of two middle elements with rounding
            // mid indices: (n/2 - 1) and (n/2)
            logic [2:0] mid1_idx, mid2_idx;
            logic signed [16:0] sum17;
            logic signed [15:0] avg;
            mid1_idx = (n_eff >> 1) - 1;
            mid2_idx = (n_eff >> 1);
            sum17 = $signed({sort_arr[mid1_idx][15], sort_arr[mid1_idx]}) +
                    $signed({sort_arr[mid2_idx][15], sort_arr[mid2_idx]});
            // Round-to-nearest for signed division by 2
            if (sum17 >= 0)
              avg = (sum17 + 17'sd1) >>> 1;
            else
              avg = (sum17 - 17'sd1) >>> 1;
            result <= avg;
          end

          done      <= 1'b1;
          busy      <= 1'b0;
          cycle_cnt <= 3'd0;
        end else begin
          done <= 1'b0;
        end
      end else begin
        // Idle state, ensure done deasserted unless just completed
        if (!start_pend)
          done <= 1'b0;
      end
    end
  end

endmodule
