module string_length(
  input  [127:0] string_bytes,
  output [4:0]   length
);

  wire [15:0] nz;

  assign nz[0]  = |string_bytes[7:0];
  assign nz[1]  = |string_bytes[15:8];
  assign nz[2]  = |string_bytes[23:16];
  assign nz[3]  = |string_bytes[31:24];
  assign nz[4]  = |string_bytes[39:32];
  assign nz[5]  = |string_bytes[47:40];
  assign nz[6]  = |string_bytes[55:48];
  assign nz[7]  = |string_bytes[63:56];
  assign nz[8]  = |string_bytes[71:64];
  assign nz[9]  = |string_bytes[79:72];
  assign nz[10] = |string_bytes[87:80];
  assign nz[11] = |string_bytes[95:88];
  assign nz[12] = |string_bytes[103:96];
  assign nz[13] = |string_bytes[111:104];
  assign nz[14] = |string_bytes[119:112];
  assign nz[15] = |string_bytes[127:120];

  assign length =
      (!nz[0])  ? 5'd0  :
      (!nz[1])  ? 5'd1  :
      (!nz[2])  ? 5'd2  :
      (!nz[3])  ? 5'd3  :
      (!nz[4])  ? 5'd4  :
      (!nz[5])  ? 5'd5  :
      (!nz[6])  ? 5'd6  :
      (!nz[7])  ? 5'd7  :
      (!nz[8])  ? 5'd8  :
      (!nz[9])  ? 5'd9  :
      (!nz[10]) ? 5'd10 :
      (!nz[11]) ? 5'd11 :
      (!nz[12]) ? 5'd12 :
      (!nz[13]) ? 5'd13 :
      (!nz[14]) ? 5'd14 :
      (!nz[15]) ? 5'd15 :
                  5'd16;

endmodule