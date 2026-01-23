module knight_arrangements (
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [3:0] m,
  output reg [29:0] result,
  output reg done
);

  // Parameters
  localparam MOD = 1000000009;
  localparam IDLE = 2'b00;
  localparam COMPUTE_COL = 2'b01;
  localparam OUTPUT = 2'b10;

  // State machine
  reg [1:0] state;
  reg [1:0] next_state;

  // DP table and related registers
  reg [29:0] dp [0:15]; // 2^4 = 16 possible states (n<=4)
  reg [29:0] new_dp [0:15];
  reg [3:0] col_cnt;
  reg [3:0] state_cnt;
  reg [3:0] prev_state_cnt;
  reg [29:0] temp;

  // Initialize DP table
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 30'b0;
      col_cnt <= 4'b0;
      state_cnt <= 4'b0;
      prev_state_cnt <= 4'b0;
      for (int i = 0; i < 16; i = i + 1) begin
        dp[i] <= 30'b0;
        new_dp[i] <= 30'b0;
      end
    end else begin
      state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = COMPUTE_COL;
          // Initialize DP table for first column
          for (int i = 0; i < 16; i = i + 1) begin
            if (i < (1 << n)) begin
              new_dp[i] = 1; // Each state is valid for first column
            end else begin
              new_dp[i] = 0;
            end
          end
          col_cnt = 0;
        end
      end
      COMPUTE_COL: begin
        if (col_cnt == m - 1) begin
          next_state = OUTPUT;
        end else begin
          // Compute new DP for next column
          for (int i = 0; i < 16; i = i + 1) begin
            new_dp[i] = 0;
          end
          for (int prev_state = 0; prev_state < (1 << n); prev_state = prev_state + 1) begin
            if (dp[prev_state] != 0) begin
              for (int curr_state = 0; curr_state < (1 << n); curr_state = curr_state + 1) begin
                if (is_valid_transition(prev_state, curr_state, n)) begin
                  temp = dp[prev_state] + new_dp[curr_state];
                  if (temp >= MOD) begin
                    new_dp[curr_state] = temp - MOD;
                  end else begin
                    new_dp[curr_state] = temp;
                  end
                end
              end
            end
          end
          // Copy new_dp to dp
          for (int i = 0; i < 16; i = i + 1) begin
            dp[i] = new_dp[i];
          end
          col_cnt = col_cnt + 1;
        end
      end
      OUTPUT: begin
        // Sum all valid states for the last column
        temp = 0;
        for (int i = 0; i < (1 << n); i = i + 1) begin
          temp = temp + dp[i];
          if (temp >= MOD) begin
            temp = temp - MOD;
          end
        end
        result = temp;
        done = 1'b1;
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Function to check valid transition between states
  function automatic bit is_valid_transition;
    input [3:0] prev_state;
    input [3:0] curr_state;
    input [1:0] n;
    integer i, j;
    begin
      is_valid_transition = 1'b1;
      // Check for 2x3 attack patterns between prev_state and curr_state
      // Since we're processing column-by-column, we need to check if knights in
      // current column and previous column form L-shapes
      for (i = 0; i < n; i = i + 1) begin
        if (curr_state[i]) begin
          // Check for knights in previous column that would attack
          // Check for |r1-r2|=1 and |c1-c2|=2 (since columns are 2 apart)
          if (i > 0 && prev_state[i-1]) begin
            is_valid_transition = 1'b0;
          end
          if (i < n-1 && prev_state[i+1]) begin
            is_valid_transition = 1'b0;
          end
        end
      end
    end
  endfunction

endmodule