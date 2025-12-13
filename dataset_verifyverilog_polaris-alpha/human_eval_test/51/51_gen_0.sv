module remove_vowels(
  input  [127:0] text_in,
  output [127:0] text_out
);

  // Extract 16 input bytes
  wire [7:0] in_b [0:15];
  genvar gi;
  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : EXTRACT_IN
      assign in_b[gi] = text_in[8*(16-gi)-1 -: 8];
    end
  endgenerate

  // Function to detect vowels (both upper and lower case)
  function automatic is_vowel(input [7:0] c);
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
          is_vowel = 1'b1;
        default:
          is_vowel = 1'b0;
      endcase
    end
  endfunction

  // Left-pack non-vowel characters combinationally
  reg [7:0] packed [0:15];
  integer i;
  integer wptr;

  always @* begin
    // Initialize all output bytes to zero
    for (i = 0; i < 16; i = i + 1) begin
      packed[i] = 8'h00;
    end

    wptr = 0;

    // Scan through input bytes; copy only non-vowels, preserving order
    for (i = 0; i < 16; i = i + 1) begin
      if (!is_vowel(in_b[i])) begin
        if (wptr < 16) begin
          packed[wptr] = in_b[i];
          wptr = wptr + 1;
        end
      end
    end
  end

  // Pack output bytes back into 128-bit bus
  genvar go;
  generate
    for (go = 0; go < 16; go = go + 1) begin : PACK_OUT
      assign text_out[8*(16-go)-1 -: 8] = packed[go];
    end
  endgenerate

endmodule