module distinct_char_counter (
  input clk,
  input rst_n,
  input start,
  input [3:0] str_len,
  input [127:0] char_array,
  output reg [4:0] distinct_count,
  output reg done
);

  // State machine parameters
  parameter IDLE = 2'b00;
  parameter PROCESSING = 2'b01;
  parameter DONE = 2'b10;

  // Internal signals
  reg [1:0] state;
  reg [3:0] count;
  logic [255:0] seen; // Track seen characters (1 bit per ASCII code)

  // State machine and processing
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all states
      state <= IDLE;
      distinct_count <= 5'd0;
      done <= 1'b0;
      count <= 4'd0;
      seen <= 256'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            count <= 4'd0;
            seen <= 256'b0; // Clear seen characters
            distinct_count <= 5'd0; // Reset distinct count
          end
          done <= 1'b0; // Ensure done is low in IDLE
        end
        
        PROCESSING: begin
          if (count < str_len) begin
            // Extract current character and convert to uppercase
            logic [7:0] current_char = char_array[count*8 +: 8] & 8'hDF;
            
            // Check if character is new and update if so
            logic [255:0] seen_next = seen;
            if (!seen[current_char]) begin
              seen_next[current_char] = 1'b1;
              distinct_count <= distinct_count + 1;
            end
            seen <= seen_next;
            count <= count + 1;
          end
          
          // Transition to DONE when processing is complete
          if (count == str_len) begin
            state <= DONE;
          end
        end
        
        DONE: begin
          // Start new processing if requested
          if (start) begin
            state <= PROCESSING;
            count <= 4'd0;
            seen <= 256'b0;
            distinct_count <= 5'd0;
          end else begin
            state <= DONE; // Remain in DONE state
          end
          done <= 1'b1; // Assert done signal
        end
      endcase
    end
  end

endmodule