module KindergartenPartition(
  input clk,
  input rst_n,
  input start,
  input input_valid,
  input [1:0] current_teacher,
  input [7:0][2:0] preference_list,
  input [2:0] current_kid,
  input [2:0] N,
  output reg [2:0] result,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    CONFIG,
    INIT_COMPUTE,
    CHECK_PARTITION,
    VERIFY,
    NEXT_ASSIGNMENT,
    NEXT_T,
    DONE
  } state_t;
  state_t state, next_state;

  // Internal registers
  reg [2:0] current_kid_reg;
  reg [7:0][1:0] current_teachers;
  reg [7:0][7:0][2:0] preference_ranks;
  reg [2:0] T;
  reg [15:0] assignment_mask;
  reg [7:0][1:0] proposed_assignment;
  reg [7:0][7:0] allowed_mask;
  reg [2:0] kid_counter;
  reg [2:0] check_counter;
  reg [2:0] pair_i, pair_j;
  reg valid_assignment;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_kid_reg <= 0;
      T <= 0;
      assignment_mask <= 0;
      kid_counter <= 0;
      check_counter <= 0;
      pair_i <= 0;
      pair_j <= 0;
      valid_assignment <= 0;
      done <= 0;
      error <= 0;
      result <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CONFIG;
      end
      CONFIG: begin
        if (input_valid) begin
          if (current_kid_reg == N - 1) begin
            next_state = INIT_COMPUTE;
          end
        end
      end
      INIT_COMPUTE: begin
        next_state = CHECK_PARTITION;
      end
      CHECK_PARTITION: begin
        next_state = VERIFY;
      end
      VERIFY: begin
        if (valid_assignment) begin
          next_state = DONE;
        end else begin
          next_state = NEXT_ASSIGNMENT;
        end
      end
      NEXT_ASSIGNMENT: begin
        if (assignment_mask == (3**N) - 1) begin
          next_state = NEXT_T;
        end else begin
          next_state = CHECK_PARTITION;
        end
      end
      NEXT_T: begin
        if (T == N) begin
          next_state = DONE;
        end else begin
          next_state = CHECK_PARTITION;
        end
      end
      DONE: begin
        if (start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Configuration state logic
  always @(posedge clk) begin
    if (!rst_n) begin
      current_kid_reg <= 0;
    end else if (state == CONFIG && input_valid) begin
      // Store current teacher
      current_teachers[current_kid] <= current_teacher;
      // Store preference ranks
      for (int j = 0; j < N; j++) begin
        if (j < current_kid) begin
          preference_ranks[current_kid][j] <= preference_list[j];
        end else if (j > current_kid) begin
          preference_ranks[current_kid][j-1] <= preference_list[j];
        end
      end
      current_kid_reg <= current_kid + 1;
    end
  end

  // Compute state logic
  always @(posedge clk) begin
    if (!rst_n) begin
      T <= 0;
      assignment_mask <= 0;
      kid_counter <= 0;
      check_counter <= 0;
      pair_i <= 0;
      pair_j <= 0;
      valid_assignment <= 0;
    end else begin
      case (state)
        INIT_COMPUTE: begin
          T <= 0;
          assignment_mask <= 0;
        end
        CHECK_PARTITION: begin
          // Decode assignment_mask to proposed_assignment
          for (int i = 0; i < N; i++) begin
            proposed_assignment[i] <= assignment_mask[2*i +: 2];
          end
          kid_counter <= 0;
          check_counter <= 0;
          pair_i <= 0;
          pair_j <= 0;
          valid_assignment <= 1;
        end
        VERIFY: begin
          // Check if all kids changed teacher
          if (kid_counter < N) begin
            if (proposed_assignment[kid_counter] == current_teachers[kid_counter]) begin
              valid_assignment <= 0;
            end
            kid_counter <= kid_counter + 1;
          end else if (check_counter < N*(N-1)/2) begin
            // Check all pairs
            if (pair_j < N) begin
              if (pair_i < pair_j) begin
                if (proposed_assignment[pair_i] == proposed_assignment[pair_j]) begin
                  // Check if pair_j is in pair_i's top T
                  if (!allowed_mask[pair_i][pair_j]) begin
                    valid_assignment <= 0;
                  end
                  // Check if pair_i is in pair_j's top T
                  if (!allowed_mask[pair_j][pair_i]) begin
                    valid_assignment <= 0;
                  end
                end
                pair_j <= pair_j + 1;
              end else begin
                pair_i <= pair_i + 1;
                pair_j <= 0;
              end
            end
            check_counter <= check_counter + 1;
          end
        end
        NEXT_ASSIGNMENT: begin
          assignment_mask <= assignment_mask + 1;
        end
        NEXT_T: begin
          T <= T + 1;
          assignment_mask <= 0;
        end
        DONE: begin
          if (valid_assignment) begin
            result <= T;
            error <= 0;
          end else begin
            error <= 1;
          end
          done <= 1;
        end
      endcase
    end
  end

  // Combinational logic for allowed_mask
  always @(*) begin
    for (int i = 0; i < N; i++) begin
      for (int j = 0; j < N; j++) begin
        if (i == j) begin
          allowed_mask[i][j] = 0;
        end else begin
          allowed_mask[i][j] = (preference_ranks[i][j] < T);
        end
      end
    end
  end

endmodule