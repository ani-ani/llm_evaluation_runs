module vowel_neighbor_count(input [127:0] str_flat, input [3:0] str_len, output [3:0] count);
  wire [7:0] char [0:15];
  generate
    genvar i;
    for (i=0; i<16; i=i+1) begin: str_split
      assign char[i] = str_flat[i*8 +: 8];
    end
  endgenerate

  logic [15:0] is_vowel;
  always_comb begin
    for (int i=0; i<16; i++) begin
      is_vowel[i] = (char[i] == 97) || (char[i] == 101) || (char[i] == 105) || (char[i] == 111) || (char[i] == 117);
    end
  end

  logic [15:0] qualifies;
  always_comb begin
    qualifies = '0;
    for (int i=0; i<16; i++) begin
      if (i < str_len) begin
        logic left_vowel, right_vowel;
        left_vowel = (i > 0) ? is_vowel[i-1] : 1'b0;
        right_vowel = (i < (str_len - 1)) ? is_vowel[i+1] : 1'b0;
        qualifies[i] = !is_vowel[i] && (left_vowel || right_vowel);
      end
    end
  end

  logic [3:0] cnt;
  always_comb begin
    cnt = '0;
    for (int i=0; i<16; i++) begin
      cnt += qualifies[i];
    end
  end
  assign count = cnt;
endmodule