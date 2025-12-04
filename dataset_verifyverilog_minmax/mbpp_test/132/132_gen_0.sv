module tuple_to_string(
  input [3:0] length,
  input [15:0][7:0] chars,
  output logic [127:0] string_out
);
  integer i;
  always_comb begin
    for (i = 0; i < 16; i = i + 1) begin
      if (i < length) string_out[i*8 +: 8] = chars[i];
      else string_out[i*8 +: 8] = 8'h00;
    end
  end
endmodule