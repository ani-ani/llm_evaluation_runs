module closest_vowel_finder (
  input clk,
  input rst_n,
  input start,
  input [15:0][7:0] word,
  input [3:0] length,
  output reg [7:0] result,
  output reg done
);

localparam IDLE = 1'b0;
localparam RUN  = 1'b1;

reg state;
reg [3:0] counter;
reg [3:0] s;
reg [7:0] result_reg;
reg found;

function [0:0] is_vowel;
  input [7:0] char;
  begin
    is_vowel = ( (char == 8'd65) || (char == 8'd69) || (char == 8'd73) || (char == 8'd79) || (char == 8'd85) ||
                (char == 8'd97) || (char == 8'd101) || (char == 8'd105) || (char == 8'd111) || (char == 8'd117) );
  end
endfunction

function [0:0] is_letter;
  input [7:0] char;
  begin
    is_letter = ( (char >= 8'd65 && char <= 8'd90) || (char >= 8'd97 && char <= 8'd122) );
  end
endfunction

always @(posedge clk) begin
  if (rst_n == 0) begin
    state <= IDLE;
    counter <= 0;
    result_reg <= 0;
    found <= 0;
    done <= 0;
    result <= 0;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          state <= RUN;
          counter <= 0;
          s <= (length >= 2) ? (length - 2) : 0;
          result_reg <= 0;
          found <= 0;
          done <= 0;
          result <= 0;
        end
      end

      RUN: begin
        if (counter < s) begin
          if (is_vowel(word[s - counter]) && 
              is_letter(word[s - counter - 1]) && !is_vowel(word[s - counter - 1]) &&
              is_letter(word[s - counter + 1]) && !is_vowel(word[s - counter + 1])) 
          begin
            if (!found) begin
              result_reg <= word[s - counter];
              found <= 1;
            end
          end
        end

        if (counter < 4'd15) begin
          counter <= counter + 1;
        end else begin
          state <= IDLE;
          done <= 1;
          result <= result_reg;
        end
      end

      default: state <= IDLE;
    endcase
  end
end

endmodule