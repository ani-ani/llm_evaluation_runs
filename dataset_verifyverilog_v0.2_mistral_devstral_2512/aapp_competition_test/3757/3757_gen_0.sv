module subsequence_counter(
  input clk,
  input rst_n,
  input start,
  input [15:0] a00,
  input [15:0] a01,
  input [15:0] a10,
  input [15:0] a11,
  input [7:0] result_index,
  output reg done,
  output reg valid,
  output reg [15:0] length,
  output reg result_bit
);

  // Internal state definitions
  typedef enum logic [2:0] {
    IDLE,
    COMPUTE_N0,
    COMPUTE_N1,
    CHECK_CONSISTENCY,
    CONSTRUCT_STRING,
    STORE_RESULT,
    DONE
  } state_t;

  state_t state;
  reg [7:0] n0, n1;
  reg [7:0] k, r;
  reg [7:0] i, j;
  reg [7:0] temp_n;
  reg [7:0] str_ptr;
  reg [63:0] result_buffer;

  // Compute n0 and n1
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      length <= 0;
      result_bit <= 0;
      n0 <= 0;
      n1 <= 0;
      k <= 0;
      r <= 0;
      i <= 0;
      j <= 0;
      temp_n <= 0;
      str_ptr <= 0;
      result_buffer <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE_N0;
            temp_n <= 0;
          end
        end
        COMPUTE_N0: begin
          if (temp_n == 0) begin
            if (a00 == 0) begin
              n0 <= 1; // Edge case: a00=0 implies n0=0 or 1
              state <= COMPUTE_N1;
            end else begin
              temp_n <= 1;
            end
          end else begin
            if (temp_n * (temp_n - 1) / 2 == a00) begin
              n0 <= temp_n;
              state <= COMPUTE_N1;
            end else if (temp_n == 255) begin
              n0 <= 0; // No solution
              state <= COMPUTE_N1;
            end else begin
              temp_n <= temp_n + 1;
            end
          end
        end
        COMPUTE_N1: begin
          if (temp_n == 0) begin
            if (a11 == 0) begin
              n1 <= 1; // Edge case: a11=0 implies n1=0 or 1
              state <= CHECK_CONSISTENCY;
            end else begin
              temp_n <= 1;
            end
          end else begin
            if (temp_n * (temp_n - 1) / 2 == a11) begin
              n1 <= temp_n;
              state <= CHECK_CONSISTENCY;
            end else if (temp_n == 255) begin
              n1 <= 0; // No solution
              state <= CHECK_CONSISTENCY;
            end else begin
              temp_n <= temp_n + 1;
            end
          end
        end
        CHECK_CONSISTENCY: begin
          if (n0 * n1 == a01 + a10) begin
            valid <= 1;
            state <= CONSTRUCT_STRING;
            k <= a01 / n1;
            r <= a01 % n1;
            i <= 0;
            j <= 0;
            str_ptr <= 0;
            result_buffer <= 0;
          end else begin
            valid <= 0;
            state <= DONE;
            done <= 1;
          end
        end
        CONSTRUCT_STRING: begin
          if (i < k) begin
            // Add '01' pairs
            result_buffer[str_ptr] <= 0;
            str_ptr <= str_ptr + 1;
            result_buffer[str_ptr] <= 1;
            str_ptr <= str_ptr + 1;
            i <= i + 1;
          end else if (i == k && j < r) begin
            // Add '0' followed by 'r' '1's
            result_buffer[str_ptr] <= 0;
            str_ptr <= str_ptr + 1;
            j <= j + 1;
          end else if (i == k && j == r && i < n0 - 1) begin
            // Add remaining '0's
            result_buffer[str_ptr] <= 0;
            str_ptr <= str_ptr + 1;
            i <= i + 1;
          end else if (i == n0 - 1 && j < n1 - k - r) begin
            // Add remaining '1's
            result_buffer[str_ptr] <= 1;
            str_ptr <= str_ptr + 1;
            j <= j + 1;
          end else begin
            state <= STORE_RESULT;
            length <= n0 + n1;
          end
        end
        STORE_RESULT: begin
          state <= DONE;
          done <= 1;
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

  // Output the result bit
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_bit <= 0;
    end else begin
      if (done && valid && result_index < length) begin
        result_bit <= result_buffer[result_index];
      end else begin
        result_bit <= 0;
      end
    end
  end

endmodule