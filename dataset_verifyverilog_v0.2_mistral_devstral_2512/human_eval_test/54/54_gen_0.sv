module same_chars (
  input [63:0] s0,
  input [63:0] s1,
  output result
);

  // Extract characters from s0
  wire [7:0] s0_chars [0:7];
  assign s0_chars[0] = s0[7:0];
  assign s0_chars[1] = s0[15:8];
  assign s0_chars[2] = s0[23:16];
  assign s0_chars[3] = s0[31:24];
  assign s0_chars[4] = s0[39:32];
  assign s0_chars[5] = s0[47:40];
  assign s0_chars[6] = s0[55:48];
  assign s0_chars[7] = s0[63:56];

  // Extract characters from s1
  wire [7:0] s1_chars [0:7];
  assign s1_chars[0] = s1[7:0];
  assign s1_chars[1] = s1[15:8];
  assign s1_chars[2] = s1[23:16];
  assign s1_chars[3] = s1[31:24];
  assign s1_chars[4] = s1[39:32];
  assign s1_chars[5] = s1[47:40];
  assign s1_chars[6] = s1[55:48];
  assign s1_chars[7] = s1[63:56];

  // Sort s0_chars using bubble sort
  wire [7:0] s0_sorted [0:7];
  wire [7:0] s0_temp1 [0:7];
  wire [7:0] s0_temp2 [0:7];
  wire [7:0] s0_temp3 [0:7];
  wire [7:0] s0_temp4 [0:7];
  wire [7:0] s0_temp5 [0:7];
  wire [7:0] s0_temp6 [0:7];

  // Pass 1
  assign s0_temp1[0] = (s0_chars[0] < s0_chars[1]) ? s0_chars[0] : s0_chars[1];
  assign s0_temp1[1] = (s0_chars[0] < s0_chars[1]) ? s0_chars[1] : s0_chars[0];
  assign s0_temp1[2] = (s0_chars[2] < s0_chars[3]) ? s0_chars[2] : s0_chars[3];
  assign s0_temp1[3] = (s0_chars[2] < s0_chars[3]) ? s0_chars[3] : s0_chars[2];
  assign s0_temp1[4] = (s0_chars[4] < s0_chars[5]) ? s0_chars[4] : s0_chars[5];
  assign s0_temp1[5] = (s0_chars[4] < s0_chars[5]) ? s0_chars[5] : s0_chars[4];
  assign s0_temp1[6] = (s0_chars[6] < s0_chars[7]) ? s0_chars[6] : s0_chars[7];
  assign s0_temp1[7] = (s0_chars[6] < s0_chars[7]) ? s0_chars[7] : s0_chars[6];

  // Pass 2
  assign s0_temp2[0] = (s0_temp1[0] < s0_temp1[2]) ? s0_temp1[0] : s0_temp1[2];
  assign s0_temp2[1] = (s0_temp1[1] < s0_temp1[3]) ? s0_temp1[1] : s0_temp1[3];
  assign s0_temp2[2] = (s0_temp1[0] < s0_temp1[2]) ? s0_temp1[2] : s0_temp1[0];
  assign s0_temp2[3] = (s0_temp1[1] < s0_temp1[3]) ? s0_temp1[3] : s0_temp1[1];
  assign s0_temp2[4] = (s0_temp1[4] < s0_temp1[6]) ? s0_temp1[4] : s0_temp1[6];
  assign s0_temp2[5] = (s0_temp1[5] < s0_temp1[7]) ? s0_temp1[5] : s0_temp1[7];
  assign s0_temp2[6] = (s0_temp1[4] < s0_temp1[6]) ? s0_temp1[6] : s0_temp1[4];
  assign s0_temp2[7] = (s0_temp1[5] < s0_temp1[7]) ? s0_temp1[7] : s0_temp1[5];

  // Pass 3
  assign s0_temp3[0] = (s0_temp2[0] < s0_temp2[4]) ? s0_temp2[0] : s0_temp2[4];
  assign s0_temp3[1] = (s0_temp2[1] < s0_temp2[5]) ? s0_temp2[1] : s0_temp2[5];
  assign s0_temp3[2] = (s0_temp2[2] < s0_temp2[6]) ? s0_temp2[2] : s0_temp2[6];
  assign s0_temp3[3] = (s0_temp2[3] < s0_temp2[7]) ? s0_temp2[3] : s0_temp2[7];
  assign s0_temp3[4] = (s0_temp2[0] < s0_temp2[4]) ? s0_temp2[4] : s0_temp2[0];
  assign s0_temp3[5] = (s0_temp2[1] < s0_temp2[5]) ? s0_temp2[5] : s0_temp2[1];
  assign s0_temp3[6] = (s0_temp2[2] < s0_temp2[6]) ? s0_temp2[6] : s0_temp2[2];
  assign s0_temp3[7] = (s0_temp2[3] < s0_temp2[7]) ? s0_temp2[7] : s0_temp2[3];

  // Pass 4
  assign s0_temp4[0] = (s0_temp3[0] < s0_temp3[1]) ? s0_temp3[0] : s0_temp3[1];
  assign s0_temp4[1] = (s0_temp3[0] < s0_temp3[1]) ? s0_temp3[1] : s0_temp3[0];
  assign s0_temp4[2] = (s0_temp3[2] < s0_temp3[3]) ? s0_temp3[2] : s0_temp3[3];
  assign s0_temp4[3] = (s0_temp3[2] < s0_temp3[3]) ? s0_temp3[3] : s0_temp3[2];
  assign s0_temp4[4] = (s0_temp3[4] < s0_temp3[5]) ? s0_temp3[4] : s0_temp3[5];
  assign s0_temp4[5] = (s0_temp3[4] < s0_temp3[5]) ? s0_temp3[5] : s0_temp3[4];
  assign s0_temp4[6] = (s0_temp3[6] < s0_temp3[7]) ? s0_temp3[6] : s0_temp3[7];
  assign s0_temp4[7] = (s0_temp3[6] < s0_temp3[7]) ? s0_temp3[7] : s0_temp3[6];

  // Pass 5
  assign s0_temp5[0] = (s0_temp4[0] < s0_temp4[2]) ? s0_temp4[0] : s0_temp4[2];
  assign s0_temp5[1] = (s0_temp4[1] < s0_temp4[3]) ? s0_temp4[1] : s0_temp4[3];
  assign s0_temp5[2] = (s0_temp4[0] < s0_temp4[2]) ? s0_temp4[2] : s0_temp4[0];
  assign s0_temp5[3] = (s0_temp4[1] < s0_temp4[3]) ? s0_temp4[3] : s0_temp4[1];
  assign s0_temp5[4] = (s0_temp4[4] < s0_temp4[6]) ? s0_temp4[4] : s0_temp4[6];
  assign s0_temp5[5] = (s0_temp4[5] < s0_temp4[7]) ? s0_temp4[5] : s0_temp4[7];
  assign s0_temp5[6] = (s0_temp4[4] < s0_temp4[6]) ? s0_temp4[6] : s0_temp4[4];
  assign s0_temp5[7] = (s0_temp4[5] < s0_temp4[7]) ? s0_temp4[7] : s0_temp4[5];

  // Pass 6
  assign s0_temp6[0] = (s0_temp5[0] < s0_temp5[4]) ? s0_temp5[0] : s0_temp5[4];
  assign s0_temp6[1] = (s0_temp5[1] < s0_temp5[5]) ? s0_temp5[1] : s0_temp5[5];
  assign s0_temp6[2] = (s0_temp5[2] < s0_temp5[6]) ? s0_temp5[2] : s0_temp5[6];
  assign s0_temp6[3] = (s0_temp5[3] < s0_temp5[7]) ? s0_temp5[3] : s0_temp5[7];
  assign s0_temp6[4] = (s0_temp5[0] < s0_temp5[4]) ? s0_temp5[4] : s0_temp5[0];
  assign s0_temp6[5] = (s0_temp5[1] < s0_temp5[5]) ? s0_temp5[5] : s0_temp5[1];
  assign s0_temp6[6] = (s0_temp5[2] < s0_temp5[6]) ? s0_temp5[6] : s0_temp5[2];
  assign s0_temp6[7] = (s0_temp5[3] < s0_temp5[7]) ? s0_temp5[7] : s0_temp5[3];

  // Final pass
  assign s0_sorted[0] = (s0_temp6[0] < s0_temp6[1]) ? s0_temp6[0] : s0_temp6[1];
  assign s0_sorted[1] = (s0_temp6[0] < s0_temp6[1]) ? s0_temp6[1] : s0_temp6[0];
  assign s0_sorted[2] = (s0_temp6[2] < s0_temp6[3]) ? s0_temp6[2] : s0_temp6[3];
  assign s0_sorted[3] = (s0_temp6[2] < s0_temp6[3]) ? s0_temp6[3] : s0_temp6[2];
  assign s0_sorted[4] = (s0_temp6[4] < s0_temp6[5]) ? s0_temp6[4] : s0_temp6[5];
  assign s0_sorted[5] = (s0_temp6[4] < s0_temp6[5]) ? s0_temp6[5] : s0_temp6[4];
  assign s0_sorted[6] = (s0_temp6[6] < s0_temp6[7]) ? s0_temp6[6] : s0_temp6[7];
  assign s0_sorted[7] = (s0_temp6[6] < s0_temp6[7]) ? s0_temp6[7] : s0_temp6[6];

  // Sort s1_chars using bubble sort
  wire [7:0] s1_sorted [0:7];
  wire [7:0] s1_temp1 [0:7];
  wire [7:0] s1_temp2 [0:7];
  wire [7:0] s1_temp3 [0:7];
  wire [7:0] s1_temp4 [0:7];
  wire [7:0] s1_temp5 [0:7];
  wire [7:0] s1_temp6 [0:7];

  // Pass 1
  assign s1_temp1[0] = (s1_chars[0] < s1_chars[1]) ? s1_chars[0] : s1_chars[1];
  assign s1_temp1[1] = (s1_chars[0] < s1_chars[1]) ? s1_chars[1] : s1_chars[0];
  assign s1_temp1[2] = (s1_chars[2] < s1_chars[3]) ? s1_chars[2] : s1_chars[3];
  assign s1_temp1[3] = (s1_chars[2] < s1_chars[3]) ? s1_chars[3] : s1_chars[2];
  assign s1_temp1[4] = (s1_chars[4] < s1_chars[5]) ? s1_chars[4] : s1_chars[5];
  assign s1_temp1[5] = (s1_chars[4] < s1_chars[5]) ? s1_chars[5] : s1_chars[4];
  assign s1_temp1[6] = (s1_chars[6] < s1_chars[7]) ? s1_chars[6] : s1_chars[7];
  assign s1_temp1[7] = (s1_chars[6] < s1_chars[7]) ? s1_chars[7] : s1_chars[6];

  // Pass 2
  assign s1_temp2[0] = (s1_temp1[0] < s1_temp1[2]) ? s1_temp1[0] : s1_temp1[2];
  assign s1_temp2[1] = (s1_temp1[1] < s1_temp1[3]) ? s1_temp1[1] : s1_temp1[3];
  assign s1_temp2[2] = (s1_temp1[0] < s1_temp1[2]) ? s1_temp1[2] : s1_temp1[0];
  assign s1_temp2[3] = (s1_temp1[1] < s1_temp1[3]) ? s1_temp1[3] : s1_temp1[1];
  assign s1_temp2[4] = (s1_temp1[4] < s1_temp1[6]) ? s1_temp1[4] : s1_temp1[6];
  assign s1_temp2[5] = (s1_temp1[5] < s1_temp1[7]) ? s1_temp1[5] : s1_temp1[7];
  assign s1_temp2[6] = (s1_temp1[4] < s1_temp1[6]) ? s1_temp1[6] : s1_temp1[4];
  assign s1_temp2[7] = (s1_temp1[5] < s1_temp1[7]) ? s1_temp1[7] : s1_temp1[5];

  // Pass 3
  assign s1_temp3[0] = (s1_temp2[0] < s1_temp2[4]) ? s1_temp2[0] : s1_temp2[4];
  assign s1_temp3[1] = (s1_temp2[1] < s1_temp2[5]) ? s1_temp2[1] : s1_temp2[5];
  assign s1_temp3[2] = (s1_temp2[2] < s1_temp2[6]) ? s1_temp2[2] : s1_temp2[6];
  assign s1_temp3[3] = (s1_temp2[3] < s1_temp2[7]) ? s1_temp2[3] : s1_temp2[7];
  assign s1_temp3[4] = (s1_temp2[0] < s1_temp2[4]) ? s1_temp2[4] : s1_temp2[0];
  assign s1_temp3[5] = (s1_temp2[1] < s1_temp2[5]) ? s1_temp2[5] : s1_temp2[1];
  assign s1_temp3[6] = (s1_temp2[2] < s1_temp2[6]) ? s1_temp2[6] : s1_temp2[2];
  assign s1_temp3[7] = (s1_temp2[3] < s1_temp2[7]) ? s1_temp2[7] : s1_temp2[3];

  // Pass 4
  assign s1_temp4[0] = (s1_temp3[0] < s1_temp3[1]) ? s1_temp3[0] : s1_temp3[1];
  assign s1_temp4[1] = (s1_temp3[0] < s1_temp3[1]) ? s1_temp3[1] : s1_temp3[0];
  assign s1_temp4[2] = (s1_temp3[2] < s1_temp3[3]) ? s1_temp3[2] : s1_temp3[3];
  assign s1_temp4[3] = (s1_temp3[2] < s1_temp3[3]) ? s1_temp3[3] : s1_temp3[2];
  assign s1_temp4[4] = (s1_temp3[4] < s1_temp3[5]) ? s1_temp3[4] : s1_temp3[5];
  assign s1_temp4[5] = (s1_temp3[4] < s1_temp3[5]) ? s1_temp3[5] : s1_temp3[4];
  assign s1_temp4[6] = (s1_temp3[6] < s1_temp3[7]) ? s1_temp3[6] : s1_temp3[7];
  assign s1_temp4[7] = (s1_temp3[6] < s1_temp3[7]) ? s1_temp3[7] : s1_temp3[6];

  // Pass 5
  assign s1_temp5[0] = (s1_temp4[0] < s1_temp4[2]) ? s1_temp4[0] : s1_temp4[2];
  assign s1_temp5[1] = (s1_temp4[1] < s1_temp4[3]) ? s1_temp4[1] : s1_temp4[3];
  assign s1_temp5[2] = (s1_temp4[0] < s1_temp4[2]) ? s1_temp4[2] : s1_temp4[0];
  assign s1_temp5[3] = (s1_temp4[1] < s1_temp4[3]) ? s1_temp4[3] : s1_temp4[1];
  assign s1_temp5[4] = (s1_temp4[4] < s1_temp4[6]) ? s1_temp4[4] : s1_temp4[6];
  assign s1_temp5[5] = (s1_temp4[5] < s1_temp4[7]) ? s1_temp4[5] : s1_temp4[7];
  assign s1_temp5[6] = (s1_temp4[4] < s1_temp4[6]) ? s1_temp4[6] : s1_temp4[4];
  assign s1_temp5[7] = (s1_temp4[5] < s1_temp4[7]) ? s1_temp4[7] : s1_temp4[5];

  // Pass 6
  assign s1_temp6[0] = (s1_temp5[0] < s1_temp5[4]) ? s1_temp5[0] : s1_temp5[4];
  assign s1_temp6[1] = (s1_temp5[1] < s1_temp5[5]) ? s1_temp5[1] : s1_temp5[5];
  assign s1_temp6[2] = (s1_temp5[2] < s1_temp5[6]) ? s1_temp5[2] : s1_temp5[6];
  assign s1_temp6[3] = (s1_temp5[3] < s1_temp5[7]) ? s1_temp5[3] : s1_temp5[7];
  assign s1_temp6[4] = (s1_temp5[0] < s1_temp5[4]) ? s1_temp5[4] : s1_temp5[0];
  assign s1_temp6[5] = (s1_temp5[1] < s1_temp5[5]) ? s1_temp5[5] : s1_temp5[1];
  assign s1_temp6[6] = (s1_temp5[2] < s1_temp5[6]) ? s1_temp5[6] : s1_temp5[2];
  assign s1_temp6[7] = (s1_temp5[3] < s1_temp5[7]) ? s1_temp5[7] : s1_temp5[3];

  // Final pass
  assign s1_sorted[0] = (s1_temp6[0] < s1_temp6[1]) ? s1_temp6[0] : s1_temp6[1];
  assign s1_sorted[1] = (s1_temp6[0] < s1_temp6[1]) ? s1_temp6[1] : s1_temp6[0];
  assign s1_sorted[2] = (s1_temp6[2] < s1_temp6[3]) ? s1_temp6[2] : s1_temp6[3];
  assign s1_sorted[3] = (s1_temp6[2] < s1_temp6[3]) ? s1_temp6[3] : s1_temp6[2];
  assign s1_sorted[4] = (s1_temp6[4] < s1_temp6[5]) ? s1_temp6[4] : s1_temp6[5];
  assign s1_sorted[5] = (s1_temp6[4] < s1_temp6[5]) ? s1_temp6[5] : s1_temp6[4];
  assign s1_sorted[6] = (s1_temp6[6] < s1_temp6[7]) ? s1_temp6[6] : s1_temp6[7];
  assign s1_sorted[7] = (s1_temp6[6] < s1_temp6[7]) ? s1_temp6[7] : s1_temp6[6];

  // Compare sorted arrays
  assign result = (s0_sorted[0] == s1_sorted[0]) &&
                 (s0_sorted[1] == s1_sorted[1]) &&
                 (s0_sorted[2] == s1_sorted[2]) &&
                 (s0_sorted[3] == s1_sorted[3]) &&
                 (s0_sorted[4] == s1_sorted[4]) &&
                 (s0_sorted[5] == s1_sorted[5]) &&
                 (s0_sorted[6] == s1_sorted[6]) &&
                 (s0_sorted[7] == s1_sorted[7]);

endmodule