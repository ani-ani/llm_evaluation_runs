module max_sum_increasing_subseq (
  input clk,
  input rst_n,
  input start,
  input [2:0] i_index,
  input [2:0] k_index,
  input [15:0] a [0:7],
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    INIT,
    ROW_PROCESS,
    DONE
  } state_t;

  state_t state;
  reg [2:0] i;
  reg [2:0] j;
  reg [15:0] dp [0:7][0:7];
  reg [15:0] max_val;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      j <= 0;
      done <= 0;
      result <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            i <= 0;
            j <= 0;
          end
        end
        INIT: begin
          if (j == 7) begin
            state <= ROW_PROCESS;
            i <= 1;
            j <= 0;
          end else begin
            j <= j + 1;
          end
        end
        ROW_PROCESS: begin
          if (i == i_index && j == 7) begin
            state <= DONE;
            result <= dp[i_index][k_index];
            done <= 1;
          end else if (j == 7) begin
            i <= i + 1;
            j <= 0;
          end else begin
            j <= j + 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

  // Initialize first row (i=0)
  always @(posedge clk) begin
    if (state == INIT) begin
      if (a[j] > a[0] && j > 0) begin
        dp[0][j] <= a[j] + a[0];
      end else begin
        dp[0][j] <= a[j];
      end
    end
  end

  // Process rows from i=1 to i_index
  always @(posedge clk) begin
    if (state == ROW_PROCESS) begin
      if (a[j] > a[i] && j > i) begin
        max_val = (dp[i-1][i] + a[j] > dp[i-1][j]) ? dp[i-1][i] + a[j] : dp[i-1][j];
        dp[i][j] <= max_val;
      end else begin
        dp[i][j] <= dp[i-1][j];
      end
    end
  end

endmodule