module make_palindrome (
  input clk,
  input rst_n,
  input start,
  input [4:0] str_len,
  input [15:0][7:0] str_data,
  output reg [4:0] result_len,
  output reg [31:0][7:0] result_data,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    FIND_SUFFIX,
    BUILD_RESULT,
    DONE
  } state_t;

  state_t state;
  reg [4:0] suffix_len;
  reg [4:0] i, j;
  reg [4:0] prefix_len;
  reg [4:0] result_idx;
  reg [4:0] check_start, check_end;
  reg [3:0] check_idx;
  reg is_palindrome;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result_len <= 0;
      done <= 0;
      suffix_len <= 0;
      i <= 0;
      j <= 0;
      prefix_len <= 0;
      result_idx <= 0;
      check_start <= 0;
      check_end <= 0;
      check_idx <= 0;
      is_palindrome <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= FIND_SUFFIX;
            suffix_len <= str_len;
            check_start <= 0;
            check_end <= str_len - 1;
            check_idx <= 0;
            is_palindrome <= 1;
          end
        end

        FIND_SUFFIX: begin
          if (is_palindrome) begin
            // Current suffix is palindrome, move to build result
            state <= BUILD_RESULT;
            prefix_len <= str_len - suffix_len;
            result_idx <= 0;
          end else begin
            // Check if current character pair matches
            if (str_data[check_start + check_idx] == str_data[check_end - check_idx]) begin
              if (check_idx == (check_end - check_start) / 2) begin
                // Entire substring checked and matches
                is_palindrome <= 1;
              end else begin
                check_idx <= check_idx + 1;
              end
            end else begin
              // Current suffix not palindrome, try shorter suffix
              suffix_len <= suffix_len - 1;
              check_start <= check_start + 1;
              check_end <= str_len - 1;
              check_idx <= 0;
              is_palindrome <= 1;
            end
          end
        end

        BUILD_RESULT: begin
          if (result_idx < str_len) begin
            // Copy original string
            result_data[result_idx] <= str_data[result_idx];
            result_idx <= result_idx + 1;
          end else if (result_idx < str_len + prefix_len) begin
            // Append reversed prefix
            result_data[result_idx] <= str_data[str_len - (result_idx - str_len) - 1];
            result_idx <= result_idx + 1;
          end else begin
            // Done building result
            result_len <= str_len + prefix_len;
            state <= DONE;
            done <= 1;
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