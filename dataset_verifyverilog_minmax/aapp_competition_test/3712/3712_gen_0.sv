module compartment_swaps(
  input clk,
  input rst_n,
  input start,
  input [2:0] comp0,
  input [2:0] comp1,
  input [2:0] comp2,
  input [2:0] comp3,
  input [2:0] comp4,
  input [2:0] comp5,
  input [2:0] comp6,
  input [2:0] comp7,
  output reg [6:0] result,
  output reg done
);

  // Internal FSM states
  typedef enum logic [2:0] {
    IDLE        = 3'b000,
    COUNTING    = 3'b001,
    PROCESS_12  = 3'b010,
    PROCESS_1_REM = 3'b011,
    PROCESS_2_REM = 3'b100,
    FINISH      = 3'b101
  } state_t;

  state_t current_state, next_state;

  // Counters and accumulators (4-bit, max 8)
  reg [3:0] counts1, counts2, counts3, counts4;
  reg [3:0] next_counts1, next_counts2, next_counts3, next_counts4;
  reg [6:0] ans, next_ans;
  reg [6:0] total_students, next_total_students;
  reg [6:0] step_counter, next_step_counter;

  // Sequential logic: state update and reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      ans           <= 7'b0;
      counts1       <= 4'b0;
      counts2       <= 4'b0;
      counts3       <= 4'b0;
      counts4       <= 4'b0;
      total_students <= 7'b0;
      step_counter   <= 7'b0;
      result         <= 7'b0;
      done           <= 1'b0;
    end else begin
      current_state <= next_state;
      ans           <= next_ans;
      counts1       <= next_counts1;
      counts2       <= next_counts2;
      counts3       <= next_counts3;
      counts4       <= next_counts4;
      total_students <= next_total_students;
      step_counter   <= next_step_counter;
      result         <= (next_state == FINISH) ? next_ans : result;
      done           <= (next_state == FINISH);
    end
  end

  // Combinational next-state logic and computations
  always_comb begin
    // Defaults (avoid latches)
    next_state        = current_state;
    next_ans          = ans;
    next_counts1      = counts1;
    next_counts2      = counts2;
    next_counts3      = counts3;
    next_counts4      = counts4;
    next_total_students = total_students;
    next_step_counter   = step_counter;

    case (current_state)
      IDLE: begin
        next_ans          = 7'b0;
        next_counts1      = 4'b0;
        next_counts2      = 4'b0;
        next_counts3      = 4'b0;
        next_counts4      = 4'b0;
        next_total_students = 7'b0;
        next_step_counter   = 7'b0;
        if (start) begin
          // Initialize counts based on comp0..comp7
          next_counts1 = {1'b0, comp1} + {1'b0, comp4} + {1'b0, comp7};
          next_counts2 = {1'b0, comp2} + {1'b0, comp5};
          next_counts3 = {1'b0, comp0} + {1'b0, comp3} + {1'b0, comp6};
          next_counts4 = 4'b0; // Not used in this flow but kept per spec
          next_total_students = {1'b0, comp0} + {1'b0, comp1} + {1'b0, comp2} +
                                {1'b0, comp3} + {1'b0, comp4} + {1'b0, comp5} +
                                {1'b0, comp6} + {1'b0, comp7};
          next_step_counter = 7'b0;
          next_state = COUNTING;
        end
      end

      COUNTING: begin
        // Single-cycle initialization step
        next_state = PROCESS_12;
      end

      PROCESS_12: begin
        // 1. Process min(counts[1], counts[2]) pairs: ans += min_val, counts[3] += min_val
        next_step_counter = step_counter + 1;
        if (counts1 <= counts2) begin
          next_ans     = ans + counts1;
          next_counts3 = counts3 + counts1;
          next_counts1 = 4'b0;
          next_counts2 = counts2 - counts1;
        end else begin
          next_ans     = ans + counts2;
          next_counts3 = counts3 + counts2;
          next_counts1 = counts1 - counts2;
          next_counts2 = 4'b0;
        end
        next_state = PROCESS_1_REM;
      end

      PROCESS_1_REM: begin
        // 2. Handle remaining counts[1]
        // a. ans += 2*(counts[1]/3), counts[3] += counts[1]/3
        next_step_counter = step_counter + 1;
        next_counts1 = counts1;
        next_counts2 = counts2;
        next_counts3 = counts3;
        next_ans     = ans;

        if (counts1 >= 3) begin
          next_ans     = ans + (2 * (counts1 / 4'd3));
          next_counts3 = counts3 + (counts1 / 4'd3);
          next_counts1 = counts1 % 4'd3;
        end
        // b. Remainder handled below in the same cycle
        if (next_counts1 > 0) begin
          if (next_counts3 > 0) begin
            next_ans = next_ans + 1; // one swap using existing in group-of-3
          end else begin
            next_ans = next_ans + 2; // need two swaps to form a group-of-3
          end
          next_counts1 = 4'b0; // remainder processed
        end
        next_state = PROCESS_2_REM;
      end

      PROCESS_2_REM: begin
        // 3. Handle remaining counts[2]
        // a. ans += 2*(counts[2]/3), counts[3] += 2*(counts[2]/3)
        next_step_counter = step_counter + 1;
        next_counts1 = counts1;
        next_counts2 = counts2;
        next_counts3 = counts3;
        next_ans     = ans;

        if (counts2 >= 3) begin
          next_ans     = ans + (2 * (counts2 / 4'd3));
          next_counts3 = counts3 + (2 * (counts2 / 4'd3));
          next_counts2 = counts2 % 4'd3;
        end
        // b. Remainder handled below in the same cycle
        if (next_counts2 > 0) begin
          if (next_counts4 > 0) begin
            next_ans = next_ans + 1; // swap with counts[4] groups
          end else begin
            next_ans = next_ans + 2; // need two swaps for remainder
          end
          next_counts2 = 4'b0; // remainder processed
        end
        next_state = FINISH;
      end

      FINISH: begin
        // Validate total student count
        if (total_students < 3 || total_students == 5) begin
          // Represent -1 as 7'b1111111
          next_ans = 7'b1111111;
        end else begin
          next_ans = ans;
        end
        // Hold final result and done; remain in FINISH until reset/start
        next_state = FINISH;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule