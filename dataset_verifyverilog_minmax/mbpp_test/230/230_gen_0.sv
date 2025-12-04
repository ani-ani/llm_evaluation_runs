module replace_spaces (
  input [255:0] str_in,
  input [7:0] char_in,
  output [255:0] str_out
);
  integer i;
  always @(*) begin
    for (i = 0; i < 32; i = i + 1) begin
      if (str_in[i*8 +: 8] == 8'h20) str_out[i*8 +: 8] = char_in;
      else str_out[i*8 +: 8] = str_in[i*8 +: 8];
    end
  end
endmodule