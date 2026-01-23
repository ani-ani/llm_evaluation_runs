module catalan_number(
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state;
  reg [3:0] i; // Current index being computed
  reg [3:0] j; // Inner loop index
  reg [31:0] dp [0:10]; // Lookup table for Catalan numbers
  reg [31:0] sum;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      j <= 0;
      sum <= 0;
      result <= 0;
      done <= 0;
      for (int k = 0; k < 11; k = k + 1) begin
        dp[k] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            i <= 2;
            j <= 0;
            sum <= 0;
            dp[0] <= 1;
            dp[1] <= 1;
            done <= 0;
          end
        end
        PROCESSING: begin
          if (j < i) begin
            sum <= sum + (dp[j] * dp[i - 1 - j]);
            j <= j + 1;
          end else begin
            dp[i] <= sum;
            if (i == n) begin
              state <= DONE;
              result <= dp[i];
              done <= 1;
            end else begin
              i <= i + 1;
              j <= 0;
              sum <= 0;
            end
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

endmodule