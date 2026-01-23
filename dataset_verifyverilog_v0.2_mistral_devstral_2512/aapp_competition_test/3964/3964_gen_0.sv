module good_plans(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [4:0] m,
  input [4:0] b,
  input [31:0] mod_val,
  input [3:0] a_val,
  input a_val_valid,
  input a_val_done,
  output reg [31:0] result,
  output reg done,
  output reg wait_for_a
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] LOAD_PARAMS = 3'b001;
  localparam [2:0] LOAD_A = 3'b010;
  localparam [2:0] COMPUTE = 3'b011;
  localparam [2:0] FINISHED = 3'b100;

  reg [2:0] state, next_state;

  // DP table: 17x17 (lines 0-16, bugs 0-16)
  reg [31:0] dp [0:16][0:16];

  // Programmer bugs storage (max 8 programmers)
  reg [3:0] a [0:7];
  reg [2:0] a_ptr;

  // Counters for computation
  reg [3:0] prog_idx;
  reg [4:0] line_idx;
  reg [4:0] bug_idx;

  // Temporary registers for computation
  reg [31:0] temp_sum;
  reg [31:0] temp_val;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      wait_for_a <= 0;
      result <= 0;
      a_ptr <= 0;
      prog_idx <= 0;
      line_idx <= 0;
      bug_idx <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD_PARAMS;
      end
      LOAD_PARAMS: begin
        next_state = LOAD_A;
      end
      LOAD_A: begin
        if (a_val_done) next_state = COMPUTE;
      end
      COMPUTE: begin
        if (prog_idx == n && line_idx == 0 && bug_idx == 0) next_state = FINISHED;
      end
      FINISHED: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      wait_for_a <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          wait_for_a <= 0;
        end
        LOAD_A: begin
          wait_for_a <= 1;
          done <= 0;
        end
        FINISHED: begin
          done <= 1;
          wait_for_a <= 0;
        end
        default: begin
          done <= 0;
          wait_for_a <= 0;
        end
      endcase
    end
  end

  // LOAD_PARAMS state: Initialize DP table
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize DP table
      for (integer i = 0; i < 17; i = i + 1) begin
        for (integer j = 0; j < 17; j = j + 1) begin
          dp[i][j] <= 0;
        end
      end
      dp[0][0] <= 1;
    end else if (state == LOAD_PARAMS) begin
      // Initialize DP table
      for (integer i = 0; i < 17; i = i + 1) begin
        for (integer j = 0; j < 17; j = j + 1) begin
          dp[i][j] <= 0;
        end
      end
      dp[0][0] <= 1;
    end
  end

  // LOAD_A state: Store programmer bugs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_ptr <= 0;
    end else if (state == LOAD_A && a_val_valid) begin
      a[a_ptr] <= a_val;
      a_ptr <= a_ptr + 1;
    end
  end

  // COMPUTE state: Update DP table
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prog_idx <= 0;
      line_idx <= 0;
      bug_idx <= 0;
    end else if (state == COMPUTE) begin
      if (prog_idx < n) begin
        if (line_idx == 0 && bug_idx == 0) begin
          // Start new programmer
          line_idx <= 1;
          bug_idx <= a[prog_idx];
        end else if (line_idx <= m && bug_idx <= b) begin
          // Update DP table
          if (bug_idx >= a[prog_idx]) begin
            temp_sum = dp[line_idx][bug_idx] + dp[line_idx - 1][bug_idx - a[prog_idx]];
            temp_val = temp_sum % mod_val;
            dp[line_idx][bug_idx] <= temp_val;
          end
          // Move to next bug or line
          if (bug_idx == b) begin
            bug_idx <= a[prog_idx];
            line_idx <= line_idx + 1;
          end else begin
            bug_idx <= bug_idx + 1;
          end
        end else begin
          // Move to next programmer
          prog_idx <= prog_idx + 1;
          line_idx <= 0;
          bug_idx <= 0;
        end
      end else begin
        // Compute result
        result <= 0;
        for (integer k = 0; k <= b; k = k + 1) begin
          result <= (result + dp[m][k]) % mod_val;
        end
      end
    end
  end

endmodule