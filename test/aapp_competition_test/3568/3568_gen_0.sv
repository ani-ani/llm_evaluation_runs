module floppy_organ_scheduler(
  input clk,
  input rst_n,
  input start,
  input [1:0] f,
  input [15:0] t_0,
  input [1:0] n_0,
  input [15:0] intervals_0 [0:7],
  input [15:0] t_1,
  input [1:0] n_1,
  input [15:0] intervals_1 [0:7],
  input [15:0] t_2,
  input [1:0] n_2,
  input [15:0] intervals_2 [0:7],
  output reg possible,
  output reg done
);

  // State encoding
  localparam IDLE           = 3'd0;
  localparam CHECK_FREQ     = 3'd1;
  localparam CHECK_INTERVAL = 3'd2;
  localparam VERIFY_PAUSE   = 3'd3;
  localparam DONE           = 3'd4;

  reg [2:0] state, next_state;

  // Global cycle counter for done timing: done after (10 + 20*f)
  reg [7:0] cycle_cnt;
  reg [7:0] done_target;

  // Frequency index (0..2)
  reg [1:0] cur_freq;

  // Working parameters for current frequency
  reg [15:0] cur_t;
  reg [1:0]  cur_n;

  // Interval index (0..cur_n-1)
  reg [2:0] int_idx;

  // For comparisons
  reg [15:0] start_cur, end_cur;
  reg [15:0] start_prev, end_prev;

  // Local flags
  reg all_ok;        // remains 1 if all frequencies valid
  reg freq_ok;       // current frequency validity

  // Helper: select current frequency parameters
  always @(*) begin
    case (cur_freq)
      2'd0: begin
        cur_t = t_0;
        cur_n = (n_0 == 2'd0) ? 2'd0 : n_0; // use as-is, assume 1-4 when active
      end
      2'd1: begin
        cur_t = t_1;
        cur_n = (n_1 == 2'd0) ? 2'd0 : n_1;
      end
      default: begin
        cur_t = t_2;
        cur_n = (n_2 == 2'd0) ? 2'd0 : n_2;
      end
    endcase
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_FREQ;
        end
      end

      CHECK_FREQ: begin
        // If current frequency index exceeds f-1, we are done checking
        if (cur_freq >= f) begin
          next_state = DONE;
        end else begin
          // Start checking intervals for this frequency
          next_state = CHECK_INTERVAL;
        end
      end

      CHECK_INTERVAL: begin
        // After verifying ordering and non-overlap for all intervals,
        // move to VERIFY_PAUSE
        next_state = VERIFY_PAUSE;
      end

      VERIFY_PAUSE: begin
        // After pause/direction constraint check, proceed to next freq or done
        if (cur_freq + 1 >= f) begin
          next_state = DONE;
        end else begin
          next_state = CHECK_FREQ;
        end
      end

      DONE: begin
        // Stay in DONE; done signal controlled by cycle counter vs target
        next_state = DONE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      cycle_cnt  <= 8'd0;
      done_target<= 8'd0;
      cur_freq   <= 2'd0;
      int_idx    <= 3'd0;
      all_ok     <= 1'b0;
      freq_ok    <= 1'b0;
      possible   <= 1'b0;
      done       <= 1'b0;
    end else begin
      state <= next_state;

      // Default: increment cycle counter if started
      if (state != IDLE || start) begin
        cycle_cnt <= cycle_cnt + 8'd1;
      end else begin
        cycle_cnt <= 8'd0;
      end

      case (state)
        IDLE: begin
          done       <= 1'b0;
          possible   <= 1'b0;
          all_ok     <= 1'b1; // assume ok until proven otherwise
          cur_freq   <= 2'd0;
          int_idx    <= 3'd0;
          // Precompute done_target based on f
          done_target <= 8'd10 + (8'd20 * {6'd0, f});
        end

        CHECK_FREQ: begin
          // At entry to CHECK_FREQ, freq_ok defaults to 1 for the frequency
          freq_ok <= 1'b1;
          int_idx <= 3'd0;
        end

        CHECK_INTERVAL: begin
          // Interval checks for current frequency
          // Conditions:
          // - If cur_n == 0: invalid (must be 1-4). Mark freq_ok=0.
          // - Intervals are in pairs: [0]=start0,[1]=end0,[2]=start1,[3]=end1,...
          // - For each i: start < end
          // - Strictly ascending, non-overlapping: start_i > end_{i-1}
          // - No internal pauses required beyond gaps between intervals.

          if (cur_n == 2'd0) begin
            freq_ok <= 1'b0;
          end else begin
            // Check all intervals
            // We will iterate combinationally using direct array reads
            // and encode failures into freq_ok.
            freq_ok <= 1'b1;

            // Interval 0
            if (cur_freq == 2'd0) begin
              start_cur = intervals_0[0];
              end_cur   = intervals_0[1];
            end else if (cur_freq == 2'd1) begin
              start_cur = intervals_1[0];
              end_cur   = intervals_1[1];
            end else begin
              start_cur = intervals_2[0];
              end_cur   = intervals_2[1];
            end

            if (!(start_cur < end_cur)) begin
              freq_ok <= 1'b0;
            end

            // Remaining intervals if any
            if (cur_n > 2'd1) begin
              integer j;
              for (j = 1; j < 4; j = j + 1) begin
                if (j < cur_n) begin
                  if (cur_freq == 2'd0) begin
                    start_cur = intervals_0[j*2];
                    end_cur   = intervals_0[j*2+1];
                    start_prev= intervals_0[(j-1)*2];
                    end_prev  = intervals_0[(j-1)*2+1];
                  end else if (cur_freq == 2'd1) begin
                    start_cur = intervals_1[j*2];
                    end_cur   = intervals_1[j*2+1];
                    start_prev= intervals_1[(j-1)*2];
                    end_prev  = intervals_1[(j-1)*2+1];
                  end else begin
                    start_cur = intervals_2[j*2];
                    end_cur   = intervals_2[j*2+1];
                    start_prev= intervals_2[(j-1)*2];
                    end_prev  = intervals_2[(j-1)*2+1];
                  end

                  // Each interval must have start < end
                  if (!(start_cur < end_cur)) begin
                    freq_ok <= 1'b0;
                  end
                  // Strictly ascending, non-overlapping: start_j > end_{j-1}
                  if (!(start_cur > end_prev)) begin
                    freq_ok <= 1'b0;
                  end
                end
              end
            end
          end
        end

        VERIFY_PAUSE: begin
          // Consider movement constraints:
          // - Sweep time between extremes = cur_t.
          // - Must reverse at endpoints with 1fs pause on direction change.
          // Simplified conservative check:
          //   Ensure that between consecutive intervals there is at least 1 unit
          //   of gap to host the mandatory pause when direction changes.
          //   If any two consecutive intervals are directly adjacent
          //   (start_i == end_{i-1} + 0), treat as invalid.

          if (freq_ok) begin
            if (cur_n > 2'd1) begin
              integer k;
              for (k = 1; k < 4; k = k + 1) begin
                if (k < cur_n) begin
                  if (cur_freq == 2'd0) begin
                    start_cur = intervals_0[k*2];
                    end_prev  = intervals_0[(k-1)*2+1];
                  end else if (cur_freq == 2'd1) begin
                    start_cur = intervals_1[k*2];
                    end_prev  = intervals_1[(k-1)*2+1];
                  end else begin
                    start_cur = intervals_2[k*2];
                    end_prev  = intervals_2[(k-1)*2+1];
                  end

                  // Require at least 1 time unit pause for potential direction change
                  if (start_cur <= end_prev) begin
                    freq_ok <= 1'b0;
                  end
                end
              end
            end

            // Additional simple feasibility: at least one full sweep fits in intervals span
            // (very conservative; ensures movement at given period is plausible)
            if (freq_ok && cur_n != 2'd0) begin
              if (cur_freq == 2'd0) begin
                start_cur = intervals_0[0];
                end_cur   = intervals_0[(cur_n*2)-1];
              end else if (cur_freq == 2'd1) begin
                start_cur = intervals_1[0];
                end_cur   = intervals_1[(cur_n*2)-1];
              end else begin
                start_cur = intervals_2[0];
                end_cur   = intervals_2[(cur_n*2)-1];
              end
              if ((end_cur - start_cur) < cur_t) begin
                freq_ok <= 1'b0;
              end
            end
          end

          // Update global all_ok based on this frequency
          if (!freq_ok) begin
            all_ok <= 1'b0;
          end

          // Move to next frequency index (if any)
          if (cur_freq + 1 < f) begin
            cur_freq <= cur_freq + 2'd1;
          end
        end

        DONE: begin
          // Set possible based on all_ok once; stable afterwards
          possible <= all_ok;
          // done asserted only when cycle_cnt reaches or exceeds target
          if (cycle_cnt >= done_target) begin
            done <= 1'b1;
          end
        end

        default: ;
      endcase
    end
  end

endmodule