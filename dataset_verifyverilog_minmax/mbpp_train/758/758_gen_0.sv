module list_histogram (
  input clk,
  input rst_n,
  input start,
  input [3:0][7:0] sublists [0:3],
  output reg [3:0][7:0] unique_lists [0:3],
  output reg [2:0] counts [0:3],
  output reg done
);

  timeunit 1ns;
  timeprecision 100ps;

  logic [3:0] sublists_d [0:3];
  logic start_r, start_d;
  logic [1:0] proc_cnt;

  // Register inputs to ease timing (optional but safe)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) sublists_d <= '0;
    else sublists_d <= sublists;
  end

  // Edge detection for start pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_r <= 1'b0;
      start_d <= 1'b0;
    end else begin
      start_r <= start;
      start_d <= start_r;
    end
  end
  logic start_pulse;
  assign start_pulse = start_r && !start_d;

  // Sequential control and processing (4 cycles), done on 5th cycle
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      unique_lists <= '{4{'{4{8'h0}}}};
      counts       <= '{4{3'd0}};
      proc_cnt     <= 2'd0;
      done         <= 1'b0;
    end else begin
      done <= 1'b0; // default for each cycle

      if (start_pulse) begin
        // Start a new 4-cycle processing window
        proc_cnt <= 2'd0;
        done     <= 1'b0;
      end else if (|proc_cnt) begin
        // Parallel comparators across all current unique slots
        logic match[0:3];
        logic has_empty;
        logic [1:0] first_empty;
        logic [1:0] match_idx;

        // Compute matches for all 4 unique slots in parallel
        for (int i = 0; i < 4; i++) begin
          logic all_eq;
          all_eq = 1'b1;
          for (int j = 0; j < 4; j++) begin
            all_eq &= (sublists_d[j] == unique_lists[i][j]);
          end
          match[i] = all_eq;
        end

        // Find first empty slot and first match in parallel
        has_empty = 1'b0;
        first_empty = 2'd0;
        match_idx = 2'd0;
        for (int i = 0; i < 4; i++) begin
          if (!has_empty && counts[i] == 3'd0) begin
            has_empty   = 1'b1;
            first_empty = i;
          end
          if (!match_idx && match[i]) begin
            match_idx = i;
          end
        end

        // Update state for current sublist (proc_cnt points to it)
        if (|match) begin
          // Existing unique: increment count up to 4
          if (counts[match_idx] < 3'd4) begin
            counts[match_idx] <= counts[match_idx] + 1'b1;
          end
        end else begin
          // New unique: store in first empty slot (guaranteed exists by design)
          unique_lists[first_empty] <= sublists_d;
          counts[first_empty]       <= 3'd1;
        end

        // Advance to next sublist (4 cycles total)
        if (proc_cnt < 2'd3) begin
          proc_cnt <= proc_cnt + 1'b1;
          done     <= 1'b0;
        end else begin
          proc_cnt <= 2'd0; // window complete
          done     <= 1'b1; // high on the 5th cycle after start
        end
      end
    end
  end

endmodule
