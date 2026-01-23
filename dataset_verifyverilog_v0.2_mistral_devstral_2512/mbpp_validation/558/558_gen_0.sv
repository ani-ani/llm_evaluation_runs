module digit_distance (
  input clk,
  input rst_n,
  input start,
  input [31:0] n1,
  input [31:0] n2,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALC_DIFF,
    EXTRACT_DIGITS,
    DONE
  } state_t;

  state_t state;
  reg [31:0] diff;
  reg [7:0] sum;
  reg [3:0] digit_count;
  reg [31:0] temp_diff;
  reg [3:0] remainder;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      diff <= 0;
      sum <= 0;
      digit_count <= 0;
      temp_diff <= 0;
      remainder <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_DIFF;
            done <= 0;
          end
        end
        CALC_DIFF: begin
          // Compute absolute difference
          if (n1 > n2) begin
            diff <= n1 - n2;
          end else begin
            diff <= n2 - n1;
          end
          state <= EXTRACT_DIGITS;
          sum <= 0;
          digit_count <= 0;
          temp_diff <= diff;
        end
        EXTRACT_DIGITS: begin
          // Extract digit by computing remainder and division by 10
          remainder <= temp_diff % 10;
          sum <= sum + remainder;
          temp_diff <= temp_diff / 10;
          digit_count <= digit_count + 1;
          
          // Check if all digits extracted (max 10 iterations)
          if (temp_diff == 0 || digit_count == 9) begin
            state <= DONE;
          end
        end
        DONE: begin
          result <= sum;
          done <= 1;
          if (!start) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule