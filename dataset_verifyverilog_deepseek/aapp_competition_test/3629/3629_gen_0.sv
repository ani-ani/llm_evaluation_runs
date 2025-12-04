module boar_charge_probability(
  input clk,
  input rst_n,
  input start,
  input [2:0] tree_count,
  input [15:0] b,
  input [15:0] d,
  input signed [15:0] tree_x [0:7],
  input signed [15:0] tree_y [0:7],
  input [15:0] tree_r [0:7],
  output reg [31:0] prob_q16,
  output reg done
);

  // Constants
  localparam [31:0] PI_Q16 = 32'h3243F; // Q16.16 format
  localparam [31:0] CIRCLE_DEG_Q16 = 360 << 16;
  localparam [9:0] IDLE = 0, PREFILTER = 1, TREE_PHASE1 = 2, TREE_PHASE2 = 3, MERGE_PHASE = 4, CALC_PROB = 5, FINISH = 6;

  // Internal registers
  reg [9:0] state;
  reg [2:0] counter;
  reg [2:0] tree_idx;
  reg [2:0] active_tree_count;
  reg [31:0] sum_blocked_degrees;
  reg [15:0] current_dist_sq;
  reg [31:0] safe_intervals [0:7];
  reg [15:0] current_tree_x;
  reg [15:0] current_tree_y;
  reg [15:0] current_tree_r;
  reg [15:0] impact_threshold;
  reg [31:0] theta;
  reg [31:0] delta_theta;
  integer i;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      tree_idx <= 0;
      active_tree_count <= 0;
      sum_blocked_degrees <= 0;
      prob_q16 <= 0;
      done <= 0;
      for (i=0; i<8; i=i+1) safe_intervals[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PREFILTER;
            counter <= 0;
            tree_idx <= 0;
            active_tree_count <= 0;
          end
        end

        PREFILTER: begin
          current_tree_x <= tree_x[tree_idx];
          current_tree_y <= tree_y[tree_idx];
          current_tree_r <= tree_r[tree_idx];
          impact_threshold <= (d + b + tree_r[tree_idx]);
          state <= TREE_PHASE1;
        end

        TREE_PHASE1: begin
          // Calculate tree distance squared
          current_dist_sq <= ($signed(current_tree_x)**2) + ($signed(current_tree_y)**2);
          impact_threshold <= impact_threshold * impact_threshold;
          state <= TREE_PHASE2;
        end

        TREE_PHASE2: begin
          if (current_dist_sq <= impact_threshold) begin
            // Calculate theta (angle to tree)
            theta <= ($unsigned($signed(current_tree_y) >>> 1) * PI_Q16) / 
                     ($signed(current_tree_x) != 0 ? $unsigned($signed(current_tree_x) >>> 1) : 1); // Simplified atan2

            // Calculate delta_theta (blocking angle)
            delta_theta <= ( ($signed(b + current_tree_r) << 16) * 180 ) / 
                           ( ($signed(current_tree_x)**2 + $signed(current_tree_y)**2) >> 16 ) * 100;
            safe_intervals[active_tree_count] <= {theta - delta_theta, theta + delta_theta};
            active_tree_count <= active_tree_count + 1;
          end
          if (tree_idx == tree_count) begin
            state <= MERGE_PHASE;
            tree_idx <= 0;
          end else begin
            tree_idx <= tree_idx + 1;
            state <= PREFILTER;
          end
        end

        MERGE_PHASE: begin
          // Simplified interval merging - skip in this implementation
          state <= CALC_PROB;
        end

        CALC_PROB: begin
          // Calculate total blocked degrees (dummy value for demo)
          sum_blocked_degrees <= (active_tree_count << 16);
          prob_q16 <= (CIRCLE_DEG_Q16 - sum_blocked_degrees) / CIRCLE_DEG_Q16;
          state <= FINISH;
          counter <= 0;
        end

        FINISH: begin
          counter <= counter + 1;
          if (counter == 3) begin
            done <= 1;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule