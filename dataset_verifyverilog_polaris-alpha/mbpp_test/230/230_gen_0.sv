module replace_spaces(
  input  [255:0] str_in,
  input  [7:0]   char_in,
  output [255:0] str_out
);

  assign str_out[7:0]     = (str_in[7:0]     == 8'h20) ? char_in : str_in[7:0];
  assign str_out[15:8]    = (str_in[15:8]    == 8'h20) ? char_in : str_in[15:8];
  assign str_out[23:16]   = (str_in[23:16]   == 8'h20) ? char_in : str_in[23:16];
  assign str_out[31:24]   = (str_in[31:24]   == 8'h20) ? char_in : str_in[31:24];
  assign str_out[39:32]   = (str_in[39:32]   == 8'h20) ? char_in : str_in[39:32];
  assign str_out[47:40]   = (str_in[47:40]   == 8'h20) ? char_in : str_in[47:40];
  assign str_out[55:48]   = (str_in[55:48]   == 8'h20) ? char_in : str_in[55:48];
  assign str_out[63:56]   = (str_in[63:56]   == 8'h20) ? char_in : str_in[63:56];
  assign str_out[71:64]   = (str_in[71:64]   == 8'h20) ? char_in : str_in[71:64];
  assign str_out[79:72]   = (str_in[79:72]   == 8'h20) ? char_in : str_in[79:72];
  assign str_out[87:80]   = (str_in[87:80]   == 8'h20) ? char_in : str_in[87:80];
  assign str_out[95:88]   = (str_in[95:88]   == 8'h20) ? char_in : str_in[95:88];
  assign str_out[103:96]  = (str_in[103:96]  == 8'h20) ? char_in : str_in[103:96];
  assign str_out[111:104] = (str_in[111:104] == 8'h20) ? char_in : str_in[111:104];
  assign str_out[119:112] = (str_in[119:112] == 8'h20) ? char_in : str_in[119:112];
  assign str_out[127:120] = (str_in[127:120] == 8'h20) ? char_in : str_in[127:120];
  assign str_out[135:128] = (str_in[135:128] == 8'h20) ? char_in : str_in[135:128];
  assign str_out[143:136] = (str_in[143:136] == 8'h20) ? char_in : str_in[143:136];
  assign str_out[151:144] = (str_in[151:144] == 8'h20) ? char_in : str_in[151:144];
  assign str_out[159:152] = (str_in[159:152] == 8'h20) ? char_in : str_in[159:152];
  assign str_out[167:160] = (str_in[167:160] == 8'h20) ? char_in : str_in[167:160];
  assign str_out[175:168] = (str_in[175:168] == 8'h20) ? char_in : str_in[175:168];
  assign str_out[183:176] = (str_in[183:176] == 8'h20) ? char_in : str_in[183:176];
  assign str_out[191:184] = (str_in[191:184] == 8'h20) ? char_in : str_in[191:184];
  assign str_out[199:192] = (str_in[199:192] == 8'h20) ? char_in : str_in[199:192];
  assign str_out[207:200] = (str_in[207:200] == 8'h20) ? char_in : str_in[207:200];
  assign str_out[215:208] = (str_in[215:208] == 8'h20) ? char_in : str_in[215:208];
  assign str_out[223:216] = (str_in[223:216] == 8'h20) ? char_in : str_in[223:216];
  assign str_out[231:224] = (str_in[231:224] == 8'h20) ? char_in : str_in[231:224];
  assign str_out[239:232] = (str_in[239:232] == 8'h20) ? char_in : str_in[239:232];
  assign str_out[247:240] = (str_in[247:240] == 8'h20) ? char_in : str_in[247:240];
  assign str_out[255:248] = (str_in[255:248] == 8'h20) ? char_in : str_in[255:248];

endmodule