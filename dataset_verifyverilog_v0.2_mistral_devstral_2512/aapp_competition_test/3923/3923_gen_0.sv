module permutation_generator #(
  parameter N = 16,
  parameter MAX_CYCLES = 16
)(
  input clk,
  input rst_n,
  input start,
  input [3:0] A,
  input [3:0] B,
  output reg [3:0] result_addr,
  output reg [3:0] result_val,
  output reg result_write,
  output reg done,
  output reg valid_solution
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    FIND_SOLUTION,
    CONSTRUCT_PERM,
    DONE
  } state_t;

  state_t state, next_state;
  reg [3:0] x, y; // Counts of cycles of length A and B
  reg [3:0] current_addr; // Current address being written
  reg [3:0] permutation [0:N-1]; // Permutation array
  reg found_solution; // Flag indicating if a solution was found
  reg [3:0] cycle_start; // Start of current cycle
  reg [3:0] cycle_length; // Current cycle length (A or B)
  reg [3:0] cycle_pos; // Position in current cycle
  reg [3:0] remaining_cycles; // Remaining cycles to construct
  reg [3:0] cycle_type; // 0 for A, 1 for B

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result_addr <= 0;
      result_val <= 0;
      result_write <= 0;
      done <= 0;
      valid_solution <= 0;
      x <= 0;
      y <= 0;
      current_addr <= 0;
      found_solution <= 0;
      cycle_start <= 0;
      cycle_length <= 0;
      cycle_pos <= 0;
      remaining_cycles <= 0;
      cycle_type <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = FIND_SOLUTION;
      end
      FIND_SOLUTION: begin
        if (found_solution) next_state = CONSTRUCT_PERM;
        else if (x == N/A + 1) next_state = DONE;
      end
      CONSTRUCT_PERM: begin
        if (current_addr == N-1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // FIND_SOLUTION logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x <= 0;
      y <= 0;
      found_solution <= 0;
    end else if (state == FIND_SOLUTION) begin
      if (A == 0 || B == 0) begin
        found_solution <= 0;
        next_state = DONE;
      end else begin
        if (x <= N/A) begin
          if ((N - x*A) % B == 0) begin
            y <= (N - x*A)/B;
            found_solution <= 1;
          end else begin
            x <= x + 1;
          end
        end else begin
          found_solution <= 0;
        end
      end
    end
  end

  // CONSTRUCT_PERM logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_addr <= 0;
      cycle_start <= 0;
      cycle_length <= 0;
      cycle_pos <= 0;
      remaining_cycles <= 0;
      cycle_type <= 0;
    end else if (state == CONSTRUCT_PERM) begin
      if (current_addr == 0) begin
        // Initialize cycle construction
        cycle_type <= 0;
        remaining_cycles <= x;
        cycle_start <= 0;
        cycle_length <= A;
        cycle_pos <= 0;
      end else begin
        // Update cycle position
        if (cycle_pos == cycle_length - 1) begin
          // End of current cycle
          if (cycle_type == 0) begin
            // Move to next A cycle or switch to B cycles
            if (remaining_cycles > 1) begin
              cycle_start <= cycle_start + cycle_length;
              remaining_cycles <= remaining_cycles - 1;
              cycle_pos <= 0;
            end else begin
              cycle_type <= 1;
              remaining_cycles <= y;
              cycle_start <= cycle_start + cycle_length;
              cycle_length <= B;
              cycle_pos <= 0;
            end
          end else begin
            // Move to next B cycle
            if (remaining_cycles > 1) begin
              cycle_start <= cycle_start + cycle_length;
              remaining_cycles <= remaining_cycles - 1;
              cycle_pos <= 0;
            end else begin
              // All cycles constructed
              current_addr <= N-1;
            end
          end
        end else begin
          cycle_pos <= cycle_pos + 1;
        end
      end

      // Write permutation value
      if (current_addr < N) begin
        if (cycle_pos == cycle_length - 1) begin
          permutation[current_addr] <= cycle_start;
        end else begin
          permutation[current_addr] <= cycle_start + cycle_pos + 1;
        end
        current_addr <= current_addr + 1;
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_write <= 0;
      done <= 0;
      valid_solution <= 0;
    end else begin
      result_write <= (state == CONSTRUCT_PERM && current_addr < N);
      done <= (state == DONE);
      valid_solution <= found_solution;

      if (result_write) begin
        result_addr <= current_addr;
        result_val <= permutation[current_addr];
      end else begin
        result_addr <= 0;
        result_val <= 0;
      end
    end
  end

endmodule