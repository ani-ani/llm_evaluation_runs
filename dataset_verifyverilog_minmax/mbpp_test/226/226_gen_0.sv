module even_char_filter (
  input [7:0] str_length,
  input [63:0] input_str,
  output [63:0] filtered_str,
  output [7:0] out_length
);

  // out_length = ceil(str_length / 2)
  assign out_length = (str_length + 1) >> 1;

  // Filter even-indexed characters (0,2,4,...) and pack them contiguously
  // from the MSB of filtered_str. Unused bytes are 0.
  integer i, j;
  always @* begin
    filtered_str = 64'h0;
    j = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (str_length > i && (i % 2) == 0) begin
        filtered_str[63:56 - j*8] = input_str[55 - i*8:48 - i*8];
        j = j + 1;
      end
    end
  end

endmodule
