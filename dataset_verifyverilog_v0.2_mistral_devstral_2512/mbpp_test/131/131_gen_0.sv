module reverse_vowels (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  output reg [7:0] char_out,
  output reg valid_out,
  output reg done
);

  // States
  typedef enum logic [2:0] {
    IDLE,
    COLLECT_VOWELS,
    OUTPUT_CHARS
  } state_t;

  state_t state, next_state;

  // Counters
  reg [2:0] char_count; // 0-7
  reg [3:0] vowel_count; // 0-8
  reg [2:0] output_count; // 0-7

  // Vowel buffer (max 8 vowels)
  reg [7:0] vowel_buffer [0:7];
  reg [2:0] vowel_ptr; // pointer for vowel buffer

  // Character storage
  reg [7:0] char_storage [0:7];

  // Vowel detection
  function logic is_vowel(input [7:0] c);
    return (c == 8'h61) || (c == 8'h65) || (c == 8'h69) || (c == 8'h6F) || (c == 8'h75) ||
           (c == 8'h41) || (c == 8'h45) || (c == 8'h49) || (c == 8'h4F) || (c == 8'h55);
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_count <= 0;
      vowel_count <= 0;
      output_count <= 0;
      vowel_ptr <= 0;
      char_out <= 0;
      valid_out <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COLLECT_VOWELS;
      end
      COLLECT_VOWELS: begin
        if (char_count == 7) next_state = OUTPUT_CHARS;
      end
      OUTPUT_CHARS: begin
        if (output_count == 7) next_state = IDLE;
      end
    endcase
  end

  // Character collection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_count <= 0;
      vowel_count <= 0;
      vowel_ptr <= 0;
      for (int i = 0; i < 8; i++) begin
        char_storage[i] <= 0;
        vowel_buffer[i] <= 0;
      end
    end else if (state == COLLECT_VOWELS && valid_in) begin
      // Store character
      char_storage[char_count] <= char_in;
      
      // Check if vowel
      if (is_vowel(char_in)) begin
        vowel_buffer[vowel_ptr] <= char_in;
        vowel_ptr <= vowel_ptr + 1;
        vowel_count <= vowel_count + 1;
      end
      
      // Increment character count
      char_count <= char_count + 1;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      output_count <= 0;
      valid_out <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          valid_out <= 0;
          done <= 0;
        end
        COLLECT_VOWELS: begin
          // Output non-vowels immediately
          if (valid_in) begin
            if (!is_vowel(char_in)) begin
              char_out <= char_in;
              valid_out <= 1;
            end else begin
              valid_out <= 0;
            end
          end else begin
            valid_out <= 0;
          end
        end
        OUTPUT_CHARS: begin
          // Output characters with reversed vowels
          if (output_count < 8) begin
            if (is_vowel(char_storage[output_count])) begin
              // Replace with reversed vowel
              char_out <= vowel_buffer[vowel_count - 1];
              vowel_count <= vowel_count - 1;
            end else begin
              // Pass through non-vowel
              char_out <= char_storage[output_count];
            end
            valid_out <= 1;
            output_count <= output_count + 1;
          end else begin
            valid_out <= 0;
          end
          
          // Set done on last cycle
          if (output_count == 7) done <= 1;
          else done <= 0;
        end
      endcase
    end
  end

endmodule