module digit_validator (
  input clk,
  input rst_n,
  input start,
  input [31:0] number,
  output reg valid,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    EXTRACT_DIGIT,
    CHECK_COUNT,
    UPDATE_COUNTER,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Digit counters (4-bit each for digits 0-9)
  reg [3:0] digit_count [0:9];

  // Internal registers
  reg [3:0] current_digit;
  reg [31:0] temp_number;
  reg [3:0] digit_index;
  reg [3:0] cycle_count;
  reg violation_detected;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      valid <= 1'b0;
      done <= 1'b0;
      violation_detected <= 1'b0;
      digit_index <= 4'd0;
      cycle_count <= 4'd0;
      for (int i = 0; i < 10; i = i + 1) begin
        digit_count[i] <= 4'd0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = EXTRACT_DIGIT;
          temp_number = number;
          digit_index = 4'd0;
          cycle_count = 4'd0;
          violation_detected = 1'b0;
          for (int i = 0; i < 10; i = i + 1) begin
            digit_count[i] = 4'd0;
          end
        end
      end

      EXTRACT_DIGIT: begin
        if (cycle_count == 4'd4) begin
          next_state = CHECK_COUNT;
        end
      end

      CHECK_COUNT: begin
        next_state = UPDATE_COUNTER;
      end

      UPDATE_COUNTER: begin
        if (digit_index == 4'd7) begin
          next_state = DONE;
        else begin
          next_state = EXTRACT_DIGIT;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Digit extraction and processing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_digit <= 4'd0;
      cycle_count <= 4'd0;
    end else begin
      case (current_state)
        EXTRACT_DIGIT: begin
          if (cycle_count < 4'd4) begin
            cycle_count <= cycle_count + 1'b1;
            // Extract digit by digit (mod 10)
            current_digit <= temp_number % 10;
            temp_number <= temp_number / 10;
          end
        end

        CHECK_COUNT: begin
          // Check if count[current_digit] <= current_digit
          if (digit_count[current_digit] > current_digit) begin
            violation_detected <= 1'b1;
          end
        end

        UPDATE_COUNTER: begin
          // Increment counter for current digit
          digit_count[current_digit] <= digit_count[current_digit] + 1'b1;
          digit_index <= digit_index + 1'b1;
          cycle_count <= 4'd0;
        end

        DONE: begin
          done <= 1'b1;
          valid <= !violation_detected;
        end

        default: ;
      endcase
    end
  end

endmodule