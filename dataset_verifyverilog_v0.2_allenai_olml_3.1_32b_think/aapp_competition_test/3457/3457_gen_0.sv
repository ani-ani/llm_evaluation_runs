module hopscotch_paths(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [3:0] X,
  input [3:0] Y,
  output reg [31:0] result,
  output reg done
);

parameter MAX_N = 8;
localparam MOD = 1000000007;

reg [31:0] dp [0:MAX_N][0:MAX_N];
reg [2:0] state;
reg [3:0] i, j, target_N, min_x, min_y;
reg [31:0] sum_val;
reg start_flag;

localparam IDLE = 0, INIT = 1, LOOP_I = 2, LOOP_J = 3, COMPUTE = 4, DONE = 5;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    i <= 0;
    j <= 0;
    target_N <= 0;
    min_x <= 0;
    min_y <= 0;
    sum_val <= 0;
    result <= 0;
    done <= 0;
    start_flag <= 0;
    dp[0][0] <= 1; // Initialize base case
  end else begin
    if (state == IDLE) begin
      if (start)
        state <= INIT;
        start_flag <= 1;
    end
    else if (state == INIT) begin
      target_N <= (N > MAX_N) ? MAX_N : N;
      min_x <= X;
      min_y <= Y;
      state <= LOOP_I;
      i <= 0;
      j <= 0;
    end
    else if (state == LOOP_I) begin
      if (i < target_N) begin
        i <= i + 1;
        j <= 0;
        state <= LOOP_J;
      end else begin
        if (i == target_N && j == target_N) begin
          state <= DONE;
          result <= dp[target_N][target_N];
          done <= 1;
        end else begin
          state <= DONE;
          done <= 1;
        end
      end
    end
    else if (state == LOOP_J) begin
      if (j < target_N) begin
        j <= j + 1;
        state <= COMPUTE;
      end else begin
        state <= LOOP_I;
      end
    end
    else if (state == COMPUTE) begin
      sum_val <= 0;
      if (i >= min_x && j >= min_y) begin
        for (int ii=0; ii<=i-min_x; ii++) begin
          for (int jj=0; jj<=j-min_y; jj++) begin
            sum_val += dp[ii][jj];
          end
        end
        sum_val %= MOD;
        dp[i][j] <= sum_val;
      end else begin
        dp[i][j] <= 0;
      end
      state <= LOOP_J;
    end
  end
end

endmodule