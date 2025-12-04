module remove_vowels(
  input [127:0] text_in,
  output reg [127:0] text_out
);
  function is_vowel;
    input [7:0] c;
    case (c)
      8'h61, 8'h41, // a A
      8'h65, 8'h45, // e E
      8'h69, 8'h49, // i I
      8'h6F, 8'h4F, // o O
      8'h75, 8'h55: // u U
        is_vowel = 1'b1;
      default:
        is_vowel = 1'b0;
    endcase
  endfunction

  integer j;
  always @(*) begin
    text_out = 128'b0; // left-pack non-vowels, pad with zeros
    for (j = 0; j < 16; j = j + 1) begin
      if (!is_vowel(text_in[j*8+:8])) begin
        // Write to the next available position from the left
        text_out[(16-j-1)*8+:8] = text_in[j*8+:8];
      end
    end
  end
endmodule
