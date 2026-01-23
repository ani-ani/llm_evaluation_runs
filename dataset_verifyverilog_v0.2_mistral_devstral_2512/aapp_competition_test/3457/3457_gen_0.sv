module hopscotch_paths #(parameter MAX_N = 8) (
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [3:0] X,
  input [3:0] Y,
  output reg [31:0] result,
  output reg done
);

  // States
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    LOOP_I,
    LOOP_J,
    COMPUTE_SUM,
    DONE
  } state_t;

  state_t state;
  reg [3:0] i, j;
  reg [3:0] i_prime, j_prime;
  reg [31:0] dp [0:MAX_N][0:MAX_N];
  reg [31:0] sum;
  reg [31:0] mod_const = 32'h3B9ACA07; // 1000000007

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      j <= 0;
      i_prime <= 0;
      j_prime <= 0;
      sum <= 0;
      result <= 0;
      done <= 0;
      for (int x = 0; x <= MAX_N; x++) begin
        for (int y = 0; y <= MAX_N; y++) begin
          dp[x][y] <= 0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 0;
          end
        end
        INIT: begin
          dp[0][0] <= 1;
          i <= 0;
          j <= 0;
          state <= LOOP_I;
        end
        LOOP_I: begin
          if (i <= N) begin
            j <= 0;
            state <= LOOP_J;
          end else begin
            state <= DONE;
          end
        end
        LOOP_J: begin
          if (j <= N) begin
            if (i >= X && j >= Y) begin
              sum <= 0;
              i_prime <= 0;
              j_prime <= 0;
              state <= COMPUTE_SUM;
            end else begin
              if (i == 0 && j == 0) begin
                dp[i][j] <= 1;
              end else begin
                dp[i][j] <= 0;
              end
              j <= j + 1;
              state <= LOOP_J;
            end
          end else begin
            i <= i + 1;
            state <= LOOP_I;
          end
        end
        COMPUTE_SUM: begin
          if (i_prime <= i - X && j_prime <= j - Y) begin
            sum <= (sum + dp[i_prime][j_prime]) % mod_const;
            if (j_prime == j - Y) begin
              j_prime <= 0;
              i_prime <= i_prime + 1;
            end else begin
              j_prime <= j_prime + 1;
            end
          end else begin
            dp[i][j] <= sum;
            j <= j + 1;
            state <= LOOP_J;
          end
        end
        DONE: begin
          result <= dp[N][N];
          done <= 1;
          if (!start) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule