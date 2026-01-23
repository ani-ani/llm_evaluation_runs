module is_undulating (
  input clk,
  input rst_n,
  input start,
  input [31:0] number,
  output reg result,
  output reg done
);

  // Define states
  typedef enum logic [1:0] {
    IDLE,
    EXTRACT_DIGITS,
    CHECK_PATTERN,
    DONE
  } state_t;

  state_t state;
  reg [7:0] digits [0:7]; // Store up to 8 digits (LSB first)
  reg [2:0] digit_count; // Count of digits extracted
  reg [31:0] temp_number; // Temporary storage for number during extraction
  reg [3:0] current_digit; // Current digit being extracted
  reg [2:0] check_index; // Index for pattern checking
  reg [1:0] cycle_count; // Cycle counter for overhead

  // Initialize outputs
  initial begin
    result = 0;
    done = 0;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      digit_count <= 0;
      temp_number <= 0;
      current_digit <= 0;
      check_index <= 0;
      cycle_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= EXTRACT_DIGITS;
            temp_number <= number;
            digit_count <= 0;
          end
        end

        EXTRACT_DIGITS: begin
          if (digit_count < 8 && temp_number != 0) begin
            current_digit <= temp_number % 10;
            digits[digit_count] <= current_digit;
            temp_number <= temp_number / 10;
            digit_count <= digit_count + 1;
          end else begin
            if (digit_count <= 2) begin
              result <= 0;
              state <= DONE;
              cycle_count <= 0;
            end else begin
              state <= CHECK_PATTERN;
              check_index <= 2;
            end
          end
        end

        CHECK_PATTERN: begin
          if (check_index < digit_count) begin
            if (digits[check_index] != digits[check_index - 2]) begin
              result <= 0;
              state <= DONE;
              cycle_count <= 0;
            end else begin
              check_index <= check_index + 1;
            end
          end else begin
            result <= 1;
            state <= DONE;
            cycle_count <= 0;
          end
        end

        DONE: begin
          done <= 1;
          if (cycle_count < 1) begin
            cycle_count <= cycle_count + 1;
          end else begin
            done <= 0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule