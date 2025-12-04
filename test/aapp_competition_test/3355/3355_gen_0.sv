module scavenger_hunt(
  input clk, // System clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [10:0] total_time, // Max total time T
  input [10:0] travel_matrix [0:5][0:5], // 6x6 travel times (locations 4=start,5=end)
  input [6:0] p_i [0:3], // Points for tasks 0-3
  input [10:0] t_i [0:3], // Task durations for tasks 0-3
  input [10:0] d_i [0:3], // Task deadlines (0x7FF for no deadline)
  output reg [8:0] max_points, // Maximum possible points (0-400)
  output reg [3:0] task_set, // Optimal task bitmask (bit0=task0)
  output reg done // High when computation completes
);

  // Internal registers
  reg [3:0] combo;                 // current combination index (0..15)
  reg [3:0] best_mask;             // best combination so far
  reg [8:0] best_points;           // best points so far
  reg       running;               // computation in progress
  reg [4:0] cycle_count;           // track cycles after start

  // Pre-declare wires for evaluations
  reg [8:0]  points_sum;
  reg [10:0] time_sum;
  reg        valid_path;
  reg        deadlines_ok;

  integer i;

  // Start/run control and combo generation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      running     <= 1'b0;
      combo       <= 4'd0;
      best_points <= 9'd0;
      best_mask   <= 4'd0;
      max_points  <= 9'd0;
      task_set    <= 4'd0;
      done        <= 1'b0;
      cycle_count <= 5'd0;
    end else begin
      if (start && !running) begin
        // Initialize computation
        running     <= 1'b1;
        combo       <= 4'd0;
        best_points <= 9'd0;
        best_mask   <= 4'd0;
        done        <= 1'b0;
        cycle_count <= 5'd0;
      end else if (running) begin
        // One combo evaluated per cycle using parallel logic (below)
        // Update best based on current combo evaluation results
        if (valid_path && deadlines_ok) begin
          if (points_sum > best_points) begin
            best_points <= points_sum;
            best_mask   <= combo;
          end else if (points_sum == best_points) begin
            // Priority for lex-smaller (numerically smaller) task sets
            if (combo < best_mask) begin
              best_mask <= combo;
            end
          end
        end

        // Advance to next combination
        if (combo == 4'd15) begin
          // After evaluating last combo, latch outputs
          running     <= 1'b0;
          max_points  <= best_points;
          task_set    <= best_mask;
          done        <= 1'b1;
        end else begin
          combo <= combo + 4'd1;
        end

        // Track cycles to align with specification (16 cycles after start)
        if (!done) begin
          if (cycle_count != 5'd31) begin
            cycle_count <= cycle_count + 5'd1;
          end
        end
      end else begin
        // Idle
        done <= 1'b0;
      end
    end
  end

  // Combinational evaluation for current combo
  // Model: simple deterministic route visiting selected tasks in order 0->1->2->3 if chosen
  // Locations: task i at loc i, start at 4, end at 5
  always @* begin
    // Initialize
    points_sum   = 9'd0;
    time_sum     = 11'd0;
    valid_path   = 1'b1;
    deadlines_ok = 1'b1;

    // If not running, default to inert values so sequential logic only uses latched results
    if (!running) begin
      valid_path   = 1'b0;
      deadlines_ok = 1'b0;
    end else begin
      // Start from location 4
      // For each selected task in fixed order 0..3, add travel + duration
      integer cur_loc;
      integer next_loc;
      integer idx;
      reg [10:0] travel;
      reg [10:0] finish_time;

      cur_loc = 4; // start location index

      // Iterate tasks 0..3
      for (idx = 0; idx < 4; idx = idx + 1) begin
        if (combo[idx]) begin
          next_loc = idx; // task location is its index
          travel   = travel_matrix[cur_loc][next_loc];

          // Check for overflow beyond total_time early (optional pruning)
          if (time_sum + travel > total_time) begin
            valid_path = 1'b0;
          end

          time_sum = time_sum + travel;

          // Add task duration
          if (time_sum + t_i[idx] > total_time) begin
            valid_path = 1'b0;
          end

          time_sum = time_sum + t_i[idx];

          // Deadline check (0x7FF indicates no deadline)
          finish_time = time_sum;
          if (d_i[idx] != 11'h7FF) begin
            if (finish_time > d_i[idx]) begin
              deadlines_ok = 1'b0;
            end
          end

          // Accumulate points regardless; filtered by valid_path & deadlines_ok later
          points_sum = points_sum + p_i[idx];

          // Move current location
          cur_loc = next_loc;
        end
      end

      // Finally, travel from last location (cur_loc) to end location 5
      travel = travel_matrix[cur_loc][5];
      if (time_sum + travel > total_time) begin
        valid_path = 1'b0;
      end
      time_sum = time_sum + travel;
    end
  end

endmodule