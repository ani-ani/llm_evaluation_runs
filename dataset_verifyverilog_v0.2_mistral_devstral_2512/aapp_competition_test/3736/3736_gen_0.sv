module mirror_check (
  input clk,
  input rst_n,
  input start,
  input [15:0] char_valid,
  input [7:0] char_data [15:0],
  input [4:0] str_length,
  output reg is_mirror,
  output reg done
);

  // Define states
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  // State registers
  state_t current_state, next_state;
  reg [3:0] left_ptr;
  reg [3:0] right_ptr;

  // Valid character set
  localparam [7:0] VALID_CHARS [9:0] = '{0x41, 0x48, 0x49, 0x4D, 0x4F, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59};

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      left_ptr <= 0;
      right_ptr <= 0;
      is_mirror <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (next_state == PROCESSING) begin
        left_ptr <= left_ptr + 1;
        right_ptr <= right_ptr - 1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
          left_ptr = 0;
          right_ptr = str_length - 1;
          is_mirror = 1;
          done = 0;
        end
      end
      PROCESSING: begin
        if (left_ptr >= right_ptr) begin
          next_state = DONE;
          done = 1;
        end else begin
          // Check if characters are valid and match
          reg char_valid_left = char_valid[left_ptr];
          reg char_valid_right = char_valid[right_ptr];
          reg char_match = (char_data[left_ptr] == char_data[right_ptr]);
          reg is_valid_char_left = 0;
          reg is_valid_char_right = 0;

          // Check if left character is in valid set
          for (int i = 0; i <= 10; i++) begin
            if (char_data[left_ptr] == VALID_CHARS[i]) begin
              is_valid_char_left = 1;
            end
          end

          // Check if right character is in valid set
          for (int i = 0; i <= 10; i++) begin
            if (char_data[right_ptr] == VALID_CHARS[i]) begin
              is_valid_char_right = 1;
            end
          end

          if (!char_valid_left || !char_valid_right || !char_match || !is_valid_char_left || !is_valid_char_right) begin
            is_mirror = 0;
            next_state = DONE;
            done = 1;
          end
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 0;
        end
      end
    endcase
  end

endmodule