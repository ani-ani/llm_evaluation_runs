module battery_allocation(
  input [63:0] batteries_packed,
  output [7:0] d
);

  // Unpack input
  wire [7:0] s0 [0:7];
  assign s0[0] = batteries_packed[63:56];
  assign s0[1] = batteries_packed[55:48];
  assign s0[2] = batteries_packed[47:40];
  assign s0[3] = batteries_packed[39:32];
  assign s0[4] = batteries_packed[31:24];
  assign s0[5] = batteries_packed[23:16];
  assign s0[6] = batteries_packed[15:8];
  assign s0[7] = batteries_packed[7:0];

  // Stage 1
  wire [7:0] s1 [0:7];
  assign {s1[0], s1[1]} = (s0[0] <= s0[1]) ? {s0[0], s0[1]} : {s0[1], s0[0]};
  assign {s1[2], s1[3]} = (s0[2] <= s0[3]) ? {s0[2], s0[3]} : {s0[3], s0[2]};
  assign {s1[4], s1[5]} = (s0[4] <= s0[5]) ? {s0[4], s0[5]} : {s0[5], s0[4]};
  assign {s1[6], s1[7]} = (s0[6] <= s0[7]) ? {s0[6], s0[7]} : {s0[7], s0[6]};

  // Stage 2
  wire [7:0] s2 [0:7];
  assign {s2[0], s2[2]} = (s1[0] <= s1[2]) ? {s1[0], s1[2]} : {s1[2], s1[0]};
  assign {s2[1], s2[3]} = (s1[1] <= s1[3]) ? {s1[1], s1[3]} : {s1[3], s1[1]};
  assign {s2[4], s2[6]} = (s1[4] <= s1[6]) ? {s1[4], s1[6]} : {s1[6], s1[4]};
  assign {s2[5], s2[7]} = (s1[5] <= s1[7]) ? {s1[5], s1[7]} : {s1[7], s1[5]};

  // Stage 3
  wire [7:0] s3 [0:7];
  assign {s3[1], s3[2]} = (s2[1] <= s2[2]) ? {s2[1], s2[2]} : {s2[2], s2[1]};
  assign {s3[5], s3[6]} = (s2[5] <= s2[6]) ? {s2[5], s2[6]} : {s2[6], s2[5]};
  assign {s3[0], s3[4]} = (s2[0] <= s2[4]) ? {s2[0], s2[4]} : {s2[4], s2[0]};
  assign {s3[3], s3[7]} = (s2[3] <= s2[7]) ? {s2[3], s2[7]} : {s2[7], s2[3]};

  // Stage 4
  wire [7:0] s4 [0:7];
  assign {s4[1], s4[5]} = (s3[1] <= s3[5]) ? {s3[1], s3[5]} : {s3[5], s3[1]};
  assign {s4[2], s4[6]} = (s3[2] <= s3[6]) ? {s3[2], s3[6]} : {s3[6], s3[2]};
  assign s4[0] = s3[0];
  assign s4[3] = s3[3];
  assign s4[4] = s3[4];
  assign s4[7] = s3[7];

  // Stage 5
  wire [7:0] s5 [0:7];
  assign {s5[1], s5[4]} = (s4[1] <= s4[4]) ? {s4[1], s4[4]} : {s4[4], s4[1]};
  assign {s5[3], s5[6]} = (s4[3] <= s4[6]) ? {s4[3], s4[6]} : {s4[6], s4[3]};
  assign s5[0] = s4[0];
  assign s5[2] = s4[2];
  assign s5[5] = s4[5];
  assign s5[7] = s4[7];

  // Stage 6
  wire [7:0] s6 [0:7];
  assign {s6[2], s6[4]} = (s5[2] <= s5[4]) ? {s5[2], s5[4]} : {s5[4], s5[2]};
  assign {s6[3], s6[5]} = (s5[3] <= s5[5]) ? {s5[3], s5[5]} : {s5[5], s5[3]};
  assign s6[0] = s5[0];
  assign s6[1] = s5[1];
  assign s6[7] = s5[7];

  // Stage 7
  wire [7:0] s7 [0:7];
  assign {s7[3], s7[4]} = (s6[3] <= s6[4]) ? {s6[3], s6[4]} : {s6[4], s6[3]};
  assign s7[0] = s6[0];
  assign s7[1] = s6[1];
  assign s7[2] = s6[2];
  assign s7[5] = s6[5];
  assign s7[6] = s6[6];
  assign s7[7] = s6[7];

  // Calculate pair differences
  wire [7:0] diff0 = s7[1] - s7[0];
  wire [7:0] diff1 = s7[3] - s7[2];
  wire [7:0] diff2 = s7[5] - s7[4];
  wire [7:0] diff3 = s7[7] - s7[6];

  // Find maximum difference
  wire [7:0] max01 = (diff0 > diff1) ? diff0 : diff1;
  wire [7:0] max23 = (diff2 > diff3) ? diff2 : diff3;
  assign d = (max01 > max23) ? max01 : max23;

endmodule