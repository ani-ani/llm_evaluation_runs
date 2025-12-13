module min_papers_average(
  input clk,
  input rst_n,
  input start,
  input [21:0] P_fixed,
  output reg [4:0] ones,
  output reg [4:0] twos,
  output reg [4:0] threes,
  output reg [4:0] fours,
  output reg [4:0] fives,
  output reg done
);

  // State encoding
  localparam IDLE    = 3'd0;
  localparam SEARCH  = 3'd1;
  localparam COMPUTE = 3'd2;
  localparam CHECK   = 3'd3;
  localparam DONE    = 3'd4;

  reg [2:0] state, next_state;

  // Nested loop counters (0-31)
  reg [4:0] c_fives;
  reg [4:0] c_fours;
  reg [4:0] c_threes;
  reg [4:0] c_twos;
  reg [4:0] c_ones;

  // Latched/current solution
  reg [4:0] sol_fives;
  reg [4:0] sol_fours;
  reg [4:0] sol_threes;
  reg [4:0] sol_twos;
  reg [4:0] sol_ones;
  reg       sol_found;

  // Total count and sum (ensure at least 20-bit precision for sum)
  reg [7:0] total_cnt;       // up to 155
  reg [19:0] sum_val;        // values: 1..5, fits in 20 bits easily

  // Comparison operands
  reg [31:0] lhs;            // sum_val * 1024
  reg [43:0] rhs;            // total_cnt * P_fixed (22+8-? fits in 44 bits)

  // Minimum count tracking
  reg [7:0] best_total_cnt;

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = SEARCH;
      end

      SEARCH: begin
        next_state = COMPUTE;
      end

      COMPUTE: begin
        next_state = CHECK;
      end

      CHECK: begin
        if (sol_found)
          next_state = DONE;
        else begin
          // If we exhausted all combinations without solution, go DONE
          if ((c_fives == 5'd31) && (c_fours == 5'd31) &&
              (c_threes == 5'd31) && (c_twos == 5'd31) &&
              (c_ones == 5'd31))
            next_state = DONE;
          else
            next_state = SEARCH;
        end
      end

      DONE: begin
        // Wait for start deassert and reassert to restart
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      done           <= 1'b0;
      ones           <= 5'd0;
      twos           <= 5'd0;
      threes         <= 5'd0;
      fours          <= 5'd0;
      fives          <= 5'd0;
      c_fives        <= 5'd0;
      c_fours        <= 5'd0;
      c_threes       <= 5'd0;
      c_twos         <= 5'd0;
      c_ones         <= 5'd0;
      sol_fives      <= 5'd0;
      sol_fours      <= 5'd0;
      sol_threes     <= 5'd0;
      sol_twos       <= 5'd0;
      sol_ones       <= 5'd0;
      sol_found      <= 1'b0;
      total_cnt      <= 8'd0;
      sum_val        <= 20'd0;
      lhs            <= 32'd0;
      rhs            <= 44'd0;
      best_total_cnt <= 8'hFF; // large initial
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done           <= 1'b0;
          sol_found      <= 1'b0;
          best_total_cnt <= 8'hFF;
          // Initialize counters when start asserted (handled next_state)
          if (start) begin
            c_fives  <= 5'd0;
            c_fours  <= 5'd0;
            c_threes <= 5'd0;
            c_twos   <= 5'd0;
            c_ones   <= 5'd0;
          end
        end

        SEARCH: begin
          // In SEARCH state we already have current counters.
          // No update of counters here; evaluation in COMPUTE/CHECK.
        end

        COMPUTE: begin
          // Compute total count and sum for current combination.
          total_cnt <= c_fives + c_fours + c_threes + c_twos + c_ones;
          // sum = 5*fives + 4*fours + 3*threes + 2*twos + ones
          sum_val   <= (c_fives  * 5) +
                       (c_fours  * 4) +
                       (c_threes * 3) +
                       (c_twos   * 2) +
                       (c_ones);
          // Prepare comparison operands
          lhs <= (( (c_fives  * 5) +
                    (c_fours  * 4) +
                    (c_threes * 3) +
                    (c_twos   * 2) +
                    (c_ones) ) << 10); // sum * 1024
          rhs <= ( (c_fives + c_fours + c_threes + c_twos + c_ones) * P_fixed );
        end

        CHECK: begin
          // Check for zero-total or valid solution
          if ( (c_fives + c_fours + c_threes + c_twos + c_ones) != 0 ) begin
            if (lhs == rhs) begin
              // Found a valid combination
              if (!sol_found ||
                  ((c_fives + c_fours + c_threes + c_twos + c_ones) < best_total_cnt)) begin
                // Update best (minimal total)
                sol_found      <= 1'b1;
                best_total_cnt <= c_fives + c_fours + c_threes + c_twos + c_ones;
                sol_fives      <= c_fives;
                sol_fours      <= c_fours;
                sol_threes     <= c_threes;
                sol_twos       <= c_twos;
                sol_ones       <= c_ones;
              end
            end
          end

          // Priority to first minimal-count solution: once a given total_cnt
          // is achieved as best, any later with same total won't replace it.

          // Increment nested-loop counters (priority: fives downto ones)
          if (!sol_found) begin
            // Continue full search until a solution is found
            if (c_ones != 5'd31) begin
              c_ones <= c_ones + 5'd1;
            end else begin
              c_ones <= 5'd0;
              if (c_twos != 5'd31) begin
                c_twos <= c_twos + 5'd1;
              end else begin
                c_twos <= 5'd0;
                if (c_threes != 5'd31) begin
                  c_threes <= c_threes + 5'd1;
                end else begin
                  c_threes <= 5'd0;
                  if (c_fours != 5'd31) begin
                    c_fours <= c_fours + 5'd1;
                  end else begin
                    c_fours <= 5'd0;
                    if (c_fives != 5'd31) begin
                      c_fives <= c_fives + 5'd1;
                    end
                  end
                end
              end
            end
          end else begin
            // If solution found, we can stop incrementing; SEARCH->DONE
          end
        end

        DONE: begin
          done <= sol_found; // High if a solution was found

          // Drive outputs with best solution found (or zeros if none)
          if (sol_found) begin
            fives  <= sol_fives;
            fours  <= sol_fours;
            threes <= sol_threes;
            twos   <= sol_twos;
            ones   <= sol_ones;
          end else begin
            fives  <= 5'd0;
            fours  <= 5'd0;
            threes <= 5'd0;
            twos   <= 5'd0;
            ones   <= 5'd0;
          end

          // Clear when start is low handled by transition back to IDLE
        end

        default: begin
        end
      endcase
    end
  end

endmodule
