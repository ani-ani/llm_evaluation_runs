module min_number_finder (
  input clk,
  input rst_n,
  input start,
  input [7:0] N,
  output reg [63:0] result,
  output reg done,
  output reg impossible
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    FACTORING,
    SORTING,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [7:0] current_N;
  reg [63:0] digits = 0;
  reg [5:0] digit_count = 0;
  reg [63:0] temp_result = 0;
  reg [5:0] i, j, k;
  reg [7:0] temp_product;
  reg [63:0] best_digits = 0;
  reg [5:0] best_digit_count = 0;
  reg found_solution = 0;
  reg [63:0] sorted_digits = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      impossible <= 0;
      current_N <= 0;
      digits <= 0;
      digit_count <= 0;
      temp_result <= 0;
      best_digits <= 0;
      best_digit_count <= 0;
      found_solution <= 0;
      sorted_digits <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= FACTORING;
            current_N <= N;
            digits <= 0;
            digit_count <= 0;
            best_digits <= 0;
            best_digit_count <= 0;
            found_solution <= 0;
            impossible <= 0;
            done <= 0;
          end
        end

        FACTORING: begin
          // Try all combinations of 1-5 digits from {2,3,4,5,6,7,8,9}
          // to find one that multiplies to N
          if (digit_count < 5) begin
            for (i = 0; i < 8; i = i + 1) begin
              temp_product = 1;
              for (j = 0; j < digit_count + 1; j = j + 1) begin
                if (j < digit_count)
                  temp_product = temp_product * (digits[j*8 +: 8]);
                else
                  temp_product = temp_product * (i + 2);
              end
              if (temp_product == current_N) begin
                digits[(digit_count)*8 +: 8] = i + 2;
                if (!found_solution || (digit_count + 1) < best_digit_count) begin
                  best_digits = digits;
                  best_digit_count = digit_count + 1;
                  found_solution = 1;
                end
              end
            end
            digit_count = digit_count + 1;
          end else begin
            if (found_solution) begin
              state <= SORTING;
              temp_result = best_digits;
            end else begin
              state <= DONE;
              impossible <= 1;
              result <= 0;
              done <= 1;
            end
          end
        end

        SORTING: begin
          // Sort digits in ascending order
          for (i = 0; i < best_digit_count - 1; i = i + 1) begin
            for (j = 0; j < best_digit_count - i - 1; j = j + 1) begin
              if (temp_result[j*8 +: 8] > temp_result[(j+1)*8 +: 8]) begin
                k = temp_result[j*8 +: 8];
                temp_result[j*8 +: 8] = temp_result[(j+1)*8 +: 8];
                temp_result[(j+1)*8 +: 8] = k;
              end
            end
          end
          state <= DONE;
          result = temp_result;
          done <= 1;
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