module count_std(
  input  [127:0] str,
  output [2:0]  count
);

  wire [2:0] match_sum;

  wire [14:0] match;

  assign match[0]  = (str[127:120] == 8'd115) && (str[119:112] == 8'd116) && (str[111:104] == 8'd100);
  assign match[1]  = (str[119:112] == 8'd115) && (str[111:104] == 8'd116) && (str[103:96]  == 8'd100);
  assign match[2]  = (str[111:104] == 8'd115) && (str[103:96]  == 8'd116) && (str[95:88]   == 8'd100);
  assign match[3]  = (str[103:96]  == 8'd115) && (str[95:88]   == 8'd116) && (str[87:80]   == 8'd100);
  assign match[4]  = (str[95:88]   == 8'd115) && (str[87:80]   == 8'd116) && (str[79:72]   == 8'd100);
  assign match[5]  = (str[87:80]   == 8'd115) && (str[79:72]   == 8'd116) && (str[71:64]   == 8'd100);
  assign match[6]  = (str[79:72]   == 8'd115) && (str[71:64]   == 8'd116) && (str[63:56]   == 8'd100);
  assign match[7]  = (str[71:64]   == 8'd115) && (str[63:56]   == 8'd116) && (str[55:48]   == 8'd100);
  assign match[8]  = (str[63:56]   == 8'd115) && (str[55:48]   == 8'd116) && (str[47:40]   == 8'd100);
  assign match[9]  = (str[55:48]   == 8'd115) && (str[47:40]   == 8'd116) && (str[39:32]   == 8'd100);
  assign match[10] = (str[47:40]   == 8'd115) && (str[39:32]   == 8'd116) && (str[31:24]   == 8'd100);
  assign match[11] = (str[39:32]   == 8'd115) && (str[31:24]   == 8'd116) && (str[23:16]   == 8'd100);
  assign match[12] = (str[31:24]   == 8'd115) && (str[23:16]   == 8'd116) && (str[15:8]    == 8'd100);
  assign match[13] = (str[23:16]   == 8'd115) && (str[15:8]    == 8'd116) && (str[7:0]     == 8'd100);
  assign match[14] = 1'b0; // padding to simplify summation logic if needed

  // Sum matches (max 14 -> fits in 4 bits; output is 3 bits per spec)
  wire [3:0] sum0 = match[0]  + match[1]  + match[2]  + match[3];
  wire [3:0] sum1 = match[4]  + match[5]  + match[6]  + match[7];
  wire [3:0] sum2 = match[8]  + match[9]  + match[10] + match[11];
  wire [3:0] sum3 = match[12] + match[13] + match[14];

  wire [4:0] sum01 = sum0 + sum1;
  wire [4:0] sum23 = sum2 + sum3;
  wire [4:0] total = sum01 + sum23;

  assign count = total[2:0];

endmodule