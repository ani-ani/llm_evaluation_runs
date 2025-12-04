module min_k_finder (
  input clk,
  input rst_n,
  input start,
  input [7:0] K,
  input [3:0][7:0] names,
  input [3:0][7:0] scores,
  output reg [3:0][7:0] min_names,
  output reg [3:0][7:0] min_scores,
  output reg done
);

  localparam STAGES = 6;   // number of compare/swap steps for 4-element bubble sort
  localparam CYCLES = 20;  // worst-case required runtime (cycles)

  // Internal state
  reg working;                 // sort is in progress
  reg [7:0] cd;                // cycle-down counter (8 bits is safe; max value is 20)
  reg [3:0][7:0] s_names;      // in-flight sorted names (pairs stay aligned)
  reg [3:0][7:0] s_scores;     // in-flight sorted scores

  // Next-cycle signals (combinational)
  reg [3:0][7:0] next_s_names;
  reg [3:0][7:0] next_s_scores;
  reg [7:0] next_cd;
  reg next_working;

  // State transition and compare/swap stage selection
  always_comb begin
    next_working = working;
    next_cd = cd;
    next_s_names = s_names;
    next_s_scores = s_scores;

    if (!rst_n) begin
      // Reset values
      next_working = 1'b0;
      next_cd = '0;
      next_s_names = '0;
      next_s_scores = '0;
    end else if (start) begin
      // Load inputs and start sorting
      next_working = 1'b1;
      next_cd = CYCLES[7:0];
      next_s_names = names;
      next_s_scores = scores;
    end else if (working) begin
      // Perform one compare/swap per cycle for CYCLES cycles
      if (cd > 0) begin
        next_cd = cd - 1;

        // Determine which pair to compare based on the current cycle count
        // Pairs: [0,1], [1,2], [2,3], [0,1], [1,2], [2,3]
        // After 6 steps, remaining cycles do nothing (already sorted)
        if (cd == 20 || cd == 17 || cd == 14 || cd == 11 || cd == 8 || cd == 5) begin
          // Compare (0,1)
          next_s_names = s_names;
          next_s_scores = s_scores;
          if (s_scores[0] > s_scores[1]) begin
            next_s_scores[0] = s_scores[1];
            next_s_scores[1] = s_scores[0];
            next_s_names[0]  = s_names[1];
            next_s_names[1]  = s_names[0];
          end
        end else if (cd == 19 || cd == 16 || cd == 13 || cd == 10 || cd == 7 || cd == 4) begin
          // Compare (1,2)
          next_s_names = s_names;
          next_s_scores = s_scores;
          if (s_scores[1] > s_scores[2]) begin
            next_s_scores[1] = s_scores[2];
            next_s_scores[2] = s_scores[1];
            next_s_names[1]  = s_names[2];
            next_s_names[2]  = s_names[1];
          end
        end else if (cd == 18 || cd == 15 || cd == 12 || cd == 9 || cd == 6 || cd == 3) begin
          // Compare (2,3)
          next_s_names = s_names;
          next_s_scores = s_scores;
          if (s_scores[2] > s_scores[3]) begin
            next_s_scores[2] = s_scores[3];
            next_s_scores[3] = s_scores[2];
            next_s_names[2]  = s_names[3];
            next_s_names[3]  = s_names[2];
          end
        end else begin
          // Idle cycles (do nothing)
          next_s_names = s_names;
          next_s_scores = s_scores;
        end
      end else begin
        // Finished: hold the sorted data
        next_working = 1'b0;
        next_cd = 8'd0;
        next_s_names = s_names;
        next_s_scores = s_scores;
      end
    end
  end

  // Register updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      working <= 1'b0;
      cd <= 8'd0;
      s_names <= '0;
      s_scores <= '0;
    end else begin
      working <= next_working;
      cd <= next_cd;
      s_names <= next_s_names;
      s_scores <= next_s_scores;
    end
  end

  // Output logic: when countdown reaches 0, finalize outputs
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_names <= '0;
      min_scores <= '0;
      done <= 1'b0;
    end else begin
      // done = 1 when not resetting and not actively working (i.e., after CYCLES cycles)
      done <= !(!rst_n) && !working;

      if (cd == 1) begin
        // At the last active cycle, select the first K elements and zero the rest
        min_scores[0] = (K >= 1) ? s_scores[0] : 8'd0;
        min_names[0]  = (K >= 1) ? s_names[0]  : 8'd0;
        min_scores[1] = (K >= 2) ? s_scores[1] : 8'd0;
        min_names[1]  = (K >= 2) ? s_names[1]  : 8'd0;
        min_scores[2] = (K >= 3) ? s_scores[2] : 8'd0;
        min_names[2]  = (K >= 3) ? s_names[2]  : 8'd0;
        min_scores[3] = 8'd0;
        min_names[3]  = 8'd0;
      end else if (cd == 0) begin
        // Hold the result until next start
        min_scores <= min_scores;
        min_names  <= min_names;
      end
    end
  end

endmodule
