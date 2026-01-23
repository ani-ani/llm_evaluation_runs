module remove_length (
  input clk,
  input rst_n,
  input start,
  input [3:0] k_len,
  input [127:0] input_str,
  output reg done,
  output reg valid,
  output reg [127:0] output_str
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PARSING,
    CHECKING,
    COPYING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] word_buffer [0:7];
  reg [7:0] output_buffer [0:15];
  reg [3:0] word_length;
  reg [3:0] output_length;
  reg [3:0] input_index;
  reg [3:0] output_index;
  reg [3:0] word_index;
  reg [3:0] space_count;
  reg word_valid;

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      valid <= 0;
      input_index <= 0;
      output_index <= 0;
      word_index <= 0;
      word_length <= 0;
      output_length <= 0;
      space_count <= 0;
      word_valid <= 0;
      
      // Clear buffers
      for (int i = 0; i < 8; i++) word_buffer[i] <= 0;
      for (int i = 0; i < 16; i++) output_buffer[i] <= 0;
    end else begin
      current_state <= next_state;
      
      // State-specific actions
      case (current_state)
        IDLE: begin
          done <= 0;
          valid <= 0;
          if (start) begin
            input_index <= 0;
            output_index <= 0;
            word_index <= 0;
            word_length <= 0;
            output_length <= 0;
            space_count <= 0;
            word_valid <= 0;
            
            // Clear buffers
            for (int i = 0; i < 8; i++) word_buffer[i] <= 0;
            for (int i = 0; i < 16; i++) output_buffer[i] <= 0;
          end
        end
        
        PARSING: begin
          if (input_index < 16) begin
            // Extract current character
            reg [7:0] current_char = input_str[(input_index+1)*8-1 : input_index*8];
            
            if (current_char == 8'h20) begin
              // Space found - end of word
              word_valid <= 1;
              next_state <= CHECKING;
            end else begin
              // Add character to word buffer
              word_buffer[word_index] <= current_char;
              word_index <= word_index + 1;
              word_length <= word_length + 1;
              input_index <= input_index + 1;
            end
          end else begin
            // End of string
            if (word_length > 0) begin
              word_valid <= 1;
              next_state <= CHECKING;
            end else begin
              next_state <= DONE;
            end
          end
        end
        
        CHECKING: begin
          if (word_valid && word_length != k_len) begin
            // Copy word to output
            next_state <= COPYING;
          end else begin
            // Skip word or invalid
            word_valid <= 0;
            word_length <= 0;
            word_index <= 0;
            input_index <= input_index + 1;
            next_state <= PARSING;
          end
        end
        
        COPYING: begin
          if (word_index < word_length) begin
            output_buffer[output_index] <= word_buffer[word_index];
            output_index <= output_index + 1;
            word_index <= word_index + 1;
          end else begin
            // Add space after word (if not last word)
            if (input_index < 16) begin
              output_buffer[output_index] <= 8'h20;
              output_index <= output_index + 1;
            end
            
            // Reset word buffer
            word_valid <= 0;
            word_length <= 0;
            word_index <= 0;
            input_index <= input_index + 1;
            next_state <= PARSING;
          end
        end
        
        DONE: begin
          done <= 1;
          valid <= 1;
          // Pad remaining output with spaces
          for (int i = output_index; i < 16; i++) begin
            output_buffer[i] <= 8'h20;
          end
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    
    case (current_state)
      IDLE: begin
        if (start) next_state = PARSING;
      end
      
      PARSING: begin
        // Next state determined in state machine
      end
      
      CHECKING: begin
        // Next state determined in state machine
      end
      
      COPYING: begin
        // Next state determined in state machine
      end
      
      DONE: begin
        if (!rst_n || start) next_state = IDLE;
      end
    endcase
  end

  // Output string assignment
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      output_str <= 0;
    end else if (valid) begin
      for (int i = 0; i < 16; i++) begin
        output_str[(i+1)*8-1 : i*8] <= output_buffer[i];
      end
    end
  end

endmodule