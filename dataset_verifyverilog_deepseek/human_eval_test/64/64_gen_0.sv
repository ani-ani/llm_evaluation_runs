module vowel_counter(input reg [63:0] chars, input reg [3:0] len, output reg [3:0] count);
  wire [7:0] vowel_bits;
  genvar i;
  generate for (i = 0; i < 8; i = i + 1) begin : gen_block
    wire [7:0] char = chars[i*8 +: 8];
    wire is_vowel = (char == 8'h61) || (char == 8'h41) || (char == 8'h65) || (char == 8'h45) || 
                    (char == 8'h69) || (char == 8'h49) || (char == 8'h6F) || (char == 8'h4F) || 
                    (char == 8'h75) || (char == 8'h55);
    wire is_y = (char == 8'h79) || (char == 8'h59);
    wire is_active = (i < len);
    wire is_last_char = (i == (len - 4'd1));
    assign vowel_bits[i] = is_active && (is_vowel || (is_y && is_last_char));
  end endgenerate
  assign count = vowel_bits[0] + vowel_bits[1] + vowel_bits[2] + vowel_bits[3] + 
                 vowel_bits[4] + vowel_bits[5] + vowel_bits[6] + vowel_bits[7];
endmodule