module replace_spaces_underscores (
  input reg [127:0] text_in,
  output reg [127:0] text_out
);
  always_comb begin
    for (int i = 0; i < 16; i++) begin
      case (text_in[i*8 +: 8])
        8'h20: text_out[i*8 +: 8] = 8'h5F;
        8'h5F: text_out[i*8 +: 8] = 8'h20;
        default: text_out[i*8 +: 8] = text_in[i*8 +: 8];
      endcase
    end
  end
endmodule