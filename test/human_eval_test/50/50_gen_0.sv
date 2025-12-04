module shift_decoder(
  input  [63:0] encoded_str,
  output [63:0] decoded_str
);

  function automatic [7:0] decode_char(input [7:0] c);
    reg [7:0] base;
    reg [7:0] diff;
    reg [7:0] res;
    begin
      // Treat all characters as lowercase a-z per problem statement
      base = c - 8'd97;          // 0-25 range
      if (base < 8'd5)
        diff = base + 8'd21;     // (base - 5) mod 26
      else
        diff = base - 8'd5;
      res = diff + 8'd97;        // back to ASCII
      decode_char = res;
    end
  endfunction

  assign decoded_str[7:0]    = decode_char(encoded_str[7:0]);
  assign decoded_str[15:8]   = decode_char(encoded_str[15:8]);
  assign decoded_str[23:16]  = decode_char(encoded_str[23:16]);
  assign decoded_str[31:24]  = decode_char(encoded_str[31:24]);
  assign decoded_str[39:32]  = decode_char(encoded_str[39:32]);
  assign decoded_str[47:40]  = decode_char(encoded_str[47:40]);
  assign decoded_str[55:48]  = decode_char(encoded_str[55:48]);
  assign decoded_str[63:56]  = decode_char(encoded_str[63:56]);

endmodule