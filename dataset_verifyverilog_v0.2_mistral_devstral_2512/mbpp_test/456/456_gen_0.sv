module string_list_reverse (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  input [2:0] str_len,
  output reg [7:0] char_out,
  output reg valid_out,
  output reg done,
  output reg [2:0] out_idx
);

  // Define states
  typedef enum logic [2:0] {
    IDLE,
    READ_STR,
    REVERSE,
    OUTPUT,
    DONE
  } state_t;

  // State registers
  state_t current_state, next_state;

  // Buffer to store strings (4 strings, each up to 8 characters)
  reg [7:0] string_buffer [0:3][0:7];

  // Counters and control signals
  reg [1:0] string_idx = 0;  // Current string index (0-3)
  reg [2:0] char_idx = 0;    // Current character index (0-7)
  reg [2:0] out_char_idx = 0; // Output character index (0-7)
  reg [1:0] str_count = 0;   // Total strings processed (0-3)

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      string_idx <= 0;
      char_idx <= 0;
      out_char_idx <= 0;
      str_count <= 0;
      char_out <= 0;
      valid_out <= 0;
      done <= 0;
      out_idx <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = READ_STR;
      end
      READ_STR: begin
        if (valid_in && char_idx < str_len) begin
          // Continue reading
        end else if (char_idx == str_len) begin
          next_state = REVERSE;
        end
      end
      REVERSE: begin
        next_state = OUTPUT;
      end
      OUTPUT: begin
        if (out_char_idx == str_len) begin
          if (str_count == 3) begin
            next_state = DONE;
          end else begin
            next_state = READ_STR;
          end
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_out <= 0;
      valid_out <= 0;
      done <= 0;
      out_idx <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          char_out <= 0;
          valid_out <= 0;
          done <= 0;
          out_idx <= 0;
        end
        READ_STR: begin
          if (valid_in && char_idx < str_len) begin
            string_buffer[string_idx][char_idx] <= char_in;
            char_idx <= char_idx + 1;
          end
          char_out <= 0;
          valid_out <= 0;
          done <= 0;
        end
        REVERSE: begin
          // No output during reverse
          char_out <= 0;
          valid_out <= 0;
          done <= 0;
          out_char_idx <= 0;
        end
        OUTPUT: begin
          if (out_char_idx < str_len) begin
            char_out <= string_buffer[string_idx][str_len - 1 - out_char_idx];
            valid_out <= 1;
            out_idx <= out_char_idx;
            out_char_idx <= out_char_idx + 1;
          end else begin
            char_out <= 0;
            valid_out <= 0;
            out_idx <= 0;
            // Move to next string
            string_idx <= string_idx + 1;
            str_count <= str_count + 1;
            char_idx <= 0;
          end
        end
        DONE: begin
          char_out <= 0;
          valid_out <= 0;
          done <= 1;
          out_idx <= 0;
        end
        default: begin
          char_out <= 0;
          valid_out <= 0;
          done <= 0;
          out_idx <= 0;
        end
      endcase
    end
  end

endmodule