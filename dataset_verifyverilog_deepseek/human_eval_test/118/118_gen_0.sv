module closest_vowel_finder (
  input clk,
  input rst_n,
  input start,
  input [15:0][7:0] word,
  input [3:0] length,
  output reg [7:0] result,
  output reg done
);

  reg [3:0] cnt;
  reg [3:0] current_index;
  reg found;
  reg [15:0][7:0] word_reg;
  reg [4:0] effective_length_reg;
  reg processing;

  function automatic is_vowel(input [7:0] c);
    return (c == "A" || c == "E" || c == "I" || c == "O" || c == "U" ||
            c == "a" || c == "e" || c == "i" || c == "o" || c == "u");
  endfunction

  function automatic is_consonant(input [7:0] c);
    reg is_letter;
    begin
      is_letter = (c >= 8'd65 && c <= 8'd90) || (c >= 8'd97 && c <= 8'd122);
      return is_letter && !is_vowel(c);
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 4'd0;
      current_index <= 4'd0;
      found <= 1'b0;
      result <= 8'd0;
      done <= 1'b0;
      processing <= 1'b0;
      effective_length_reg <= 5'd0;
      word_reg <= '0;
    end else begin
      if (processing) begin
        if (cnt > 4'd0) cnt <= cnt - 4'd1;

        if (!found && cnt > 4'd0) begin
          if (current_index >= 4'd1 && current_index <= effective_length_reg - 5'd2) begin
            if (is_vowel(word_reg[current_index]) &&
                is_consonant(word_reg[current_index - 1]) &&
                is_consonant(word_reg[current_index + 1])) begin
              result <= word_reg[current_index];
              found <= 1'b1;
            end
          end
          current_index <= current_index - 4'd1;
        end

        if (cnt == 4'd0) begin
          processing <= 1'b0;
          done <= 1'b1;
          if (!found) result <= 8'd0;
        end
      end else begin
        done <= 1'b0;
        if (start) begin
          processing <= 1'b1;
          done <= 1'b0;
          cnt <= 4'd15;
          found <= 1'b0;
          result <= 8'd0;
          word_reg <= word;
          effective_length_reg <= (length == 4'd0) ? 5'd16 : {1'b0, length};
          if ((length >= 4'd3) || (length == 4'd0)) begin
            current_index <= ((length == 4'd0) ? 5'd16 : {1'b0, length}) - 5'd2;
          end else begin
            current_index <= 4'd0;
          end
        end
      end
    end
  end

endmodule