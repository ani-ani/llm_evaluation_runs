module string_length_filter (
  input [7:0] str_length,
  input [127:0] str0, str1, str2, str3, str4, str5, str6, str7,
  output reg [7:0] valid_mask,
  output reg [127:0] filtered0, filtered1, filtered2, filtered3, filtered4, filtered5, filtered6, filtered7
);
  
  // Calculate lengths for str0
  wire [15:0] len_bit0;
  assign len_bit0[0] = (str0[7:0] != 8'd0);
  assign len_bit0[1] = len_bit0[0] && (str0[15:8] != 8'd0);
  assign len_bit0[2] = len_bit0[1] && (str0[23:16] != 8'd0);
  assign len_bit0[3] = len_bit0[2] && (str0[31:24] != 8'd0);
  assign len_bit0[4] = len_bit0[3] && (str0[39:32] != 8'd0);
  assign len_bit0[5] = len_bit0[4] && (str0[47:40] != 8'd0);
  assign len_bit0[6] = len_bit0[5] && (str0[55:48] != 8'd0);
  assign len_bit0[7] = len_bit0[6] && (str0[63:56] != 8'd0);
  assign len_bit0[8] = len_bit0[7] && (str0[71:64] != 8'd0);
  assign len_bit0[9] = len_bit0[8] && (str0[79:72] != 8'd0);
  assign len_bit0[10] = len_bit0[9] && (str0[87:80] != 8'd0);
  assign len_bit0[11] = len_bit0[10] && (str0[95:88] != 8'd0);
  assign len_bit0[12] = len_bit0[11] && (str0[103:96] != 8'd0);
  assign len_bit0[13] = len_bit0[12] && (str0[111:104] != 8'd0);
  assign len_bit0[14] = len_bit0[13] && (str0[119:112] != 8'd0);
  assign len_bit0[15] = len_bit0[14] && (str0[127:120] != 8'd0);
  
  wire [4:0] len0;
  assign len0 = (!len_bit0[0]) ? 5'd0 :
                (!len_bit0[1]) ? 5'd1 :
                (!len_bit0[2]) ? 5'd2 :
                (!len_bit0[3]) ? 5'd3 :
                (!len_bit0[4]) ? 5'd4 :
                (!len_bit0[5]) ? 5'd5 :
                (!len_bit0[6]) ? 5'd6 :
                (!len_bit0[7]) ? 5'd7 :
                (!len_bit0[8]) ? 5'd8 :
                (!len_bit0[9]) ? 5'd9 :
                (!len_bit0[10]) ? 5'd10 :
                (!len_bit0[11]) ? 5'd11 :
                (!len_bit0[12]) ? 5'd12 :
                (!len_bit0[13]) ? 5'd13 :
                (!len_bit0[14]) ? 5'd14 :
                (!len_bit0[15]) ? 5'd15 : 5'd16;
  
  // Calculate lengths for str1
  wire [15:0] len_bit1;
  assign len_bit1[0] = (str1[7:0] != 8'd0);
  assign len_bit1[1] = len_bit1[0] && (str1[15:8] != 8'd0);
  assign len_bit1[2] = len_bit1[1] && (str1[23:16] != 8'd0);
  assign len_bit1[3] = len_bit1[2] && (str1[31:24] != 8'd0);
  assign len_bit1[4] = len_bit1[3] && (str1[39:32] != 8'd0);
  assign len_bit1[5] = len_bit1[4] && (str1[47:40] != 8'd0);
  assign len_bit1[6] = len_bit1[5] && (str1[55:48] != 8'd0);
  assign len_bit1[7] = len_bit1[6] && (str1[63:56] != 8'd0);
  assign len_bit1[8] = len_bit1[7] && (str1[71:64] != 8'd0);
  assign len_bit1[9] = len_bit1[8] && (str1[79:72] != 8'd0);
  assign len_bit1[10] = len_bit1[9] && (str1[87:80] != 8'd0);
  assign len_bit1[11] = len_bit1[10] && (str1[95:88] != 8'd0);
  assign len_bit1[12] = len_bit1[11] && (str1[103:96] != 8'd0);
  assign len_bit1[13] = len_bit1[12] && (str1[111:104] != 8'd0);
  assign len_bit1[14] = len_bit1[13] && (str1[119:112] != 8'd0);
  assign len_bit1[15] = len_bit1[14] && (str1[127:120] != 8'd0);
  
  wire [4:0] len1;
  assign len1 = (!len_bit1[0]) ? 5'd0 :
                (!len_bit1[1]) ? 5'd1 :
                (!len_bit1[2]) ? 5'd2 :
                (!len_bit1[3]) ? 5'd3 :
                (!len_bit1[4]) ? 5'd4 :
                (!len_bit1[5]) ? 5'd5 :
                (!len_bit1[6]) ? 5'd6 :
                (!len_bit1[7]) ? 5'd7 :
                (!len_bit1[8]) ? 5'd8 :
                (!len_bit1[9]) ? 5'd9 :
                (!len_bit1[10]) ? 5'd10 :
                (!len_bit1[11]) ? 5'd11 :
                (!len_bit1[12]) ? 5'd12 :
                (!len_bit1[13]) ? 5'd13 :
                (!len_bit1[14]) ? 5'd14 :
                (!len_bit1[15]) ? 5'd15 : 5'd16;
  
  // Calculate lengths for str2
  wire [15:0] len_bit2;
  assign len_bit2[0] = (str2[7:0] != 8'd0);
  assign len_bit2[1] = len_bit2[0] && (str2[15:8] != 8'd0);
  assign len_bit2[2] = len_bit2[1] && (str2[23:16] != 8'd0);
  assign len_bit2[3] = len_bit2[2] && (str2[31:24] != 8'd0);
  assign len_bit2[4] = len_bit2[3] && (str2[39:32] != 8'd0);
  assign len_bit2[5] = len_bit2[4] && (str2[47:40] != 8'd0);
  assign len_bit2[6] = len_bit2[5] && (str2[55:48] != 8'd0);
  assign len_bit2[7] = len_bit2[6] && (str2[63:56] != 8'd0);
  assign len_bit2[8] = len_bit2[7] && (str2[71:64] != 8'd0);
  assign len_bit2[9] = len_bit2[8] && (str2[79:72] != 8'd0);
  assign len_bit2[10] = len_bit2[9] && (str2[87:80] != 8'd0);
  assign len_bit2[11] = len_bit2[10] && (str2[95:88] != 8'd0);
  assign len_bit2[12] = len_bit2[11] && (str2[103:96] != 8'd0);
  assign len_bit2[13] = len_bit2[12] && (str2[111:104] != 8'd0);
  assign len_bit2[14] = len_bit2[13] && (str2[119:112] != 8'd0);
  assign len_bit2[15] = len_bit2[14] && (str2[127:120] != 8'd0);
  
  wire [4:0] len2;
  assign len2 = (!len_bit2[0]) ? 5'd0 :
                (!len_bit2[1]) ? 5'd1 :
                (!len_bit2[2]) ? 5'd2 :
                (!len_bit2[3]) ? 5'd3 :
                (!len_bit2[4]) ? 5'd4 :
                (!len_bit2[5]) ? 5'd5 :
                (!len_bit2[6]) ? 5'd6 :
                (!len_bit2[7]) ? 5'd7 :
                (!len_bit2[8]) ? 5'd8 :
                (!len_bit2[9]) ? 5'd9 :
                (!len_bit2[10]) ? 5'd10 :
                (!len_bit2[11]) ? 5'd11 :
                (!len_bit2[12]) ? 5'd12 :
                (!len_bit2[13]) ? 5'd13 :
                (!len_bit2[14]) ? 5'd14 :
                (!len_bit2[15]) ? 5'd15 : 5'd16;
  
  // Calculate lengths for str3
  wire [15:0] len_bit3;
  assign len_bit3[0] = (str3[7:0] != 8'd0);
  assign len_bit3[1] = len_bit3[0] && (str3[15:8] != 8'd0);
  assign len_bit3[2] = len_bit3[1] && (str3[23:16] != 8'd0);
  assign len_bit3[3] = len_bit3[2] && (str3[31:24] != 8'd0);
  assign len_bit3[4] = len_bit3[3] && (str3[39:32] != 8'd0);
  assign len_bit3[5] = len_bit3[4] && (str3[47:40] != 8'd0);
  assign len_bit3[6] = len_bit3[5] && (str3[55:48] != 8'd0);
  assign len_bit3[7] = len_bit3[6] && (str3[63:56] != 8'd0);
  assign len_bit3[8] = len_bit3[7] && (str3[71:64] != 8'd0);
  assign len_bit3[9] = len_bit3[8] && (str3[79:72] != 8'd0);
  assign len_bit3[10] = len_bit3[9] && (str3[87:80] != 8'd0);
  assign len_bit3[11] = len_bit3[10] && (str3[95:88] != 8'd0);
  assign len_bit3[12] = len_bit3[11] && (str3[103:96] != 8'd0);
  assign len_bit3[13] = len_bit3[12] && (str3[111:104] != 8'd0);
  assign len_bit3[14] = len_bit3[13] && (str3[119:112] != 8'd0);
  assign len_bit3[15] = len_bit3[14] && (str3[127:120] != 8'd0);
  
  wire [4:0] len3;
  assign len3 = (!len_bit3[0]) ? 5'd0 :
                (!len_bit3[1]) ? 5'd1 :
                (!len_bit3[2]) ? 5'd2 :
                (!len_bit3[3]) ? 5'd3 :
                (!len_bit3[4]) ? 5'd4 :
                (!len_bit3[5]) ? 5'd5 :
                (!len_bit3[6]) ? 5'd6 :
                (!len_bit3[7]) ? 5'd7 :
                (!len_bit3[8]) ? 5'd8 :
                (!len_bit3[9]) ? 5'd9 :
                (!len_bit3[10]) ? 5'd10 :
                (!len_bit3[11]) ? 5'd11 :
                (!len_bit3[12]) ? 5'd12 :
                (!len_bit3[13]) ? 5'd13 :
                (!len_bit3[14]) ? 5'd14 :
                (!len_bit3[15]) ? 5'd15 : 5'd16;
  
  // Calculate lengths for str4
  wire [15:0] len_bit4;
  assign len_bit4[0] = (str4[7:0] != 8'd0);
  assign len_bit4[1] = len_bit4[0] && (str4[15:8] != 8'd0);
  assign len_bit4[2] = len_bit4[1] && (str4[23:16] != 8'd0);
  assign len_bit4[3] = len_bit4[2] && (str4[31:24] != 8'd0);
  assign len_bit4[4] = len_bit4[3] && (str4[39:32] != 8'd0);
  assign len_bit4[5] = len_bit4[4] && (str4[47:40] != 8'd0);
  assign len_bit4[6] = len_bit4[5] && (str4[55:48] != 8'd0);
  assign len_bit4[7] = len_bit4[6] && (str4[63:56] != 8'd0);
  assign len_bit4[8] = len_bit4[7] && (str4[71:64] != 8'd0);
  assign len_bit4[9] = len_bit4[8] && (str4[79:72] != 8'd0);
  assign len_bit4[10] = len_bit4[9] && (str4[87:80] != 8'd0);
  assign len_bit4[11] = len_bit4[10] && (str4[95:88] != 8'd0);
  assign len_bit4[12] = len_bit4[11] && (str4[103:96] != 8'd0);
  assign len_bit4[13] = len_bit4[12] && (str4[111:104] != 8'd0);
  assign len_bit4[14] = len_bit4[13] && (str4[119:112] != 8'd0);
  assign len_bit4[15] = len_bit4[14] && (str4[127:120] != 8'd0);
  
  wire [4:0] len4;
  assign len4 = (!len_bit4[0]) ? 5'd0 :
                (!len_bit4[1]) ? 5'd1 :
                (!len_bit4[2]) ? 5'd2 :
                (!len_bit4[3]) ? 5'd3 :
                (!len_bit4[4]) ? 5'd4 :
                (!len_bit4[5]) ? 5'd5 :
                (!len_bit4[6]) ? 5'd6 :
                (!len_bit4[7]) ? 5'd7 :
                (!len_bit4[8]) ? 5'd8 :
                (!len_bit4[9]) ? 5'd9 :
                (!len_bit4[10]) ? 5'd10 :
                (!len_bit4[11]) ? 5'd11 :
                (!len_bit4[12]) ? 5'd12 :
                (!len_bit4[13]) ? 5'd13 :
                (!len_bit4[14]) ? 5'd14 :
                (!len_bit4[15]) ? 5'd15 : 5'd16;
  
  // Calculate lengths for str5
  wire [15:0] len_bit5;
  assign len_bit5[0] = (str5[7:0] != 8'd0);
  assign len_bit5[1] = len_bit5[0] && (str5[15:8] != 8'd0);
  assign len_bit5[2] = len_bit5[1] && (str5[23:16] != 8'd0);
  assign len_bit5[3] = len_bit5[2] && (str5[31:24] != 8'd0);
  assign len_bit5[4] = len_bit5[3] && (str5[39:32] != 8'd0);
  assign len_bit5[5] = len_bit5[4] && (str5[47:40] != 8'd0);
  assign len_bit5[6] = len_bit5[5] && (str5[55:48] != 8'd0);
  assign len_bit5[7] = len_bit5[6] && (str5[63:56] != 8'd0);
  assign len_bit5[8] = len_bit5[7] && (str5[71:64] != 8'd0);
  assign len_bit5[9] = len_bit5[8] && (str5[79:72] != 8'd0);
  assign len_bit5[10] = len_bit5[9] && (str5[87:80] != 8'd0);
  assign len_bit5[11] = len_bit5[10] && (str5[95:88] != 8'd0);
  assign len_bit5[12] = len_bit5[11] && (str5[103:96] != 8'd0);
  assign len_bit5[13] = len_bit5[12] && (str5[111:104] != 8'd0);
  assign len_bit5[14] = len_bit5[13] && (str5[119:112] != 8'd0);
  assign len_bit5[15] = len_bit5[14] && (str5[127:120] != 8'd0);
  
  wire [4:0] len5;
  assign len5 = (!len_bit5[0]) ? 5'd0 :
                (!len_bit5[1]) ? 5'd1 :
                (!len_bit5[2]) ? 5'd2 :
                (!len_bit5[3]) ? 5'd3 :
                (!len_bit5[4]) ? 5'd4 :
                (!len_bit5[5]) ? 5'd5 :
                (!len_bit5[6]) ? 5'd6 :
                (!len_bit5[7]) ? 5'd7 :
                (!len_bit5[8]) ? 5'd8 :
                (!len_bit5[9]) ? 5'd9 :
                (!len_bit5[10]) ? 5'd10 :
                (!len_bit5[11]) ? 5'd11 :
                (!len_bit5[12]) ? 5'd12 :
                (!len_bit5[13]) ? 5'd13 :
                (!len_bit5[14]) ? 5'd14 :
                (!len_bit5[15]) ? 5'd15 : 5'd16;
  
  // Calculate lengths for str6
  wire [15:0] len_bit6;
  assign len_bit6[0] = (str6[7:0] != 8'd0);
  assign len_bit6[1] = len_bit6[0] && (str6[15:8] != 8'd0);
  assign len_bit6[2] = len_bit6[1] && (str6[23:16] != 8'd0);
  assign len_bit6[3] = len_bit6[2] && (str6[31:24] != 8'd0);
  assign len_bit6[4] = len_bit6[3] && (str6[39:32] != 8'd0);
  assign len_bit6[5] = len_bit6[4] && (str6[47:40] != 8'd0);
  assign len_bit6[6] = len_bit6[5] && (str6[55:48] != 8'd0);
  assign len_bit6[7] = len_bit6[6] && (str6[63:56] != 8'd0);
  assign len_bit6[8] = len_bit6[7] && (str6[71:64] != 8'd0);
  assign len_bit6[9] = len_bit6[8] && (str6[79:72] != 8'd0);
  assign len_bit6[10] = len_bit6[9] && (str6[87:80] != 8'd0);
  assign len_bit6[11] = len_bit6[10] && (str6[95:88] != 8'd0);
  assign len_bit6[12] = len_bit6[11] && (str6[103:96] != 8'd0);
  assign len_bit6[13] = len_bit6[12] && (str6[111:104] != 8'd0);
  assign len_bit6[14] = len_bit6[13] && (str6[119:112] != 8'd0);
  assign len_bit6[15] = len_bit6[14] && (str6[127:120] != 8'd0);
  
  wire [4:0] len6;
  assign len6 = (!len_bit6[0]) ? 5'd0 :
                (!len_bit6[1]) ? 5'd1 :
                (!len_bit6[2]) ? 5'd2 :
                (!len_bit6[3]) ? 5'd3 :
                (!len_bit6[4]) ? 5'd4 :
                (!len_bit6[5]) ? 5'd5 :
                (!len_bit6[6]) ? 5'd6 :
                (!len_bit6[7]) ? 5'd7 :
                (!len_bit6[8]) ? 5'd8 :
                (!len_bit6[9]) ? 5'd9 :
                (!len_bit6[10]) ? 5'd10 :
                (!len_bit6[11]) ? 5'd11 :
                (!len_bit6[12]) ? 5'd12 :
                (!len_bit6[13]) ? 5'd13 :
                (!len_bit6[14]) ? 5'd14 :
                (!len_bit6[15]) ? 5'd15 : 5'd16;
  
  // Calculate lengths for str7
  wire [15:0] len_bit7;
  assign len_bit7[0] = (str7[7:0] != 8'd0);
  assign len_bit7[1] = len_bit7[0] && (str7[15:8] != 8'd0);
  assign len_bit7[2] = len_bit7[1] && (str7[23:16] != 8'd0);
  assign len_bit7[3] = len_bit7[2] && (str7[31:24] != 8'd0);
  assign len_bit7[4] = len_bit7[3] && (str7[39:32] != 8'd0);
  assign len_bit7[5] = len_bit7[4] && (str7[47:40] != 8'd0);
  assign len_bit7[6] = len_bit7[5] && (str7[55:48] != 8'd0);
  assign len_bit7[7] = len_bit7[6] && (str7[63:56] != 8'd0);
  assign len_bit7[8] = len_bit7[7] && (str7[71:64] != 8'd0);
  assign len_bit7[9] = len_bit7[8] && (str7[79:72] != 8'd0);
  assign len_bit7[10] = len_bit7[9] && (str7[87:80] != 8'd0);
  assign len_bit7[11] = len_bit7[10] && (str7[95:88] != 8'd0);
  assign len_bit7[12] = len_bit7[11] && (str7[103:96] != 8'd0);
  assign len_bit7[13] = len_bit7[12] && (str7[111:104] != 8'd0);
  assign len_bit7[14] = len_bit7[13] && (str7[119:112] != 8'd0);
  assign len_bit7[15] = len_bit7[14] && (str7[127:120] != 8'd0);
  
  wire [4:0] len7;
  assign len7 = (!len_bit7[0]) ? 5'd0 :
                (!len_bit7[1]) ? 5'd1 :
                (!len_bit7[2]) ? 5'd2 :
                (!len_bit7[3]) ? 5'd3 :
                (!len_bit7[4]) ? 5'd4 :
                (!len_bit7[5]) ? 5'd5 :
                (!len_bit7[6]) ? 5'd6 :
                (!len_bit7[7]) ? 5'd7 :
                (!len_bit7[8]) ? 5'd8 :
                (!len_bit7[9]) ? 5'd9 :
                (!len_bit7[10]) ? 5'd10 :
                (!len_bit7[11]) ? 5'd11 :
                (!len_bit7[12]) ? 5'd12 :
                (!len_bit7[13]) ? 5'd13 :
                (!len_bit7[14]) ? 5'd14 :
                (!len_bit7[15]) ? 5'd15 : 5'd16;
  
  always_comb begin
    valid_mask[0] = (len0 == str_length[4:0]);
    valid_mask[1] = (len1 == str_length[4:0]);
    valid_mask[2] = (len2 == str_length[4:0]);
    valid_mask[3] = (len3 == str_length[4:0]);
    valid_mask[4] = (len4 == str_length[4:0]);
    valid_mask[5] = (len5 == str_length[4:0]);
    valid_mask[6] = (len6 == str_length[4:0]);
    valid_mask[7] = (len7 == str_length[4:0]);
    
    filtered0 = valid_mask[0] ? str0 : 128'd0;
    filtered1 = valid_mask[1] ? str1 : 128'd0;
    filtered2 = valid_mask[2] ? str2 : 128'd0;
    filtered3 = valid_mask[3] ? str3 : 128'd0;
    filtered4 = valid_mask[4] ? str4 : 128'd0;
    filtered5 = valid_mask[5] ? str5 : 128'd0;
    filtered6 = valid_mask[6] ? str6 : 128'd0;
    filtered7 = valid_mask[7] ? str7 : 128'd0;
  end
endmodule