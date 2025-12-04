module all_chars_same(input wire [63:0] s, input wire [2:0] len, output wire all_same);
  wire [7:0] first_char = s[63:56];
  wire [3:0] len_ext = (len == 3'd0) ? 4'd8 : {1'b0, len};
  wire ok1 = (len_ext <= 4'd1) || (s[55:48] == first_char);
  wire ok2 = (len_ext <= 4'd2) || (s[47:40] == first_char);
  wire ok3 = (len_ext <= 4'd3) || (s[39:32] == first_char);
  wire ok4 = (len_ext <= 4'd4) || (s[31:24] == first_char);
  wire ok5 = (len_ext <= 4'd5) || (s[23:16] == first_char);
  wire ok6 = (len_ext <= 4'd6) || (s[15:8] == first_char);
  wire ok7 = (len_ext <= 4'd7) || (s[7:0] == first_char);
  assign all_same = ok1 & ok2 & ok3 & ok4 & ok5 & ok6 & ok7;
endmodule