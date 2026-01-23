module digit_sum_optimizer (
  input clk,
  input rst_n,
  input start,
  input [11:0] n,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    COMPUTE_A,
    COMPUTE_B,
    CHECK_MAX,
    DONE
  } state_t;

  state_t state;
  reg [11:0] a;
  reg [11:0] b;
  reg [7:0] sum_a;
  reg [7:0] sum_b;
  reg [7:0] max_sum;
  reg [3:0] digit_sum_state;
  reg [11:0] current_num;
  reg [7:0] current_sum;
  reg [3:0] digit;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      a <= 0;
      b <= 0;
      sum_a <= 0;
      sum_b <= 0;
      max_sum <= 0;
      digit_sum_state <= 0;
      current_num <= 0;
      current_sum <= 0;
      digit <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE_A;
            a <= 0;
            max_sum <= 0;
          end
        end
        COMPUTE_A: begin
          current_num <= a;
          current_sum <= 0;
          digit_sum_state <= 0;
          state <= COMPUTE_B;
        end
        COMPUTE_B: begin
          if (digit_sum_state == 0) begin
            sum_a <= current_sum;
            current_num <= n - a;
            current_sum <= 0;
            digit_sum_state <= 0;
          end
          if (digit_sum_state == 3) begin
            sum_b <= current_sum;
            state <= CHECK_MAX;
          end
        end
        CHECK_MAX: begin
          if (sum_a + sum_b > max_sum) begin
            max_sum <= sum_a + sum_b;
          end
          if (a == n) begin
            state <= DONE;
          end else begin
            a <= a + 1;
            state <= COMPUTE_A;
          end
        end
        DONE: begin
          result <= max_sum;
          done <= 1;
        end
      endcase
    end
  end

  // Digit sum state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      digit_sum_state <= 0;
      current_sum <= 0;
      digit <= 0;
    end else begin
      case (digit_sum_state)
        0: begin
          if (current_num > 0) begin
            digit <= current_num % 10;
            current_num <= current_num / 10;
            current_sum <= current_sum + digit;
            digit_sum_state <= 1;
          end else begin
            digit_sum_state <= 3;
          end
        end
        1: begin
          if (current_num > 0) begin
            digit <= current_num % 10;
            current_num <= current_num / 10;
            current_sum <= current_sum + digit;
            digit_sum_state <= 2;
          end else begin
            digit_sum_state <= 3;
          end
        end
        2: begin
          if (current_num > 0) begin
            digit <= current_num % 10;
            current_num <= current_num / 10;
            current_sum <= current_sum + digit;
            digit_sum_state <= 1;
          end else begin
            digit_sum_state <= 3;
          end
        end
        3: begin
          // Done
        end
      endcase
    end
  end

endmodule