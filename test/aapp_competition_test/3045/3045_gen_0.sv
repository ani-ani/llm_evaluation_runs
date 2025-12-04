module mps_receiver(
  input clk,
  input rst_n,
  input start,
  input [1:0] beacon_count,
  input signed [9:0] x[0:3],
  input signed [9:0] y[0:3],
  input [11:0] d[0:3],
  output reg signed [9:0] x_r,
  output reg signed [9:0] y_r,
  output reg [1:0] status
);

  // State encoding
  localparam [2:0]
    S_IDLE      = 3'd0,
    S_SEARCH    = 3'd1,
    S_CALC_DIST = 3'd2,
    S_CHECK     = 3'd3,
    S_DONE      = 3'd4;

  reg [2:0] state, next_state;

  // Candidate position counters: range -512..511
  // Represented as 10-bit signed
  reg signed [9:0] x_cand, y_cand;

  // Beacon index for iterative checking
  reg [1:0] b_idx;

  // Valid position tracking
  reg [19:0] valid_count;       // Enough to count many positions
  reg signed [9:0] unique_x;
  reg signed [9:0] unique_y;

  // Working registers
  reg [11:0] expected_d;
  reg [11:0] manhattan_sum;
  reg match_flag;               // 1 if candidate matches all checked beacons so far

  // Absolute difference helper (combinational)
  function automatic [11:0] abs_diff_10;
    input signed [9:0] a;
    input signed [9:0] b;
    reg signed [10:0] diff;
    begin
      diff = a - b;
      if (diff[10] == 1'b1) begin
        abs_diff_10 = (diff[10] ? (~diff + 11'd1) : diff)[11:0];
      end else begin
        abs_diff_10 = diff[11:0];
      end
    end
  endfunction

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_SEARCH;
        end
      end

      S_SEARCH: begin
        // Move to CALC_DIST for each candidate position
        next_state = S_CALC_DIST;
      end

      S_CALC_DIST: begin
        // After computing/accumulating distance for one beacon, decide next step
        if (b_idx == beacon_count) begin
          // All required beacons processed
          next_state = S_CHECK;
        end else begin
          // More beacons to check for this candidate
          next_state = S_CALC_DIST;
        end
      end

      S_CHECK: begin
        // After checking candidate validity, either continue SEARCH or finish
        // Determine if last candidate (x=511,y=511)
        if ((x_cand == 10'sd511) && (y_cand == 10'sd511)) begin
          next_state = S_DONE;
        end else begin
          next_state = S_SEARCH;
        end
      end

      S_DONE: begin
        // Wait in DONE until start deasserted and asserted again
        if (!start) begin
          next_state = S_IDLE;
        end
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      x_cand      <= -10'sd512;
      y_cand      <= -10'sd512;
      b_idx       <= 2'd0;
      valid_count <= 20'd0;
      unique_x    <= 10'sd0;
      unique_y    <= 10'sd0;
      x_r         <= 10'sd0;
      y_r         <= 10'sd0;
      status      <= 2'b00; // computing
      expected_d  <= 12'd0;
      manhattan_sum <= 12'd0;
      match_flag  <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          // Initialize when start asserted (handled in next_state)
          if (start) begin
            x_cand      <= -10'sd512;
            y_cand      <= -10'sd512;
            b_idx       <= 2'd0;
            valid_count <= 20'd0;
            unique_x    <= 10'sd0;
            unique_y    <= 10'sd0;
            x_r         <= 10'sd0;
            y_r         <= 10'sd0;
            status      <= 2'b00; // computing
            manhattan_sum <= 12'd0;
            match_flag  <= 1'b1;  // start optimistic for each candidate
          end else begin
            status <= 2'b00; // idle/computing
          end
        end

        S_SEARCH: begin
          // Prepare to evaluate new candidate
          b_idx        <= 2'd0;
          manhattan_sum<= 12'd0;
          match_flag   <= 1'b1; // optimistic until disproved
        end

        S_CALC_DIST: begin
          // For beacon indices 0..beacon_count-1 compute and compare incrementally
          if (b_idx < beacon_count) begin
            // Compute Manhattan distance for current beacon
            // abs(x_cand - x[b_idx]) + abs(y_cand - y[b_idx])
            manhattan_sum <= abs_diff_10(x_cand, x[b_idx]) + abs_diff_10(y_cand, y[b_idx]);
            expected_d    <= d[b_idx];

            // Update match_flag based on this beacon's constraint
            if (manhattan_sum == expected_d) begin
              match_flag <= match_flag & 1'b1;
            end else begin
              match_flag <= 1'b0;
            end

            // Move to next beacon index
            b_idx <= b_idx + 2'd1;
          end
        end

        S_CHECK: begin
          // After all beacons processed for this candidate
          if (match_flag == 1'b1) begin
            // Candidate is valid
            valid_count <= valid_count + 20'd1;
            if (valid_count == 20'd0) begin
              // First valid position found
              unique_x <= x_cand;
              unique_y <= y_cand;
            end
          end

          // Advance to next candidate position
          if (x_cand == 10'sd511) begin
            x_cand <= -10'sd512;
            if (y_cand != 10'sd511) begin
              y_cand <= y_cand + 10'sd1;
            end
          end else begin
            x_cand <= x_cand + 10'sd1;
          end
        end

        S_DONE: begin
          // Determine status output based on valid_count
          if (valid_count == 20'd0) begin
            status <= 2'b11; // impossible
          end else if (valid_count == 20'd1) begin
            status <= 2'b01; // unique
            x_r    <= unique_x;
            y_r    <= unique_y;
          end else begin
            status <= 2'b10; // uncertain
          end
        end

        default: begin
          // Should not occur, reset to safe defaults
          state       <= S_IDLE;
          status      <= 2'b00;
        end
      endcase
    end
  end

endmodule