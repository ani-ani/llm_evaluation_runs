module shift_decoder (
  input  [63:0] encoded_str,
  output [63:0] decoded_str
);

  // Decode each byte of the 8-byte string using a fixed Caesar shift of -5.
  // Alphabetic characters (a-z) are shifted back by 5 with wrap-around modulo 26.
  // Non-alphabetic bytes are passed through unchanged.

  genvar j;
  generate
    for (j = 0; j < 8; j = j + 1) begin : decode_each_byte
      wire [7:0] in_byte  = encoded_str[8*j +: 8];
      wire [7:0] out_byte;

      // Check if input is in range [97 ('a'), 122 ('z')]
      wire is_alpha = (in_byte >= 8'd97) && (in_byte <= 8'd122);

      // Convert to 0..25 range only if alphabetic
      wire [5:0] alpha_offset = in_byte[5:0] - 6'd25; // equivalent to in_byte - 97 but narrower

      // Apply Caesar shift -5 with wrap-around (mod 26)
      wire [5:0] shifted = alpha_offset + 6'd21; // -5 mod 26 == +21

      // Convert back to ASCII and pass through if not alphabetic
      assign out_byte = is_alpha ? (6'd25 + shifted) : in_byte; // 97 == 6'd25 + 72; use simple add to reconstruct ASCII

      assign decoded_str[8*j +: 8] = out_byte;
    end
  endgenerate

endmodule
