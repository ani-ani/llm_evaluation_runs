module word_length_filter(
  input clk,
  input rst_n,
  input start,
  input [255:0] str_in,
  input [2:0] K,
  output reg [255:0] str_out,
  output reg done
);
  
  typedef enum {
    IDLE,
    PARSE,
    COMPARE,
    BUILD_OUT,
    DONE
  } state_t;
  
  reg [2:0] current_state, next_state;
  reg [255:0] input_buffer;
  reg [255:0] output_buffer;
  reg [7:0] char;
  reg [2:0] word_len;
  reg [3:0] cycle_count;
  reg [3:0] word_pos;
  reg [3:0] char_pos;
  reg [4:0] output_ptr;
  reg prev_space;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      str_out <= 256'b0;
      done <= 0;
      input_buffer <= 256'b0;
      output_buffer <= 256'b0;
      word_len <= 0;
      word_pos <= 0;
      char_pos <= 0;
      output_ptr <= 0;
      prev_space <= 1;
      cycle_count <= 0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          done <= 0;
          output_ptr <= 0;
          prev_space <= 1;
          if (start) begin
            input_buffer <= str_in;
            char_pos <= 0;
            word_pos <= 0;
            output_buffer <= 256'b0;
            cycle_count <= 0;
          end
        end
        
        PARSE: begin
          cycle_count <= cycle_count + 1;
          char <= input_buffer[char_pos*8 +:8];
          if (char != " " && prev_space) begin
            word_len <= 1;
            prev_space <= 0;
          end else if (char != " ") begin
            word_len <= word_len + 1;
            char_pos <= char_pos + 1;
          end else begin
            prev_space <= 1;
            char_pos <= char_pos + 1;
          end
        end
        
        COMPARE: begin
          cycle_count <= cycle_count + 1;
          if (word_len != K) begin
            output_buffer[output_ptr*8 +:8] <= " ";
            output_ptr <= output_ptr + 1;
            word_pos <= word_pos + 1;
          end
        end
        
        BUILD_OUT: begin
          output_buffer[output_ptr*8 +:8] <= char;
          output_ptr <= output_ptr + 1;
          if (char_pos >= 31 || word_pos >= 8) begin
            next_state <= DONE;
          end else begin
            next_state <= PARSE;
          end
        end
        
        DONE: begin
          str_out <= output_buffer;
          done <= 1;
          next_state <= IDLE;
        end
      endcase
    end
  end
  
  always_comb begin
    case (current_state)
      IDLE: next_state = start ? PARSE : IDLE;
      PARSE: next_state = (char == " " || word_len >= 8) ? COMPARE : PARSE;
      COMPARE: next_state = BUILD_OUT;
      BUILD_OUT: next_state = (char_pos >= 31 || word_pos >= 8) ? DONE : PARSE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
  
endmodule