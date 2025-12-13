module char_replacer(
  input  [127:0] str_in,
  input  [7:0]   ch,
  input  [7:0]   newch,
  output [127:0] str_out
);

  assign str_out[7:0]     = (str_in[7:0]     == ch) ? newch : str_in[7:0];
  assign str_out[15:8]    = (str_in[15:8]    == ch) ? newch : str_in[15:8];
  assign str_out[23:16]   = (str_in[23:16]   == ch) ? newch : str_in[23:16];
  assign str_out[31:24]   = (str_in[31:24]   == ch) ? newch : str_in[31:24];
  assign str_out[39:32]   = (str_in[39:32]   == ch) ? newch : str_in[39:32];
  assign str_out[47:40]   = (str_in[47:40]   == ch) ? newch : str_in[47:40];
  assign str_out[55:48]   = (str_in[55:48]   == ch) ? newch : str_in[55:48];
  assign str_out[63:56]   = (str_in[63:56]   == ch) ? newch : str_in[63:56];
  assign str_out[71:64]   = (str_in[71:64]   == ch) ? newch : str_in[71:64];
  assign str_out[79:72]   = (str_in[79:72]   == ch) ? newch : str_in[79:72];
  assign str_out[87:80]   = (str_in[87:80]   == ch) ? newch : str_in[87:80];
  assign str_out[95:88]   = (str_in[95:88]   == ch) ? newch : str_in[95:88];
  assign str_out[103:96]  = (str_in[103:96]  == ch) ? newch : str_in[103:96];
  assign str_out[111:104] = (str_in[111:104] == ch) ? newch : str_in[111:104];
  assign str_out[119:112] = (str_in[119:112] == ch) ? newch : str_in[119:112];
  assign str_out[127:120] = (str_in[127:120] == ch) ? newch : str_in[127:120];

endmodule