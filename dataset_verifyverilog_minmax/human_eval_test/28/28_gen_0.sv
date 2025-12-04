module string_concat(
  input  [3:0]       valid_mask,
  input  [3:0][31:0] strings,
  output [127:0]      concatenated
);

  // Each string is packed as: [31:24] char3, [23:16] char2, [15:8] char1, [7:0] char0
  // Concatenate chars (char0..char3 for each string, strings processed LSB->MSB of valid_mask),
  // inserting zero bytes for any string with valid_mask[i]==0.

  logic [15:0][7:0] concat_bytes;

  always_comb begin
    // Initialize with zeros (ensures full 16-byte output is zero-padded)
    concat_bytes = '0;
    // For each of the 4 input strings (LSB to MSB)
    for (int s = 0; s < 4; s++) begin
      if (valid_mask[s]) begin
        // Append char0..char3 of this string
        concat_bytes[s*4 + 0] = strings[s][7:0];    // char0
        concat_bytes[s*4 + 1] = strings[s][15:8];   // char1
        concat_bytes[s*4 + 2] = strings[s][23:16];  // char2
        concat_bytes[s*4 + 3] = strings[s][31:24];  // char3
      end
      // else leave zero padding at positions s*4..s*4+3
    end
  end

  // Map byte array to 128-bit packed output (byte 0 is MSB)
  assign concatenated = {concat_bytes[15], concat_bytes[14], concat_bytes[13], concat_bytes[12],
                         concat_bytes[11], concat_bytes[10], concat_bytes[9],  concat_bytes[8],
                         concat_bytes[7],  concat_bytes[6],  concat_bytes[5],  concat_bytes[4],
                         concat_bytes[3],  concat_bytes[2],  concat_bytes[1],  concat_bytes[0]};

endmodule
