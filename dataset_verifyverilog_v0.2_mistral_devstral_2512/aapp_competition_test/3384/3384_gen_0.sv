module closest_handsome(
  input clk,
  input rst_n,
  input start,
  input [31:0] input_number,
  output reg [31:0] result_lower,
  output reg [31:0] result_upper,
  output reg found_lower,
  output reg found_upper,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SEARCH_LOWER,
    SEARCH_UPPER,
    COMPLETE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [31:0] current_number;
  reg [31:0] lower_candidate;
  reg [31:0] upper_candidate;
  reg [31:0] lower_distance;
  reg [31:0] upper_distance;
  reg [31:0] search_counter;
  reg [31:0] temp_number;
  reg [31:0] temp_bcd;
  reg [7:0] search_limit;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      found_lower <= 0;
      found_upper <= 0;
      result_lower <= 0;
      result_upper <= 0;
      search_counter <= 0;
      lower_candidate <= 0;
      upper_candidate <= 0;
      lower_distance <= 0;
      upper_distance <= 0;
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
          next_state = SEARCH_LOWER;
        end
      end
      SEARCH_LOWER: begin
        if (search_counter == 255 || (current_number == 0 && search_counter > 0)) begin
          next_state = SEARCH_UPPER;
        end
      end
      SEARCH_UPPER: begin
        if (search_counter == 255) begin
          next_state = COMPLETE;
        end
      end
      COMPLETE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // State actions
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else begin
      case (current_state)
        IDLE: begin
          done <= 0;
          found_lower <= 0;
          found_upper <= 0;
          result_lower <= 0;
          result_upper <= 0;
          if (start) begin
            current_number <= input_number;
            search_counter <= 0;
            lower_candidate <= 0;
            upper_candidate <= 0;
            lower_distance <= 0;
            upper_distance <= 0;
          end
        end
        SEARCH_LOWER: begin
          if (search_counter == 0) begin
            // Check if input number itself is handsome
            if (is_handsome(current_number)) begin
              lower_candidate <= current_number;
              lower_distance <= 0;
              found_lower <= 1;
            end
            temp_number <= current_number - 1;
          end else begin
            temp_number <= temp_number - 1;
          end

          // Check if temp_number is handsome
          if (is_handsome(temp_number) && temp_number != 0) begin
            lower_candidate <= temp_number;
            lower_distance <= search_counter + 1;
            found_lower <= 1;
          end

          search_counter <= search_counter + 1;

          // Transition to SEARCH_UPPER when done
          if (search_counter == 255 || (temp_number == 0 && search_counter > 0)) begin
            search_counter <= 0;
          end
        end
        SEARCH_UPPER: begin
          if (search_counter == 0) begin
            temp_number <= current_number + 1;
          end else begin
            temp_number <= temp_number + 1;
          end

          // Check if temp_number is handsome
          if (is_handsome(temp_number)) begin
            upper_candidate <= temp_number;
            upper_distance <= search_counter + 1;
            found_upper <= 1;
          end

          search_counter <= search_counter + 1;

          // Transition to COMPLETE when done
          if (search_counter == 255) begin
            // Determine final results
            if (found_lower && found_upper) begin
              if (lower_distance <= upper_distance) begin
                result_lower <= lower_candidate;
                result_upper <= 0;
                found_upper <= 0;
              end else begin
                result_upper <= upper_candidate;
                result_lower <= 0;
                found_lower <= 0;
              end
            end else if (found_lower) begin
              result_lower <= lower_candidate;
            end else if (found_upper) begin
              result_upper <= upper_candidate;
            end
            done <= 1;
          end
        end
        COMPLETE: begin
          done <= 1;
          if (!start) begin
            done <= 0;
          end
        end
      endcase
    end
  end

  // Helper module: is_handsome
  function automatic logic is_handsome(input [31:0] num);
    logic [3:0] digits[0:7];
    logic [31:0] temp = num;
    logic [3:0] digit;
    logic prev_parity, current_parity;
    integer i;

    // Extract digits
    for (i = 0; i < 8; i = i + 1) begin
      digit = temp[3:0];
      digits[i] = digit;
      temp = temp >> 4;
    end

    // Check if single digit
    if (num[31:4] == 0 && num[3:0] != 0) begin
      return 1;
    end

    // Check consecutive digits
    for (i = 0; i < 7; i = i + 1) begin
      if (digits[i] != 0 || (i > 0 && digits[i-1] != 0)) begin
        prev_parity = digits[i][0];
        current_parity = digits[i+1][0];
        if (prev_parity == current_parity) begin
          return 0;
        end
      end
    end

    return 1;
  endfunction

endmodule