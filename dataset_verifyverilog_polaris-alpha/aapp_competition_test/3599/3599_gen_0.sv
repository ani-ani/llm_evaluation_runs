module break_scheduler(
  input clk,
  input rst_n,
  input start,
  input [3:0] T,
  input [2:0] N,
  input [4:0][3:0] breaks,
  output reg [4:0][3:0] start_times,
  output reg done
);

  // Latched inputs/parameters
  reg [3:0] T_reg;
  reg [2:0] N_reg;
  reg [4:0][3:0] breaks_reg;

  // Internal schedule storage
  reg [4:0][3:0] st;

  // Cycle counter to track latency from start
  reg [3:0] cycle_cnt;

  // Edge detect for start
  reg start_d;
  wire start_pulse = start & ~start_d;

  integer i;

  // Combinational function to count active breaks at a given time
  function automatic [2:0] active_count;
    input [3:0] t;
    input [2:0] N_loc;
    input [4:0][3:0] st_loc;
    input [4:0][3:0] br_loc;
    integer j;
    reg [2:0] cnt;
  begin
    cnt = 3'd0;
    for (j = 0; j < 5; j = j + 1) begin
      if (j < N_loc) begin
        if ((t >= st_loc[j]) && (t < st_loc[j] + br_loc[j])) begin
          cnt = cnt + 3'd1;
        end
      end
    end
    active_count = cnt;
  end
  endfunction

  // Sequential control and scheduling
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d    <= 1'b0;
      cycle_cnt  <= 4'd0;
      done       <= 1'b0;
      T_reg      <= 4'd0;
      N_reg      <= 3'd0;
      breaks_reg <= '{default:4'd0};
      st         <= '{default:4'd0};
      start_times<= '{default:4'd0};
    end else begin
      // Capture previous start for edge detection
      start_d <= start;

      // On start pulse: latch inputs, clear counter and done, compute schedule
      if (start_pulse) begin
        T_reg      <= T;
        N_reg      <= N;
        breaks_reg <= breaks;
        cycle_cnt  <= 4'd0;
        done       <= 1'b0;

        // Initialize start times to zero
        for (i = 0; i < 5; i = i + 1) begin
          st[i] <= 4'd0;
        end
      end else if (!done && (cycle_cnt < 4'd10)) begin
        // Increment cycle counter while computing / waiting
        cycle_cnt <= cycle_cnt + 4'd1;
      end

      // Perform scheduling immediately after latching inputs (combinational-style inside clocked block)
      // This ensures computation completes within the fixed latency window.
      if (start_pulse) begin
        integer m;
        integer t;
        reg placed;
        reg [2:0] cnt;

        // For each musician up to N_reg, find earliest feasible start time
        for (m = 0; m < 5; m = m + 1) begin
          if (m < N) begin
            placed = 1'b0;
            // default if no placement possible (should not occur for valid inputs)
            st[m] = 4'd0;

            for (t = 0; t < 16; t = t + 1) begin
              if (!placed) begin
                // Check fits within concert length
                if (t + breaks[m] <= T) begin
                  // Temporarily consider st[m] = t and compute active count window
                  integer tt;
                  reg ok;
                  ok = 1'b1;

                  for (tt = t; tt < t + breaks[m]; tt = tt + 1) begin
                    reg [2:0] acc;
                    reg [4:0][3:0] tmp_st;
                    integer k;

                    // Build temporary start-times: existing assigned plus candidate
                    for (k = 0; k < 5; k = k + 1) begin
                      if (k < m)
                        tmp_st[k] = st[k];
                      else if (k == m)
                        tmp_st[k] = t[3:0];
                      else
                        tmp_st[k] = 4'd0;
                    end

                    acc = active_count(tt[3:0], N, tmp_st, breaks);
                    if (acc > 3'd2) begin
                      ok = 1'b0;
                    end
                  end

                  if (ok) begin
                    st[m] = t[3:0];
                    placed = 1'b1;
                  end
                end
              end
            end
          end else begin
            st[m] = 4'd0;
          end
        end
      end

      // At exactly 10 cycles after start, drive outputs and assert done.
      // cycle_cnt starts at 0 on start_pulse, so when it reaches 9 we are at 10th cycle.
      if (!done && (cycle_cnt == 4'd9)) begin
        start_times <= st;
        done        <= 1'b1;
      end

    end
  end

endmodule