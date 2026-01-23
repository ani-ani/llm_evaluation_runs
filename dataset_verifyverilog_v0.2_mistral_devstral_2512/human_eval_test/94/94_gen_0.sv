module prime_digit_sum (
  input clk,
  input rst_n,
  input start,
  input [4:0] list_size,
  input [15:0] list_data [0:7],
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    FIND_PRIME,
    CHECK_PRIME,
    CALCULATE_DIGITS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] current_number;
  reg [15:0] max_prime;
  reg [3:0] list_index;
  reg [15:0] divisor;
  reg [15:0] temp_number;
  reg [7:0] digit_sum;
  reg [3:0] digit_index;
  reg [15:0] sqrt_n;
  reg is_prime;
  reg [3:0] counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 8'h0;
      done <= 1'b0;
      list_index <= 4'd0;
      max_prime <= 16'h0;
      current_number <= 16'h0;
      divisor <= 16'h0;
      temp_number <= 16'h0;
      digit_sum <= 8'h0;
      digit_index <= 4'd0;
      sqrt_n <= 16'h0;
      is_prime <= 1'b0;
      counter <= 4'd0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (list_index == list_size - 1) next_state = FIND_PRIME;
      end
      FIND_PRIME: begin
        if (list_index == list_size - 1) next_state = CALCULATE_DIGITS;
        else next_state = CHECK_PRIME;
      end
      CHECK_PRIME: begin
        if (counter == 4'd100) next_state = FIND_PRIME;
      end
      CALCULATE_DIGITS: begin
        if (digit_index == 4'd5) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // State actions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          result <= 8'h0;
        end
        LOAD: begin
          current_number <= list_data[list_index];
          list_index <= list_index + 1'b1;
        end
        FIND_PRIME: begin
          if (current_number > max_prime && is_prime) begin
            max_prime <= current_number;
          end
          list_index <= list_index + 1'b1;
          is_prime <= 1'b0;
        end
        CHECK_PRIME: begin
          if (counter == 4'd0) begin
            // Initialize prime check
            if (current_number <= 1) is_prime <= 1'b0;
            else if (current_number == 2) is_prime <= 1'b1;
            else if (current_number[0] == 1'b0) is_prime <= 1'b0; // Even number
            else begin
              is_prime <= 1'b1;
              divisor <= 3;
              sqrt_n <= 90; // sqrt(8191) ≈ 90.5
            end
          end else if (is_prime) begin
            if (divisor <= sqrt_n && current_number % divisor == 0) begin
              is_prime <= 1'b0;
            end
            divisor <= divisor + 2;
          end
          counter <= counter + 1'b1;
        end
        CALCULATE_DIGITS: begin
          if (digit_index == 4'd0) begin
            temp_number <= max_prime;
            digit_sum <= 8'h0;
          end
          digit_sum <= digit_sum + temp_number % 10;
          temp_number <= temp_number / 10;
          digit_index <= digit_index + 1'b1;
        end
        DONE: begin
          result <= digit_sum;
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule