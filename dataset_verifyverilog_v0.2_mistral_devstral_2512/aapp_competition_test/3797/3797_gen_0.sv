module coloring_counter (
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [7:0] M_i,
  input [2:0] l_i,
  input [2:0] r_i,
  input [1:0] x_i,
  output reg [29:0] result,
  output reg done
);

  // Constants
  localparam MOD = 30'b1111111111111111111111111111101; // 10^9+7
  localparam MAX_M = 16;
  localparam MAX_N = 8;

  // State machine
  typedef enum logic [3:0] {
    IDLE,
    SETUP,
    CHECK_COLORING,
    UPDATE_RESULT,
    DONE
  } state_t;
  state_t current_state, next_state;

  // Condition storage
  logic [2:0] conditions_l [0:MAX_M-1];
  logic [2:0] conditions_r [0:MAX_M-1];
  logic [1:0] conditions_x [0:MAX_M-1];
  logic valid [0:MAX_M-1];

  // Internal registers
  reg [7:0] M;
  reg [7:0] condition_count;
  reg [2:0] current_coloring [0:MAX_N-1];
  reg [2:0] coloring_counter_reg;
  reg [29:0] sum;
  reg [2:0] i, j;
  reg condition_valid;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      result <= 0;
      M <= 0;
      condition_count <= 0;
      sum <= 0;
      coloring_counter_reg <= 0;
      i <= 0;
      j <= 0;
      for (int k = 0; k < MAX_M; k++) begin
        valid[k] <= 0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = SETUP;
      end
      SETUP: begin
        if (condition_count == M_i - 1) begin
          next_state = CHECK_COLORING;
        end
      end
      CHECK_COLORING: begin
        if (coloring_counter_reg == (1 << N) - 1) begin
          next_state = DONE;
        end else if (i == N - 1) begin
          next_state = UPDATE_RESULT;
        end
      end
      UPDATE_RESULT: begin
        if (j == M - 1) begin
          next_state = CHECK_COLORING;
        end
      end
      DONE: begin
        done = 1;
      end
      default: next_state = IDLE;
    endcase
  end

  // Condition storage logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      M <= 0;
      condition_count <= 0;
    end else if (current_state == SETUP && start) begin
      if (condition_count < M_i) begin
        conditions_l[condition_count] <= l_i;
        conditions_r[condition_count] <= r_i;
        conditions_x[condition_count] <= x_i;
        valid[condition_count] <= 1;
        condition_count <= condition_count + 1;
      end
      if (condition_count == M_i - 1) begin
        M <= M_i;
      end
    end
  end

  // Coloring generation logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      coloring_counter_reg <= 0;
      i <= 0;
    end else if (current_state == CHECK_COLORING) begin
      if (coloring_counter_reg == 0) begin
        for (int k = 0; k < MAX_N; k++) begin
          current_coloring[k] <= 0;
        end
      end
      if (i < N) begin
        current_coloring[i] <= current_coloring[i] + 1;
        if (current_coloring[i] == 3) begin
          current_coloring[i] <= 0;
          i <= i + 1;
        end else begin
          i <= 0;
        end
      end
      if (i == 0 && current_coloring[0] == 0) begin
        coloring_counter_reg <= coloring_counter_reg + 1;
      end
    end
  end

  // Condition checking logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      j <= 0;
      condition_valid <= 1;
    end else if (current_state == UPDATE_RESULT) begin
      if (j < M) begin
        if (valid[j]) begin
          logic [2:0] l = conditions_l[j];
          logic [2:0] r = conditions_r[j];
          logic [1:0] x = conditions_x[j];
          logic all_match = 1;
          for (int k = l; k <= r; k++) begin
            if (current_coloring[k] != x) begin
              all_match = 0;
            end
          end
          if (!all_match) begin
            condition_valid = 0;
          end
        end
        j <= j + 1;
      end else begin
        j <= 0;
      end
    end
  end

  // Result update logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum <= 0;
    end else if (current_state == UPDATE_RESULT && j == M) begin
      if (condition_valid) begin
        sum <= (sum + 1) % MOD;
      end
      condition_valid <= 1;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (current_state == DONE) begin
      result <= sum;
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule