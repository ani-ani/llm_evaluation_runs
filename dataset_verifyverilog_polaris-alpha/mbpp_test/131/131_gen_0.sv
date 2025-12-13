module reverse_vowels(
  input  [7:0]      string_length,
  input  [7:0][7:0] chars_in,
  output [7:0][7:0] chars_out
);

  // Internal wires for vowel detection
  wire [7:0] is_vowel;

  // Function to determine if a character is a vowel (a,e,i,o,u,A,E,I,O,U)
  function automatic is_vowel_func(input [7:0] c);
    begin
      case (c)
        8'h41, // 'A'
        8'h45, // 'E'
        8'h49, // 'I'
        8'h4F, // 'O'
        8'h55, // 'U'
        8'h61, // 'a'
        8'h65, // 'e'
        8'h69, // 'i'
        8'h6F, // 'o'
        8'h75: // 'u'
          is_vowel_func = 1'b1;
        default:
          is_vowel_func = 1'b0;
      endcase
    end
  endfunction

  // Precompute which positions (0..7) are vowels and within string_length
  genvar gi;
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : GEN_VOWEL_FLAGS
      assign is_vowel[gi] = (gi < string_length) ? is_vowel_func(chars_in[gi]) : 1'b0;
    end
  endgenerate

  // Combinational block to reverse vowels
  integer i, j;
  reg [2:0] last_vowel_idx; // index of next vowel-from-end (0..7)

  always @* begin
    // Initialize output to input by default
    for (i = 0; i < 8; i = i + 1) begin
      chars_out[i] = chars_in[i];
    end

    // Start from the last valid character position
    if (string_length == 0) begin
      last_vowel_idx = 3'd7; // unused when length=0, but defined
    end else begin
      if (string_length > 8) begin
        last_vowel_idx = 3'd7;
      end else begin
        last_vowel_idx = string_length[2:0] - 1'b1;
      end
    end

    // For each position from 0..string_length-1, if vowel, replace with next vowel from end
    for (i = 0; i < 8; i = i + 1) begin
      if (i < string_length && is_vowel[i]) begin
        // Find next vowel from end at or before last_vowel_idx
        for (j = last_vowel_idx; j >= 0; j = j - 1) begin
          if (j < string_length && is_vowel[j]) begin
            chars_out[i] = chars_in[j];
            if (j == 0)
              last_vowel_idx = 3'd7; // no more valid, but loop won't find new ones
            else
              last_vowel_idx = j[2:0] - 1'b1;
            break;
          end
          if (j == 0) begin
            // No more vowels found; keep original (though spec guarantees symmetry)
            break;
          end
        end
      end
    end
  end

endmodule