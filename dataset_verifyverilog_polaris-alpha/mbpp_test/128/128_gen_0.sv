module word_length_filter(
  input  [3:0]     n,
  input  [1023:0]  word_string,
  output reg [7:0] word_mask
);

  integer i, w;
  reg [3:0] len [7:0];
  reg [3:0] final_len [7:0];
  reg [3:0] ch_non_space;
  reg [7:0] ch;

  always @* begin
    // Initialize lengths
    for (w = 0; w < 8; w = w + 1) begin
      len[w] = 4'd0;
      final_len[w] = 4'd0;
    end

    // For each word, track runs of non-space chars separated by spaces.
    // Only the last such run before trailing spaces is taken as the word length.
    // This effectively ignores trailing spaces used for padding.
    for (w = 0; w < 8; w = w + 1) begin
      ch_non_space = 4'd0;
      final_len[w] = 4'd0;

      // Characters within a word: index 0 = first char, index 15 = last char
      // Map: ch = word_string[base + (15 - j)*8 +: 8]
      for (i = 0; i < 16; i = i + 1) begin
        ch = word_string[(w*128) + (15 - i)*8 +: 8];

        if (ch != 8'h20) begin
          // Non-space: grow current run
          if (ch_non_space < 4'd15)
            ch_non_space = ch_non_space + 4'd1;
        end else begin
          // Space: terminate current run, update final_len, reset run
          if (ch_non_space != 4'd0)
            final_len[w] = ch_non_space;
          ch_non_space = 4'd0;
        end
      end

      // End of word: if it ended on non-space run, that is the final length
      if (ch_non_space != 4'd0)
        final_len[w] = ch_non_space;
    end

    // Generate mask: 1 if final_len > n
    for (w = 0; w < 8; w = w + 1) begin
      word_mask[w] = (final_len[w] > n) ? 1'b1 : 1'b0;
    end
  end

endmodule