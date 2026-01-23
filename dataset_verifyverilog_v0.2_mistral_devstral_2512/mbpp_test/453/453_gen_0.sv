module sum_even_factors (
  input clk,
  input rst_n,
  input start,
  input [5:0] n,
  output reg [7:0] result,
  output reg done
);

  parameter MAX_ITER = 16;

  typedef enum logic [2:0] {
    IDLE,
    CHECK_ODD,
    FACTOR_LOOP,
    ITERATE_I,
    DIVIDE_CHECK,
    COMPUTE_SUM,
    MULTIPLY_RESULT,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [5:0] i = 0;
  reg [5:0] count = 0;
  reg [5:0] temp_n = 0;
  reg [7:0] sum = 0;
  reg [5:0] iter = 0;
  reg [5:0] sqrt_n = 0;
  reg [5:0] remaining_n = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      count <= 0;
      temp_n <= 0;
      sum <= 0;
      iter <= 0;
      sqrt_n <= 0;
      remaining_n <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_ODD;
            temp_n <= n;
            sum <= 0;
            iter <= 0;
            sqrt_n <= 0;
            remaining_n <= 0;
            done <= 0;
          end
        end

        CHECK_ODD: begin
          if (n[0]) begin
            result <= 0;
            done <= 1;
            state <= DONE;
          end else begin
            state <= FACTOR_LOOP;
            i <= 2;
            sqrt_n <= compute_sqrt(n);
          end
        end

        FACTOR_LOOP: begin
          if (iter >= MAX_ITER || i > sqrt_n) begin
            state <= MULTIPLY_RESULT;
            remaining_n <= temp_n;
          end else begin
            state <= ITERATE_I;
          end
        end

        ITERATE_I: begin
          state <= DIVIDE_CHECK;
        end

        DIVIDE_CHECK: begin
          if (temp_n % i == 0) begin
            state <= COMPUTE_SUM;
            count <= 0;
          end else begin
            state <= FACTOR_LOOP;
            i <= i + 1;
            iter <= iter + 1;
          end
        end

        COMPUTE_SUM: begin
          if (i == 2) begin
            sum <= sum + (1 << (count + 1)) - 2;
          end else begin
            sum <= sum + (i**(count + 1) - 1)/(i - 1) - 1;
          end
          temp_n <= temp_n / (i**count);
          state <= FACTOR_LOOP;
          i <= i + 1;
          iter <= iter + 1;
        end

        MULTIPLY_RESULT: begin
          if (remaining_n >= 2) begin
            sum <= sum + (1 + remaining_n);
          end
          result <= sum;
          done <= 1;
          state <= DONE;
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  function [5:0] compute_sqrt(input [5:0] num);
    reg [5:0] sqrt = 0;
    reg [5:0] i;
    for (i = 0; i <= num; i = i + 1) begin
      if (i * i > num) begin
        sqrt = i - 1;
        break;
      end
    end
    return sqrt;
  endfunction

endmodule