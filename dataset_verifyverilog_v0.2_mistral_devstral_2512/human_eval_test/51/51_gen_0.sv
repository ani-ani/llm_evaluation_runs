module remove_vowels (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [3:0] length,
  output reg [7:0] char_out,
  output reg out_valid,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    READ_CHAR,
    PROCESS_CHAR,
    WRITE_CHAR,
    DONE
  } state_t;

  state_t state, next_state;
  reg [3:0] char_count;
  reg [3:0] out_count;
  reg [7:0] char_buffer [0:15];

  // Vowel detection function
  function logic is_vowel(input [7:0] c);
    return (c == 8'h61 || c == 8'h41 ||  // a, A
            c == 8'h65 || c == 8'h45 ||  // e, E
            c == 8'h69 || c == 8'h49 ||  // i, I
            c == 8'h6F || c == 8'h4F ||  // o, O
            c == 8'h75 || c == 8'h55);   // u, U
  endfunction

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_count <= 0;
      out_count <= 0;
      char_out <= 0;
      out_valid <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          char_count <= 0;
          out_count <= 0;
          done <= 0;
        end
        
        READ_CHAR: begin
          if (char_count < length) begin
            char_buffer[char_count] <= char_in;
            char_count <= char_count + 1;
          end
        end
        
        PROCESS_CHAR: begin
          if (out_count < char_count) begin
            if (!is_vowel(char_buffer[out_count])) begin
              char_out <= char_buffer[out_count];
              out_valid <= 1;
            end else begin
              out_valid <= 0;
            end
            out_count <= out_count + 1;
          end
        end
        
        WRITE_CHAR: begin
          out_valid <= 0;
        end
        
        DONE: begin
          done <= 1;
        end
        
        default: begin
          state <= IDLE;
          char_count <= 0;
          out_count <= 0;
          char_out <= 0;
          out_valid <= 0;
          done <= 0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = READ_CHAR;
      end
      
      READ_CHAR: begin
        if (char_count == length) next_state = PROCESS_CHAR;
      end
      
      PROCESS_CHAR: begin
        if (out_count == char_count) next_state = DONE;
        else if (out_valid) next_state = WRITE_CHAR;
      end
      
      WRITE_CHAR: begin
        next_state = PROCESS_CHAR;
      end
      
      DONE: begin
        if (!start) next_state = IDLE;
      end
      
      default: next_state = IDLE;
    endcase
  end

endmodule