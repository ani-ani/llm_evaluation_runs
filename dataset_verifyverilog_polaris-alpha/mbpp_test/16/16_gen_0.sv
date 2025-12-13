module text_lowercase_underscore(
  input  [127:0] text,
  output reg     valid
);

  integer i;
  integer underscore_count;
  integer underscore_pos;
  reg [7:0] ch;
  reg is_lower;
  reg is_underscore;

  always @* begin
    valid = 1'b1;
    underscore_count = 0;
    underscore_pos = -1;

    // Check all characters: must be lowercase or underscore; count underscores
    for (i = 0; i < 16; i = i + 1) begin
      ch = text[127 - (i*8) -: 8];
      is_lower = (ch >= 8'h61) && (ch <= 8'h7A);
      is_underscore = (ch == 8'h5F);

      if (!(is_lower || is_underscore)) begin
        valid = 1'b0;
      end
      if (is_underscore) begin
        underscore_count = underscore_count + 1;
        underscore_pos = i;
      end
    end

    // Exactly one underscore required
    if (underscore_count != 1)
      valid = 1'b0;

    // Underscore cannot be first (i == 0 is last char), cannot be last (i == 15 is first char)
    // Positions are counted from LSB side: i=0 => last char, i=15 => first char
    if ((underscore_pos == 0) || (underscore_pos == 15))
      valid = 1'b0;

    // If still potentially valid, ensure all chars before and after underscore are lowercase only
    if (valid) begin
      // Characters after underscore (indices 0 .. underscore_pos-1)
      for (i = 0; i < underscore_pos; i = i + 1) begin
        ch = text[127 - (i*8) -: 8];
        if (!((ch >= 8'h61) && (ch <= 8'h7A))) begin
          valid = 1'b0;
        end
      end
      // Characters before underscore (indices underscore_pos+1 .. 15)
      for (i = underscore_pos + 1; i < 16; i = i + 1) begin
        ch = text[127 - (i*8) -: 8];
        if (!((ch >= 8'h61) && (ch <= 8'h7A))) begin
          valid = 1'b0;
        end
      end
    end
  end

endmodule