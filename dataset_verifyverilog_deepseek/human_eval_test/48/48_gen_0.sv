module palindrome_checker(input [63:0] text, output is_pal);
  wire [7:0] byte [7:0];
  assign byte[0] = text[63:56];
  assign byte[1] = text[55:48];
  assign byte[2] = text[47:40];
  assign byte[3] = text[39:32];
  assign byte[4] = text[31:24];
  assign byte[5] = text[23:16];
  assign byte[6] = text[15:8];
  assign byte[7] = text[7:0];
  wire pair0_nonzero = (byte[0] != 0) && (byte[7] != 0);
  wire pair0_match = (byte[0] == byte[7]);
  wire pair1_nonzero = (byte[1] != 0) && (byte[6] != 0);
  wire pair1_match = (byte[1] == byte[6]);
  wire pair2_nonzero = (byte[2] != 0) && (byte[5] != 0);
  wire pair2_match = (byte[2] == byte[5]);
  wire pair3_nonzero = (byte[3] != 0) && (byte[4] != 0);
  wire pair3_match = (byte[3] == byte[4]);
  assign is_pal = !((pair0_nonzero && !pair0_match) ||
                  (pair1_nonzero && !pair1_match) ||
                  (pair2_nonzero && !pair2_match) ||
                  (pair3_nonzero && !pair3_match));
endmodule