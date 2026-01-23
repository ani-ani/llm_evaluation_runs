module closest_vowel(
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] word,
  output reg [7:0] result,
  output reg done
);

  // Define states
  typedef enum logic [1:0] {
    IDLE,
    SCAN,
    DONE
  } state_t;

  state_t state;
  reg [2:0] i; // 3-bit counter for 8 positions

  // Vowel check function
  function automatic logic is_vowel(input [7:0] c);
    return (c == "a" || c == "e" || c == "i" || c == "o" || c == "u" ||
            c == "A" || c == "E" || c == "I" || c == "O" || c == "U");
  endfunction

  // Consonant check function (English letter but not vowel)
  function automatic logic is_consonant(input [7:0] c);
    return ((c >= "a" && c <= "z") || (c >= "A" && c <= "Z")) && !is_vowel(c);
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      i <= 7;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SCAN;
            i <= 7;
            result <= 0;
            done <= 0;
          end
        end
        SCAN: begin
          if (i < 1) begin
            state <= DONE;
            result <= 0;
            done <= 1;
          end else begin
            if (is_vowel(word[i]) && is_consonant(word[i-1]) && is_consonant(word[i+1])) begin
              result <= word[i];
              state <= DONE;
              done <= 1;
            end else begin
              i <= i - 1;
            end
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule