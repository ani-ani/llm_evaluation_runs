module grade_rounding (
  input clk,
  input rst_n,
  input start,
  input [7:0] t,
  input [15:0] input_number_packed,
  output reg [127:0] result_number,
  output reg [7:0] result_length,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    FIND_TRIGGER,
    ROUNDING,
    CARRY_PROP,
    FORMAT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [127:0] internal_buffer;
  reg [7:0] buffer_length;
  reg [7:0] cursor_pos;
  reg [7:0] decimal_pos;
  reg [7:0] remaining_t;
  reg [7:0] carry_pos;
  reg [7:0] i;
  reg found_trigger;
  reg carry_active;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result_number <= 0;
      result_length <= 0;
      done <= 0;
      internal_buffer <= 0;
      buffer_length <= 0;
      cursor_pos <= 0;
      decimal_pos <= 0;
      remaining_t <= 0;
      carry_pos <= 0;
      found_trigger <= 0;
      carry_active <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = FIND_TRIGGER;
          // Initialize internal buffer with input
          for (i = 0; i < 16; i = i + 1) begin
            internal_buffer[i*8 +: 8] = input_number_packed[i*8 +: 8];
          end
          buffer_length = 16;
          remaining_t = t;
          found_trigger = 0;
          carry_active = 0;
          // Find decimal point
          for (i = 0; i < 16; i = i + 1) begin
            if (internal_buffer[i*8 +: 8] == 8'h2E) begin
              decimal_pos = i;
              break;
            end
          end
        end
      end

      FIND_TRIGGER: begin
        if (!found_trigger) begin
          // Scan fractional part for first digit >= '5'
          for (i = decimal_pos + 1; i < buffer_length; i = i + 1) begin
            if (internal_buffer[i*8 +: 8] >= 8'h35) begin
              cursor_pos = i;
              found_trigger = 1;
              break;
            end
          end
          if (found_trigger) begin
            next_state = ROUNDING;
          end else begin
            next_state = FORMAT;
          end
        end else begin
          next_state = ROUNDING;
        end
      end

      ROUNDING: begin
        if (remaining_t == 0) begin
          next_state = FORMAT;
        end else if (cursor_pos == decimal_pos) begin
          next_state = CARRY_PROP;
        end else begin
          // Move cursor left
          cursor_pos = cursor_pos - 1;
          remaining_t = remaining_t - 1;
          // Check if digit is '4' or '5'
          if (internal_buffer[cursor_pos*8 +: 8] == 8'h34 || internal_buffer[cursor_pos*8 +: 8] == 8'h35) begin
            // Increment digit
            internal_buffer[cursor_pos*8 +: 8] = internal_buffer[cursor_pos*8 +: 8] + 1;
            if (internal_buffer[cursor_pos*8 +: 8] == 8'h3A) begin
              // Handle carry
              internal_buffer[cursor_pos*8 +: 8] = 8'h30;
              carry_pos = cursor_pos - 1;
              carry_active = 1;
              next_state = CARRY_PROP;
            end
          end
        end
      end

      CARRY_PROP: begin
        if (carry_active) begin
          if (carry_pos < 0) begin
            // Add new '1' at the beginning
            for (i = buffer_length; i > 0; i = i - 1) begin
              internal_buffer[i*8 +: 8] = internal_buffer[(i-1)*8 +: 8];
            end
            internal_buffer[0 +: 8] = 8'h31;
            buffer_length = buffer_length + 1;
            carry_active = 0;
            next_state = FORMAT;
          end else if (internal_buffer[carry_pos*8 +: 8] == 8'h2E) begin
            // Skip decimal point
            carry_pos = carry_pos - 1;
          end else if (internal_buffer[carry_pos*8 +: 8] == 8'h39) begin
            // Handle '9' becoming '0'
            internal_buffer[carry_pos*8 +: 8] = 8'h30;
            carry_pos = carry_pos - 1;
          end else begin
            // Increment digit
            internal_buffer[carry_pos*8 +: 8] = internal_buffer[carry_pos*8 +: 8] + 1;
            carry_active = 0;
            next_state = FORMAT;
          end
        end else begin
          next_state = FORMAT;
        end
      end

      FORMAT: begin
        // Remove trailing decimal point or zeros
        if (decimal_pos != 0 && internal_buffer[decimal_pos*8 +: 8] == 8'h2E) begin
          // Check if there are digits after decimal
          reg has_fraction = 0;
          for (i = decimal_pos + 1; i < buffer_length; i = i + 1) begin
            if (internal_buffer[i*8 +: 8] != 8'h00) begin
              has_fraction = 1;
              break;
            end
          end
          if (!has_fraction) begin
            // Remove decimal point
            for (i = decimal_pos; i < buffer_length - 1; i = i + 1) begin
              internal_buffer[i*8 +: 8] = internal_buffer[(i+1)*8 +: 8];
            end
            buffer_length = buffer_length - 1;
          end
        end
        next_state = DONE;
      end

      DONE: begin
        done = 1;
        result_number = internal_buffer;
        result_length = buffer_length;
        if (start) begin
          next_state = IDLE;
          done = 0;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule