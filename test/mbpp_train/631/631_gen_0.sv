module replace_spaces_underscores(
  input  [127:0] text_in,
  output [127:0] text_out
);

  assign text_out[7:0]     = (text_in[7:0]     == 8'h20) ? 8'h5F : (text_in[7:0]     == 8'h5F) ? 8'h20 : text_in[7:0];
  assign text_out[15:8]    = (text_in[15:8]    == 8'h20) ? 8'h5F : (text_in[15:8]    == 8'h5F) ? 8'h20 : text_in[15:8];
  assign text_out[23:16]   = (text_in[23:16]   == 8'h20) ? 8'h5F : (text_in[23:16]   == 8'h5F) ? 8'h20 : text_in[23:16];
  assign text_out[31:24]   = (text_in[31:24]   == 8'h20) ? 8'h5F : (text_in[31:24]   == 8'h5F) ? 8'h20 : text_in[31:24];
  assign text_out[39:32]   = (text_in[39:32]   == 8'h20) ? 8'h5F : (text_in[39:32]   == 8'h5F) ? 8'h20 : text_in[39:32];
  assign text_out[47:40]   = (text_in[47:40]   == 8'h20) ? 8'h5F : (text_in[47:40]   == 8'h5F) ? 8'h20 : text_in[47:40];
  assign text_out[55:48]   = (text_in[55:48]   == 8'h20) ? 8'h5F : (text_in[55:48]   == 8'h5F) ? 8'h20 : text_in[55:48];
  assign text_out[63:56]   = (text_in[63:56]   == 8'h20) ? 8'h5F : (text_in[63:56]   == 8'h5F) ? 8'h20 : text_in[63:56];
  assign text_out[71:64]   = (text_in[71:64]   == 8'h20) ? 8'h5F : (text_in[71:64]   == 8'h5F) ? 8'h20 : text_in[71:64];
  assign text_out[79:72]   = (text_in[79:72]   == 8'h20) ? 8'h5F : (text_in[79:72]   == 8'h5F) ? 8'h20 : text_in[79:72];
  assign text_out[87:80]   = (text_in[87:80]   == 8'h20) ? 8'h5F : (text_in[87:80]   == 8'h5F) ? 8'h20 : text_in[87:80];
  assign text_out[95:88]   = (text_in[95:88]   == 8'h20) ? 8'h5F : (text_in[95:88]   == 8'h5F) ? 8'h20 : text_in[95:88];
  assign text_out[103:96]  = (text_in[103:96]  == 8'h20) ? 8'h5F : (text_in[103:96]  == 8'h5F) ? 8'h20 : text_in[103:96];
  assign text_out[111:104] = (text_in[111:104] == 8'h20) ? 8'h5F : (text_in[111:104] == 8'h5F) ? 8'h20 : text_in[111:104];
  assign text_out[119:112] = (text_in[119:112] == 8'h20) ? 8'h5F : (text_in[119:112] == 8'h5F) ? 8'h20 : text_in[119:112];
  assign text_out[127:120] = (text_in[127:120] == 8'h20) ? 8'h5F : (text_in[127:120] == 8'h5F) ? 8'h20 : text_in[127:120];

endmodule