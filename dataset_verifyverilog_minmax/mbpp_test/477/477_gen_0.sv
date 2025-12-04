module string_to_lower(
  input [63:0] string_in,
  output [63:0] string_out
);

  always_comb begin
    for (int i = 0; i < 8; i++) begin
      byte character = string_in[i*8 +: 8];
      if (character >= 8'd65 && character <= 8'd90)
        string_out[i*8 +: 8] = character + 8'd32;
      else
        string_out[i*8 +: 8] = character;
    end
  end

endmodule