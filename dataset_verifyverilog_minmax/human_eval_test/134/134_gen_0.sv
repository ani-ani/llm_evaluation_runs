module last_char_checker (
  input clk,
  input rst_n,
  input start,
  input [15:0][7:0] txt,
  output reg result,
  output reg done
);

  parameter READY = 2'b00;
  parameter PROCESSING = 2'b01;
  parameter OUTPUT = 2'b10;

  reg [1:0] state;
  reg [4:0] counter;  // 0 to 15 for processing, 16 for finished
  reg [4:0] last_non_space_index;  // 0-15 valid index, 16 = none

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= READY;
      result <= 0;
      done <= 1;
      counter <= 0;
      last_non_space_index <= 16;  // use 16 as invalid
    end
    else begin
      case (state)
        READY: begin
          if (start) begin
            state <= PROCESSING;
            counter <= 0;
            last_non_space_index <= 16;  // reset
            done <= 0;  // start processing
          end
          else begin
            state <= READY;
            done <= 1;
            // result retains previous value
          end
        end

        PROCESSING: begin
          // Check current character
          if (txt[counter] != 8'h20) begin  // not space
            last_non_space_index <= counter;
          end

          // Count characters
          counter <= counter + 1;

          if (counter == 15) begin  // processed all 16 chars
            state <= OUTPUT;
          end
          else begin
            state <= PROCESSING;
          end
        end

        OUTPUT: begin
          // Set result based on last non-space character
          if (last_non_space_index == 16) begin
            result <= 0;  // no non-space character found
          end
          else begin
            reg [7:0] char;
            char = txt[last_non_space_index];
            
            // Check if it's a letter (A-Z or a-z)
            if ((char >= 8'h41 && char <= 8'h5A) || (char >= 8'h61 && char <= 8'h7A)) begin
              // Check if previous character was space
              if (last_non_space_index == 0) begin
                result <= 1;  // first character is standalone
              end
              else begin
                if (txt[last_non_space_index-1] == 8'h20) begin
                  result <= 1;  // preceded by space
                end
                else begin
                  result <= 0;  // not preceded by space
                end
              end
            end
            else begin
              result <= 0;  // not a letter
            end
          end
          
          done <= 1;  // processing complete
          
          // Ready for next start
          if (start) begin
            state <= PROCESSING;
            counter <= 0;
            last_non_space_index <= 16;
            done <= 0;  // immediately start next processing
          end
          else begin
            state <= READY;
          end
        end

        default: state <= READY;
      endcase
    end
  end
endmodule