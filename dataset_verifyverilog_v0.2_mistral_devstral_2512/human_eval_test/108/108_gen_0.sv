module count_nums (
  input clk,
  input rst_n,
  input start,
  input [4:0] array_size,
  input signed [7:0] arr [0:15],
  output reg [4:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_NUM,
    GET_SIGN,
    EXTRACT_DIGITS,
    SUM_DIGITS,
    CHECK_COUNT,
    DONE
  } state_t;

  state_t state, next_state;

  // Temporary registers
  reg [4:0] array_index;
  reg signed [7:0] current_num;
  reg [7:0] abs_num;
  reg sign;
  reg [7:0] digit_sum;
  reg [1:0] digit_count;
  reg [7:0] digits [0:2]; // Store up to 3 digits
  reg [1:0] digit_ptr;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      array_index <= 0;
      current_num <= 0;
      abs_num <= 0;
      sign <= 0;
      digit_sum <= 0;
      digit_count <= 0;
      digit_ptr <= 0;
      for (int i = 0; i < 3; i++) begin
        digits[i] <= 0;
      end
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_NUM;
          array_index = 0;
          result = 0;
          done = 0;
        end
      end

      LOAD_NUM: begin
        if (array_index < array_size) begin
          current_num = arr[array_index];
          next_state = GET_SIGN;
        end else begin
          next_state = DONE;
        end
      end

      GET_SIGN: begin
        if (current_num == 0) begin
          next_state = CHECK_COUNT;
        end else begin
          sign = (current_num < 0);
          abs_num = sign ? -current_num : current_num;
          digit_count = 0;
          digit_ptr = 0;
          next_state = EXTRACT_DIGITS;
        end
      end

      EXTRACT_DIGITS: begin
        if (digit_count < 3) begin
          digits[digit_count] = abs_num % 10;
          abs_num = abs_num / 10;
          digit_count = digit_count + 1;
          if (abs_num == 0) begin
            next_state = SUM_DIGITS;
          end
        end else begin
          next_state = SUM_DIGITS;
        end
      end

      SUM_DIGITS: begin
        digit_sum = 0;
        for (int i = 0; i < digit_count; i++) begin
          if (i == digit_count - 1 && sign) begin
            digit_sum = digit_sum - digits[i];
          end else begin
            digit_sum = digit_sum + digits[i];
          end
        end
        next_state = CHECK_COUNT;
      end

      CHECK_COUNT: begin
        if (digit_sum > 0) begin
          result = result + 1;
        end
        array_index = array_index + 1;
        next_state = LOAD_NUM;
      end

      DONE: begin
        done = 1;
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule