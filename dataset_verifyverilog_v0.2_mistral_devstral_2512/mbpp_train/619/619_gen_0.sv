module move_num (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  output reg [7:0] char_out,
  output reg valid_out,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INPUT_COLLECT,
    OUTPUT_NON_DIGITS,
    OUTPUT_DIGITS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Buffers
  reg [7:0] non_digit_buffer [0:15];
  reg [7:0] digit_buffer [0:15];

  // Counters
  reg [3:0] input_counter;
  reg [3:0] non_digit_counter;
  reg [3:0] digit_counter;
  reg [3:0] output_counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      input_counter <= 0;
      non_digit_counter <= 0;
      digit_counter <= 0;
      output_counter <= 0;
      char_out <= 0;
      valid_out <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = INPUT_COLLECT;
      end
      INPUT_COLLECT: begin
        if (input_counter == 15) next_state = OUTPUT_NON_DIGITS;
      end
      OUTPUT_NON_DIGITS: begin
        if (output_counter == 15) next_state = OUTPUT_DIGITS;
      end
      OUTPUT_DIGITS: begin
        if (output_counter == 15) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Input collection logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      input_counter <= 0;
      non_digit_counter <= 0;
      digit_counter <= 0;
    end else if (current_state == INPUT_COLLECT && valid_in) begin
      if (char_in >= 8'h30 && char_in <= 8'h39) begin
        digit_buffer[digit_counter] <= char_in;
        digit_counter <= digit_counter + 1;
      end else begin
        non_digit_buffer[non_digit_counter] <= char_in;
        non_digit_counter <= non_digit_counter + 1;
      end
      input_counter <= input_counter + 1;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      output_counter <= 0;
      char_out <= 0;
      valid_out <= 0;
    end else begin
      case (current_state)
        OUTPUT_NON_DIGITS: begin
          if (output_counter < non_digit_counter) begin
            char_out <= non_digit_buffer[output_counter];
            valid_out <= 1;
          end else begin
            char_out <= 0;
            valid_out <= 0;
          end
          output_counter <= output_counter + 1;
        end
        OUTPUT_DIGITS: begin
          if (output_counter < digit_counter) begin
            char_out <= digit_buffer[output_counter];
            valid_out <= 1;
          end else begin
            char_out <= 0;
            valid_out <= 0;
          end
          output_counter <= output_counter + 1;
        end
        DONE: begin
          done <= 1;
          char_out <= 0;
          valid_out <= 0;
        end
        default: begin
          char_out <= 0;
          valid_out <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule