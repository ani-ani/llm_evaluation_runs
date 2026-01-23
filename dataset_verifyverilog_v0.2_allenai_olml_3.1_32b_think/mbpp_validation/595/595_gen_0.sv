module min_swaps (
    input [15:0] str1,
    input [15:0] str2,
    input [3:0] length,
    output reg [3:0] swaps,
    output reg possible
);

wire enable_0, enable_1, enable_2, enable_3,
      enable_4, enable_5, enable_6, enable_7,
      enable_8, enable_9, enable_10, enable_11,
      enable_12, enable_13, enable_14, enable_15;

assign enable_0 = 1'b1;
assign enable_1 = length > 1;
assign enable_2 = length > 2;
assign enable_3 = length > 3;
assign enable_4 = length > 4;
assign enable_5 = length > 5;
assign enable_6 = length > 6;
assign enable_7 = length > 7;
assign enable_8 = length > 8;
assign enable_9 = length > 9;
assign enable_10 = length > 10;
assign enable_11 = length > 11;
assign enable_12 = length > 12;
assign enable_13 = length > 13;
assign enable_14 = length > 14;
assign enable_15 = length > 15;

wire bit0, bit1, bit2, bit3, bit4, bit5, bit6, bit7,
     bit8, bit9, bit10, bit11, bit12, bit13, bit14, bit15;

assign bit0 = (str1[0] ^ str2[0]) & enable_0;
assign bit1 = (str1[1] ^ str2[1]) & enable_1;
assign bit2 = (str1[2] ^ str2[2]) & enable_2;
assign bit3 = (str1[3] ^ str2[3]) & enable_3;
assign bit4 = (str1[4] ^ str2[4]) & enable_4;
assign bit5 = (str1[5] ^ str2[5]) & enable_5;
assign bit6 = (str1[6] ^ str2[6]) & enable_6;
assign bit7 = (str1[7] ^ str2[7]) & enable_7;
assign bit8 = (str1[8] ^ str2[8]) & enable_8;
assign bit9 = (str1[9] ^ str2[9]) & enable_9;
assign bit10 = (str1[10] ^ str2[10]) & enable_10;
assign bit11 = (str1[11] ^ str2[11]) & enable_11;
assign bit12 = (str1[12] ^ str2[12]) & enable_12;
assign bit13 = (str1[13] ^ str2[13]) & enable_13;
assign bit14 = (str1[14] ^ str2[14]) & enable_14;
assign bit15 = (str1[15] ^ str2[15]) & enable_15;

assign mismatch_count = bit0 + bit1 + bit2 + bit3 + bit4 + bit5 + bit6 + bit7 + bit8 + bit9 + bit10 + bit11 + bit12 + bit13 + bit14 + bit15;

assign possible = (mismatch_count % 2 == 0);
assign swaps = (possible) ? (mismatch_count >> 1)[3:0] : 4'b0;
endmodule