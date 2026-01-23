module digit_rearrange (
  input clk,
  input rst_n,
  input start,
  input [31:0] digit_vector,
  input [2:0] num_digits,
  output reg [39:0] result,
  output reg [3:0] result_length,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    COUNT_DIGITS,
    REMOVE_SPECIAL,
    COMPUTE_PREFIX,
    FIND_PERMUTATION,
    CONSTRUCT_RESULT,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [3:0] digit_count [0:9];
  reg [3:0] prefix_digits [0:7];
  reg [3:0] permutation;
  reg [3:0] prefix_length;
  reg [3:0] prefix_mod;
  reg [3:0] perm_index;
  reg [3:0] result_digits [0:9];
  reg [3:0] temp_digits [0:7];
  reg [3:0] temp_length;
  reg [3:0] i, j, k;
  reg [3:0] current_digit;
  reg [3:0] current_mod;
  reg [3:0] perm_value;
  reg [3:0] perm_digits [0:3];
  reg [3:0] perm_map [0:6];

  // Initialize permutation map
  initial begin
    perm_map[0] = 4'b0001_1000_0110_1001; // 1869
    perm_map[1] = 4'b0001_1000_1001_0110; // 1896
    perm_map[2] = 4'b0001_1001_1000_0110; // 1986
    perm_map[3] = 4'b0001_0110_1001_1000; // 1698
    perm_map[4] = 4'b0110_0001_1001_1000; // 6198
    perm_map[5] = 4'b0001_0110_1000_1001; // 1689
    perm_map[6] = 4'b0001_1001_0110_1000; // 1968
  end

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      prefix_length <= 0;
      temp_length <= 0;
      prefix_mod <= 0;
      perm_index <= 0;
      current_mod <= 0;
      for (int m = 0; m < 10; m = m + 1) begin
        digit_count[m] <= 0;
      end
      for (int m = 0; m < 8; m = m + 1) begin
        prefix_digits[m] <= 0;
        temp_digits[m] <= 0;
      end
      for (int m = 0; m < 10; m = m + 1) begin
        result_digits[m] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COUNT_DIGITS;
            i <= 0;
            for (int m = 0; m < 10; m = m + 1) begin
              digit_count[m] <= 0;
            end
          end
        end

        COUNT_DIGITS: begin
          if (i < num_digits) begin
            current_digit <= digit_vector[(i*4)+:4];
            digit_count[current_digit] <= digit_count[current_digit] + 1;
            i <= i + 1;
          end else begin
            state <= REMOVE_SPECIAL;
            i <= 0;
            temp_length <= 0;
          end
        end

        REMOVE_SPECIAL: begin
          if (i < 4) begin
            case (i)
              0: current_digit <= 4'b0001; // '1'
              1: current_digit <= 4'b0110; // '6'
              2: current_digit <= 4'b1000; // '8'
              3: current_digit <= 4'b1001; // '9'
            endcase
            if (digit_count[current_digit] > 0) begin
              digit_count[current_digit] <= digit_count[current_digit] - 1;
            end
            i <= i + 1;
          end else begin
            state <= COMPUTE_PREFIX;
            i <= 0;
            j <= 0;
            temp_length <= 0;
            current_mod <= 0;
          end
        end

        COMPUTE_PREFIX: begin
          if (i < 10) begin
            if (digit_count[i] > 0) begin
              temp_digits[temp_length] <= i;
              temp_length <= temp_length + 1;
              current_mod <= (current_mod * 10 + i) % 7;
            end
            i <= i + 1;
          end else begin
            state <= FIND_PERMUTATION;
            prefix_length <= temp_length;
            prefix_mod <= current_mod;
            perm_index <= 0;
          end
        end

        FIND_PERMUTATION: begin
          if (perm_index < 7) begin
            perm_value <= perm_map[perm_index];
            if ((prefix_mod * 10000 + perm_value) % 7 == 0) begin
              permutation <= perm_value;
              state <= CONSTRUCT_RESULT;
              i <= 0;
              j <= 0;
              k <= 0;
            end
            perm_index <= perm_index + 1;
          end else begin
            state <= DONE;
            valid <= 0;
          end
        end

        CONSTRUCT_RESULT: begin
          if (i < prefix_length) begin
            result_digits[i] <= temp_digits[i];
            i <= i + 1;
          end else if (j < 4) begin
            result_digits[i] <= permutation[(j*4)+:4];
            i <= i + 1;
            j <= j + 1;
          end else if (k < (10 - prefix_length - 4)) begin
            result_digits[i] <= 4'b0000;
            i <= i + 1;
            k <= k + 1;
          end else begin
            state <= DONE;
            valid <= 1;
          end
        end

        DONE: begin
          done <= 1;
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

  // Output assignment
  always @(posedge clk) begin
    if (state == DONE) begin
      result <= {result_digits[9], result_digits[8], result_digits[7], result_digits[6], 
                 result_digits[5], result_digits[4], result_digits[3], result_digits[2], 
                 result_digits[1], result_digits[0]};
      result_length <= 10;
    end else begin
      result <= 0;
      result_length <= 0;
    end
  end

endmodule