module replace_spaces(
  input clk,
  input rst_n,
  input start,
  input [7:0] char_array [0:15],  // 16-character input buffer
  input [4:0] len,                 // String length (0-16)
  output reg [7:0] result_array [0:15],  // Output buffer
  output reg done,
  output reg valid
);

  // Parameters
  localparam [3:0] MAX_LEN = 4'd16;
  localparam [7:0] SPACE_ASCII = 8'd32;    // ' '
  localparam [7:0] UNDERSCORE_ASCII = 8'd95; // '_'
  
  // State machine states
  localparam [1:0] IDLE = 2'd0;
  localparam [1:0] PROCESS = 2'd1;
  localparam [1:0] FINISHED = 2'd2;
  
  // Registers
  reg [1:0] state;
  reg [4:0] index;  // Current character index
  reg [4:0] length; // Stored length
  
  integer i;
  
  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      valid <= 1'b0;
      index <= 5'd0;
      length <= 5'd0;
      // Clear output array
      for (i = 0; i < MAX_LEN; i = i + 1) begin
        result_array[i] <= 8'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          valid <= 1'b0;
          index <= 5'd0;
          if (start && len > 5'd0 && len <= MAX_LEN) begin
            length <= len;
            state <= PROCESS;
            // Initialize output with input
            for (i = 0; i < MAX_LEN; i = i + 1) begin
              if (i < len)
                result_array[i] <= char_array[i];
              else
                result_array[i] <= 8'd0;
            end
          end
        end
        
        PROCESS: begin
          if (index < length) begin
            // Process current character
            if (result_array[index] == SPACE_ASCII)
              result_array[index] <= UNDERSCORE_ASCII;
            else if (result_array[index] == UNDERSCORE_ASCII)
              result_array[index] <= SPACE_ASCII;
            // else keep as is
            
            index <= index + 5'd1;
          end else begin
            // All characters processed
            state <= FINISHED;
            done <= 1'b1;
            valid <= 1'b1;
          end
        end
        
        FINISHED: begin
          done <= 1'b0;
          // Wait for next start or reset
          if (!start) begin
            state <= IDLE;
          end
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule