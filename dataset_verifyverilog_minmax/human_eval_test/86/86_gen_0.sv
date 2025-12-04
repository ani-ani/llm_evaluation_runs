module string_sorter (
  input clk,
  input rst_n,
  input start,
  input [63:0][7:0] char_in,
  output reg [63:0][7:0] char_out,
  output reg done
);

  // Internal output buffer
  reg [63:0][7:0] char_out_reg;
  
  // Input tracking
  reg [5:0] input_idx;    // Current position in input (0-63)
  reg [5:0] s_idx;        // Start index of current word
  reg [2:0] word_len;     // Length of current word (0-8)
  reg in_word;            // Flag: 1 if currently processing a word
  
  // Word buffer for sorting
  reg [7:0] word_reg [0:7];  // 8-character buffer
  
  // Sorting state
  reg [3:0] sort_pass;    // Bubble sort pass counter (0-7)
  reg [3:0] sort_comp;    // Comparison counter within pass (0-6)
  
  // Writing state
  reg [3:0] write_counter; // Counter for writing sorted word (0-7)
  
  // State machine
  reg [2:0] state;
  parameter IDLE = 3'b000, READ = 3'b001, SORT = 3'b010, WRITE = 3'b011, DONE = 3'b100;
  
  // Temporary for swap operation
  reg [7:0] temp_swap;
  
  // Main state machine
  always_ff @(posedge clk) begin
    if (rst_n == 0) begin
      // Reset all registers
      state <= IDLE;
      done <= 0;
      char_out_reg <= 64'h0;
      input_idx <= 0;
      s_idx <= 0;
      word_len <= 0;
      in_word <= 0;
      sort_pass <= 0;
      sort_comp <= 0;
      write_counter <= 0;
      // Initialize word buffer
      for (int i = 0; i < 8; i++) begin
        word_reg[i] <= 8'h0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            char_out_reg <= char_in;  // Copy input to output buffer
            input_idx <= 0;
            s_idx <= 0;
            word_len <= 0;
            in_word <= 0;
            state <= READ;
          end
        end
        
        READ: begin
          if (input_idx >= 64) begin
            state <= DONE;
          end else if (in_word == 0) begin
            if (char_in[input_idx] == 8'h20) begin
              // Skip space character
              input_idx <= input_idx + 1;
            end else begin
              // Start new word
              in_word <= 1;
              s_idx <= input_idx;
              word_reg[0] <= char_in[input_idx];
              word_len <= 1;
              input_idx <= input_idx + 1;
            end
          end else begin
            if (word_len < 8) begin
              if (input_idx < 64 && char_in[input_idx] != 8'h20) begin
                // Continue reading word
                word_reg[word_len] <= char_in[input_idx];
                word_len <= word_len + 1;
                input_idx <= input_idx + 1;
              end else begin
                // End of word
                in_word <= 0;
                state <= SORT;
              end
            end else begin
              // Word buffer full
              in_word <= 0;
              state <= SORT;
            end
          end
        end
        
        SORT: begin
          if (sort_pass < 8) begin
            if (sort_comp < 7) begin
              if (word_reg[sort_comp] > word_reg[sort_comp + 1]) begin
                // Swap characters
                temp_swap = word_reg[sort_comp];
                word_reg[sort_comp] <= word_reg[sort_comp + 1];
                word_reg[sort_comp + 1] <= temp_swap;
              end
              sort_comp <= sort_comp + 1;
            end else begin
              // Move to next pass
              sort_pass <= sort_pass + 1;
              sort_comp <= 0;
            end
          end else begin
            // Sort complete
            state <= WRITE;
          end
        end
        
        WRITE: begin
          if (write_counter < word_len) begin
            // Write sorted character to output
            char_out_reg[s_idx + write_counter] <= word_reg[write_counter];
            write_counter <= write_counter + 1;
          end else begin
            // Word written, prepare for next word
            write_counter <= 0;
            state <= READ;
          end
        end
        
        DONE: begin
          done <= 1;
          // Stay in DONE state until reset
        end
      endcase
    end
  end
  
  // Output assignment
  always_ff @(posedge clk) begin
    if (rst_n == 0) begin
      char_out <= 64'h0;
    end else begin
      char_out <= char_out_reg;
    end
  end
  
endmodule