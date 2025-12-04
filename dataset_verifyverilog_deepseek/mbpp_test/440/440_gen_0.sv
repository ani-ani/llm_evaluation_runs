module adverb_finder (
  input clk,
  input rst_n,
  input start,
  input [511:0] text,
  output reg [5:0] start_pos,
  output reg [5:0] end_pos,
  output reg [127:0] found_word,
  output reg done
);

  // State encoding
  localparam IDLE = 2'd0;
  localparam SCAN = 2'd1;
  localparam DONE = 2'd2;
  
  reg [1:0] state;
  reg [5:0] pos_reg; 
  reg [5:0] word_start_reg;
  reg [3:0] word_ptr;
  reg [7:0] prev_char_reg;
  reg [7:0] last_char_reg;
  reg was_word;
  reg [127:0] word_buffer;
  
  wire [7:0] current_char = text[pos_reg * 8 +: 8];
  
  wire current_is_word = (current_char >= 8'h41 && current_char <= 8'h5A) || 
                         (current_char >= 8'h61 && current_char <= 8'h7A);
  
  wire word_start_detect = current_is_word && !was_word;
  wire word_end_detect = ((!current_is_word && was_word) || 
                         (pos_reg == 6'd63 && current_is_word)) && (word_ptr > 0);
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pos_reg <= 6'b0;
      start_pos <= 6'b0;
      end_pos <= 6'b0;
      found_word <= 128'b0;
      done <= 1'b0;
      word_start_reg <= 6'b0;
      word_ptr <= 4'b0;
      prev_char_reg <= 8'b0;
      last_char_reg <= 8'b0;
      word_buffer <= 128'b0;
      was_word <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= SCAN;
            pos_reg <= 6'b0;
            word_ptr <= 4'b0;
            word_buffer <= 128'b0;
            prev_char_reg <= 8'b0;
            last_char_reg <= 8'b0;
            was_word <= 1'b0;
          end
        end
        
        SCAN: begin
          // Detect word boundaries
          if (word_start_detect) begin
            word_start_reg <= pos_reg;
            word_ptr <= 4'b0;
            prev_char_reg <= 8'b0;
            last_char_reg <= 8'b0;
          end
          
          if (current_is_word) begin
            // Update character tracking
            prev_char_reg <= last_char_reg;
            last_char_reg <= current_char;
            
            // Buffer first 16 characters
            if (word_ptr < 4'd15) begin
              word_buffer[word_ptr*8 +:8] <= current_char;
              word_ptr <= word_ptr + 1;
            end
          end
          
          // Process word endings
          if (word_end_detect) begin
            if (prev_char_reg == 8'h6C && last_char_reg == 8'h79) begin
              // Match found
              start_pos <= word_start_reg;
              end_pos <= (pos_reg == 6'd63 && current_is_word) ? pos_reg : pos_reg - 1'b1;
              found_word <= word_buffer;
              done <= 1'b1;
              state <= DONE;
            end else if (pos_reg == 6'd63) begin
              // End of text
              start_pos <= 6'b0;
              end_pos <= 6'b0;
              found_word <= 128'b0;
              done <= 1'b1;
              state <= DONE;
            end
          end
          
          // Update position and state
          was_word <= current_is_word;
          if (state == SCAN) begin
            pos_reg <= (pos_reg == 6'd63) ? 6'd0 : pos_reg + 6'b1;
          end
        end
        
        DONE: begin
          if (start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule