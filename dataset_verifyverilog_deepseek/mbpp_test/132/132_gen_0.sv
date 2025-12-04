module tuple_to_string (
  input [3:0] length,
  input [15:0][7:0] chars,
  output logic [127:0] string_out
);

  always_comb begin
    string_out = '0;
    for (int i=0; i<16; i++) begin
      if (i < length) begin
        string_out[127 - i*8 -:8] = chars[i];
      end
    end
  end

endmodule