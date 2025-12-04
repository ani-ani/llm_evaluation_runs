module replace_spaces(input [255:0] str_in, input [7:0] char_in, output [255:0] str_out);
  always_comb begin
    for (int i = 0; i < 32; i++) begin
      if (str_in[i*8 +: 8] == 8'h20) begin
        str_out[i*8 +: 8] = char_in;
      end else begin
        str_out[i*8 +: 8] = str_in[i*8 +: 8];
      end
    end
  end
endmodule