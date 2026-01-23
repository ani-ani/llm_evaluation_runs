module count_substrings (
  input clk,
  input rst_n,
  input start,
  input [127:0] s,
  input [4:0] len,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    READ_LEN,
    PROCESSING,
    WAIT,
    DONE
  } state_t;

  state_t state;
  reg [3:0] char_index;
  reg [7:0] prefix_sum;
  reg [7:0] val;
  reg [7:0] current_val;
  reg [7:0] lookup_table [0:32]; // 33 entries for -16 to +16

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_index <= 0;
      prefix_sum <= 0;
      result <= 0;
      done <= 0;
      for (int i = 0; i < 33; i++) begin
        lookup_table[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= READ_LEN;
            char_index <= 0;
            prefix_sum <= 0;
            result <= 0;
            done <= 0;
          end
        end
        READ_LEN: begin
          if (len > 0) begin
            state <= PROCESSING;
          end else begin
            state <= DONE;
            done <= 1;
          end
        end
        PROCESSING: begin
          if (char_index < len) begin
            // Calculate current digit
            reg [7:0] current_char = s[(char_index << 3) +: 8];
            reg [3:0] digit = current_char - 8'd48; // ASCII '0' is 48
            
            // Update prefix_sum
            prefix_sum <= prefix_sum + digit;
            
            // Calculate val = prefix_sum - index
            val <= prefix_sum - char_index;
            
            // Move to WAIT state to handle lookup table update
            state <= WAIT;
          end else begin
            state <= DONE;
            done <= 1;
          end
        end
        WAIT: begin
          // Lookup current val in table
          current_val <= val + 16; // Adjust for negative indices
          
          // Add count to result
          result <= result + lookup_table[current_val];
          
          // Increment count in table
          lookup_table[current_val] <= lookup_table[current_val] + 1;
          
          // Move to next character
          char_index <= char_index + 1;
          state <= PROCESSING;
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule