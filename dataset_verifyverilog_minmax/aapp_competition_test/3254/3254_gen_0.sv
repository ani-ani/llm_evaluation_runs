module min_papers_average(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [21:0] P_fixed, // Q12.10 format (P * 1024)
  output reg [4:0] ones, twos, threes, fours, fives, // counts per paper type (0-31)
  output reg done // high when solution found
);

  // State machine states
  typedef enum logic [2:0] {
    IDLE = 3'b000,
    SEARCH = 3'b001,
    COMPUTE = 3'b010,
    CHECK = 3'b011,
    DONE = 3'b100
  } state_t;
  
  state_t current_state, next_state;
  
  // Internal counters for the nested loops
  reg [4:0] fives_reg, fours_reg, threes_reg, twos_reg, ones_reg;
  reg [7:0] total_count_reg; // 0-255, but we only go to 200
  
  // Cycle counter to ensure we don't exceed 2000 cycles
  reg [11:0] cycle_count;
  
  // Internal computation for sum and comparison
  reg [19:0] sum_values; // 20-bit precision for sum
  reg [31:0] left_side, right_side;
  
  // Sequential logic for state transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      cycle_count <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == IDLE) begin
        cycle_count <= 0;
      end else if (current_state == SEARCH) begin
        cycle_count <= cycle_count + 1;
      end
    end
  end
  
  // Combinational logic for next state and outputs
  always_comb begin
    // Default outputs
    next_state = current_state;
    done = 0;
    ones = 0;
    twos = 0;
    threes = 0;
    fours = 0;
    fives = 0;
    
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SEARCH;
        end
      end
      
      SEARCH: begin
        // If we've exceeded 2000 cycles, go to DONE
        if (cycle_count >= 2000) begin
          next_state = DONE;
        end else begin
          next_state = COMPUTE;
        end
      end
      
      COMPUTE: begin
        // Compute sum and total count for current combination
        ones_reg = total_count_reg - fives_reg - fours_reg - threes_reg - twos_reg;
        sum_values = (1 * ones_reg) + (2 * twos_reg) + (3 * threes_reg) + (4 * fours_reg) + (5 * fives_reg);
        next_state = CHECK;
      end
      
      CHECK: begin
        // Check the condition: (sum * 1024) == (total_count * P_fixed)
        left_side = sum_values * 1024;
        right_side = total_count_reg * P_fixed;
        
        if (left_side == right_side) begin
          // Solution found
          ones = ones_reg;
          twos = twos_reg;
          threes = threes_reg;
          fours = fours_reg;
          fives = fives_reg;
          done = 1;
          next_state = DONE;
        end else begin
          // Increment the loop counters
          if (twos_reg < 31) begin
            twos_reg = twos_reg + 1;
            next_state = SEARCH;
          end else if (threes_reg < 31) begin
            twos_reg = 0;
            threes_reg = threes_reg + 1;
            next_state = SEARCH;
          end else if (fours_reg < 31) begin
            twos_reg = 0;
            threes_reg = 0;
            fours_reg = fours_reg + 1;
            next_state = SEARCH;
          end else if (fives_reg < 31) begin
            twos_reg = 0;
            threes_reg = 0;
            fours_reg = 0;
            fives_reg = fives_reg + 1;
            next_state = SEARCH;
          end else if (total_count_reg < 200) begin
            // Reset all counters and increment total_count
            twos_reg = 0;
            threes_reg = 0;
            fours_reg = 0;
            fives_reg = 0;
            total_count_reg = total_count_reg + 1;
            next_state = SEARCH;
          end else begin
            // No solution found within constraints
            next_state = DONE;
          end
        end
      end
      
      DONE: begin
        // Maintain outputs and done signal
        done = 1;
        ones = ones_reg;
        twos = twos_reg;
        threes = threes_reg;
        fours = fours_reg;
        fives = fives_reg;
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end
  
endmodule