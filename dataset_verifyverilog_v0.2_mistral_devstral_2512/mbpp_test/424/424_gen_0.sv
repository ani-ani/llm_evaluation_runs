module extract_rear (
  input [7:0] str1,
  input [7:0] str2,
  input [7:0] str3,
  input [2:0] len1,
  input [2:0] len2,
  input [2:0] len3,
  output [7:0] rear1,
  output [7:0] rear2,
  output [7:0] rear3
);

  // Extract last character from str1
  assign rear1 = (len1 == 1) ? str1[7:0] :
                 (len1 == 2) ? str1[15:8] :
                 (len1 == 3) ? str1[23:16] :
                 (len1 == 4) ? str1[31:24] :
                 (len1 == 5) ? str1[39:32] :
                 (len1 == 6) ? str1[47:40] :
                 (len1 == 7) ? str1[55:48] :
                 str1[63:56];

  // Extract last character from str2
  assign rear2 = (len2 == 1) ? str2[7:0] :
                 (len2 == 2) ? str2[15:8] :
                 (len2 == 3) ? str2[23:16] :
                 (len2 == 4) ? str2[31:24] :
                 (len2 == 5) ? str2[39:32] :
                 (len2 == 6) ? str2[47:40] :
                 (len2 == 7) ? str2[55:48] :
                 str2[63:56];

  // Extract last character from str3
  assign rear3 = (len3 == 1) ? str3[7:0] :
                 (len3 == 2) ? str3[15:8] :
                 (len3 == 3) ? str3[23:16] :
                 (len3 == 4) ? str3[31:24] :
                 (len3 == 5) ? str3[39:32] :
                 (len3 == 6) ? str3[47:40] :
                 (len3 == 7) ? str3[55:48] :
                 str3[63:56];

endmodule