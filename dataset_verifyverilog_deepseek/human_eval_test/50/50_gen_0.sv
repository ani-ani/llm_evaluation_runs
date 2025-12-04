module shift_decoder(input reg [63:0] encoded_str, output reg [63:0] decoded_str);
  always_comb begin
    decoded_str = 64'b0;
    for (int i=0; i<8; i++) begin
      automatic logic [7:0] enc_byte = (encoded_str >> (56 - 8*i)) & 8'hFF;
      automatic logic [7:0] temp = enc_byte - 8'd97;
      automatic logic [7:0] added = temp + 8'd21;
      automatic logic [7:0] mod_val = added % 8'd26;
      automatic logic [7:0] dec_byte = mod_val + 8'd97;
      decoded_str = decoded_str | (64'(dec_byte) << (56 - 8*i));
    end
  end
endmodule