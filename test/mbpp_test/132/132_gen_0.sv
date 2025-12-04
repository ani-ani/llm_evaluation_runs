module tuple_to_string(
  input  [3:0]          length,
  input  [15:0][7:0]    chars,
  output reg [127:0]    string_out
);

  integer i;

  always @* begin
    string_out = 128'd0;
    for (i = 0; i < 16; i = i + 1) begin
      if (i < length)
        string_out[(127 - i*8) -: 8] = chars[i];
    end
  end

endmodule