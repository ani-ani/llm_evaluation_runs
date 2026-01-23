module fix_spaces (
  input clk,
  input rst_n,
  input start,
  input [127:0] text_in,
  output reg [127:0] text_out,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state, next_state;
  reg [3:0] char_index; // 0 to 15
  reg [3:0] space_count; // Count of consecutive spaces
  reg [7:0] current_char;
  reg [7:0] prev_char;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_index <= 0;
      space_count <= 0;
      current_char <= 0;
      prev_char <= 0;
      text_out <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      if (state == PROCESSING) begin
        char_index <= char_index + 1;
        prev_char <= current_char;
        current_char <= text_in[(char_index + 1) * 8 - 1 : char_index * 8];
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (char_index == 15) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Processing logic
  always @(*) begin
    case (state)
      IDLE: begin
        text_out = 0;
        done = 0;
      end
      PROCESSING: begin
        // Default: pass through the character
        text_out[(char_index + 1) * 8 - 1 : char_index * 8] = current_char;
        
        // Space handling logic
        if (current_char == 8'h20) begin // Space
          if (prev_char == 8'h20) begin // Previous was space
            space_count = space_count + 1;
            if (space_count == 2) begin // Third consecutive space
              text_out[(char_index + 1) * 8 - 1 : char_index * 8] = 8'h2D; // Hyphen
            end
          end else begin // First space in sequence
            space_count = 1;
            text_out[(char_index + 1) * 8 - 1 : char_index * 8] = 8'h5F; // Underscore
          end
        end else begin // Not a space
          space_count = 0;
          if (prev_char == 8'h20 && char_index > 0) begin
            // Check if previous was part of exactly 2 spaces
            reg [7:0] prev_prev_char = text_in[(char_index - 1) * 8 - 1 : (char_index - 2) * 8];
            if (prev_prev_char == 8'h20) begin
              // This was the second space in a pair
              text_out[char_index * 8 - 1 : (char_index - 1) * 8] = 8'h5F;
            end
          end
        end
        
        done = 0;
      end
      DONE: begin
        done = 1;
      end
    endcase
  end

endmodule