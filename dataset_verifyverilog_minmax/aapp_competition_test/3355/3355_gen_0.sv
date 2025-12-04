module scavenger_hunt(
  input clk, // System clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [10:0] total_time, // Max total time T
  input [10:0] travel_matrix [0:5][0:5], // 6x6 flattened travel times (locations 4=start,5=end)
  input [6:0] p_i [0:3], // Points for tasks 0-3
  input [10:0] t_i [0:3], // Task durations for tasks 0-3
  input [10:0] d_i [0:3], // Task deadlines (0x7FF for no deadline)
  output reg [8:0] max_points, // Maximum possible points (0-400)
  output reg [3:0] task_set, // Optimal task bitmask (bit0=task0)
  output reg done // High when computation completes
);

  // Internal state
  reg [3:0] comb;          // 4-bit combination counter (0..15)
  reg [3:0] cycle_cnt;     // Counts 0..15 after start
  reg busy;                // Computation in progress

  // Helper: compute shortest travel time between two locations using BFS
  // -1 means unreachable; assumes at most 6 nodes and non-negative weights
  function [10:0] shortest_travel;
    input [2:0] src; // 0..5
    input [2:0] dst; // 0..5
    integer q[0:5];
    reg [10:0] dist [0:5];
    reg visited [0:5];
    integer i, u, v;
    begin
      for (i = 0; i < 6; i++) begin
        dist[i] = 11'h7FF; // 'h7FF = 2047 > any possible path
        visited[i] = 1'b0;
      end
      dist[src] = 0;
      qhead = 0; qtail = 0;
      q[qtail] = src; qtail = qtail + 1;
      visited[src] = 1'b1;
      while (qhead < qtail) begin
        u = q[qhead]; qhead = qhead + 1;
        for (v = 0; v < 6; v = v + 1) begin
          if (travel_matrix[u][v] != 11'h7FF && !visited[v]) begin
            if (dist[u] + travel_matrix[u][v] < dist[v]) begin
              dist[v] = dist[u] + travel_matrix[u][v];
              visited[v] = 1'b1;
              q[qtail] = v; qtail = qtail + 1;
            end
          end
        end
      end
      shortest_travel = dist[dst];
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      comb <= 4'd0;
      cycle_cnt <= 4'd0;
      busy <= 1'b0;
      max_points <= 9'd0;
      task_set <= 4'd0;
      done <= 1'b0;
    end else begin
      // Defaults
      done <= 1'b0;
      if (start) begin
        comb <= 4'd1;      // evaluate 0 immediately in the same cycle
        cycle_cnt <= 4'd0; // cycle 0 corresponds to comb==0
        busy <= 1'b1;
        done <= 1'b0;
        max_points <= 9'd0;
        task_set <= 4'd0;
      end else if (busy) begin
        if (cycle_cnt < 4'd15) begin
          cycle_cnt <= cycle_cnt + 1;
          comb <= comb + 1; // next combination
        end else begin
          // Completed 16 combinations
          busy <= 1'b0;
          done <= 1'b1;
        end
      end

      // Evaluate current combination during the busy window (0..15)
      if (busy) begin
        // Build sequence indices for current mask (comb)
        // seq[0] will be invalid (0xFF) if no tasks are selected
        reg [1:0] seq [0:3];
        integer k, si, points_acc, time_acc, prev_loc, t0, t1, t2, t3, t_deadline;
        reg valid, candidate_better;
        reg [10:0] travel; // local accum for travel time
        reg [3:0] mask;

        // Initialize
        for (k = 0; k < 4; k++) seq[k] = 2'h3; // 2'b11 = invalid index
        si = 0;
        for (k = 0; k < 4; k++) begin
          if (comb[k]) begin
            seq[si] = k;
            si = si + 1;
          end
        end

        points_acc = 0;
        time_acc = 0;
        travel = 0;
        valid = 1'b1;
        prev_loc = 4; // start location index = 4

        // Accumulate time and points based on sequence order
        if (seq[0] != 2'h3) begin
          t0 = seq[0];
          travel = shortest_travel(prev_loc, t0);
          if (travel >= 11'h7FF) valid = 1'b0;
          time_acc = travel + t_i[t0];
          points_acc = points_acc + p_i[t0];
          prev_loc = t0;

          if (d_i[t0] != 11'h7FF && time_acc > d_i[t0]) valid = 1'b0;
          if (time_acc > total_time) valid = 1'b0;

          if (seq[1] != 2'h3) begin
            t1 = seq[1];
            travel = shortest_travel(prev_loc, t1);
            if (travel >= 11'h7FF) valid = 1'b0;
            time_acc = time_acc + travel + t_i[t1];
            points_acc = points_acc + p_i[t1];
            prev_loc = t1;

            if (d_i[t1] != 11'h7FF && time_acc > d_i[t1]) valid = 1'b0;
            if (time_acc > total_time) valid = 1'b0;

            if (seq[2] != 2'h3) begin
              t2 = seq[2];
              travel = shortest_travel(prev_loc, t2);
              if (travel >= 11'h7FF) valid = 1'b0;
              time_acc = time_acc + travel + t_i[t2];
              points_acc = points_acc + p_i[t2];
              prev_loc = t2;

              if (d_i[t2] != 11'h7FF && time_acc > d_i[t2]) valid = 1'b0;
              if (time_acc > total_time) valid = 1'b0;

              if (seq[3] != 2'h3) begin
                t3 = seq[3];
                travel = shortest_travel(prev_loc, t3);
                if (travel >= 11'h7FF) valid = 1'b0;
                time_acc = time_acc + travel + t_i[t3];
                points_acc = points_acc + p_i[t3];
                prev_loc = t3;

                if (d_i[t3] != 11'h7FF && time_acc > d_i[t3]) valid = 1'b0;
                if (time_acc > total_time) valid = 1'b0;
              end
            end
          end
        end

        // Final leg to end location (5)
        if (valid) begin
          travel = shortest_travel(prev_loc, 5);
          if (travel >= 11'h7FF) valid = 1'b0;
          else time_acc = time_acc + travel;
          if (time_acc > total_time) valid = 1'b0;
        end

        // Update best if valid
        if (valid) begin
          if (points_acc > max_points) begin
            max_points <= points_acc;
            task_set <= comb;
          end else if (points_acc == max_points) begin
            // Tie-breaker: prefer lexicographically smaller (numerically smaller bitmask)
            if (comb < task_set) begin
              task_set <= comb;
            end
          end
        end
      end
    end
  end

endmodule