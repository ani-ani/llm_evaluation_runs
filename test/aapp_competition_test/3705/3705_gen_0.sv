module phone_number_counter(
  input  [4:0]  n,          // Number of cards (1-32)
  input  [127:0] s,         // 32 digits packed left-aligned
  output reg [1:0] count    // Maximum number of phone numbers (0-2)
);

  // One-hot '8' detection for all 32 digit slots
  wire [31:0] is_eight;

  assign is_eight[31] = (s[127:124] == 4'b1000);
  assign is_eight[30] = (s[123:120] == 4'b1000);
  assign is_eight[29] = (s[119:116] == 4'b1000);
  assign is_eight[28] = (s[115:112] == 4'b1000);
  assign is_eight[27] = (s[111:108] == 4'b1000);
  assign is_eight[26] = (s[107:104] == 4'b1000);
  assign is_eight[25] = (s[103:100] == 4'b1000);
  assign is_eight[24] = (s[99:96]   == 4'b1000);
  assign is_eight[23] = (s[95:92]   == 4'b1000);
  assign is_eight[22] = (s[91:88]   == 4'b1000);
  assign is_eight[21] = (s[87:84]   == 4'b1000);
  assign is_eight[20] = (s[83:80]   == 4'b1000);
  assign is_eight[19] = (s[79:76]   == 4'b1000);
  assign is_eight[18] = (s[75:72]   == 4'b1000);
  assign is_eight[17] = (s[71:68]   == 4'b1000);
  assign is_eight[16] = (s[67:64]   == 4'b1000);
  assign is_eight[15] = (s[63:60]   == 4'b1000);
  assign is_eight[14] = (s[59:56]   == 4'b1000);
  assign is_eight[13] = (s[55:52]   == 4'b1000);
  assign is_eight[12] = (s[51:48]   == 4'b1000);
  assign is_eight[11] = (s[47:44]   == 4'b1000);
  assign is_eight[10] = (s[43:40]   == 4'b1000);
  assign is_eight[9]  = (s[39:36]   == 4'b1000);
  assign is_eight[8]  = (s[35:32]   == 4'b1000);
  assign is_eight[7]  = (s[31:28]   == 4'b1000);
  assign is_eight[6]  = (s[27:24]   == 4'b1000);
  assign is_eight[5]  = (s[23:20]   == 4'b1000);
  assign is_eight[4]  = (s[19:16]   == 4'b1000);
  assign is_eight[3]  = (s[15:12]   == 4'b1000);
  assign is_eight[2]  = (s[11:8]    == 4'b1000);
  assign is_eight[1]  = (s[7:4]     == 4'b1000);
  assign is_eight[0]  = (s[3:0]     == 4'b1000);

  // Mask out positions beyond n (only first n digits are valid)
  wire [31:0] valid_mask;
  assign valid_mask = (n == 0) ? 32'b0 : (~32'b0 << (32 - n));

  wire [31:0] masked_eight = is_eight & valid_mask;

  // Count '8's (we only care up to 2, but implement a small adder tree)
  // Pairwise sums (2 bits each: max 2)
  wire [1:0] s0_0 = masked_eight[31] + masked_eight[30];
  wire [1:0] s0_1 = masked_eight[29] + masked_eight[28];
  wire [1:0] s0_2 = masked_eight[27] + masked_eight[26];
  wire [1:0] s0_3 = masked_eight[25] + masked_eight[24];
  wire [1:0] s0_4 = masked_eight[23] + masked_eight[22];
  wire [1:0] s0_5 = masked_eight[21] + masked_eight[20];
  wire [1:0] s0_6 = masked_eight[19] + masked_eight[18];
  wire [1:0] s0_7 = masked_eight[17] + masked_eight[16];
  wire [1:0] s0_8 = masked_eight[15] + masked_eight[14];
  wire [1:0] s0_9 = masked_eight[13] + masked_eight[12];
  wire [1:0] s0_10 = masked_eight[11] + masked_eight[10];
  wire [1:0] s0_11 = masked_eight[9]  + masked_eight[8];
  wire [1:0] s0_12 = masked_eight[7]  + masked_eight[6];
  wire [1:0] s0_13 = masked_eight[5]  + masked_eight[4];
  wire [1:0] s0_14 = masked_eight[3]  + masked_eight[2];
  wire [1:0] s0_15 = masked_eight[1]  + masked_eight[0];

  // Next level (3 bits each: max 4)
  wire [2:0] s1_0 = s0_0 + s0_1;
  wire [2:0] s1_1 = s0_2 + s0_3;
  wire [2:0] s1_2 = s0_4 + s0_5;
  wire [2:0] s1_3 = s0_6 + s0_7;
  wire [2:0] s1_4 = s0_8 + s0_9;
  wire [2:0] s1_5 = s0_10 + s0_11;
  wire [2:0] s1_6 = s0_12 + s0_13;
  wire [2:0] s1_7 = s0_14 + s0_15;

  // Next level (4 bits each: max 8)
  wire [3:0] s2_0 = s1_0 + s1_1;
  wire [3:0] s2_1 = s1_2 + s1_3;
  wire [3:0] s2_2 = s1_4 + s1_5;
  wire [3:0] s2_3 = s1_6 + s1_7;

  // Next level (5 bits each: max 16)
  wire [4:0] s3_0 = s2_0 + s2_1;
  wire [4:0] s3_1 = s2_2 + s2_3;

  // Final '8' count (6 bits: max 32)
  wire [5:0] eight_count = s3_0 + s3_1;

  // floor(n / 11) limited to 0,1,2
  wire [1:0] max_by_n = (n >= 5'd22) ? 2'd2 :
                       (n >= 5'd11) ? 2'd1 :
                                      2'd0;

  // Take min(eight_count, max_by_n), saturating eight_count at 2
  wire [1:0] eight_limited = (eight_count >= 6'd2) ? 2'd2 : eight_count[1:0];

  always @* begin
    if (eight_limited < max_by_n)
      count = eight_limited;
    else
      count = max_by_n;
  end

endmodule