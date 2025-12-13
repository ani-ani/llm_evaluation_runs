module sort_third(
  input  [95:0] arr_in,
  output [95:0] arr_out
);

  // Extract 12 signed 8-bit elements (index 0 = MSB segment [95:88])
  wire signed [7:0] e0 = arr_in[95:88];
  wire signed [7:0] e1 = arr_in[87:80];
  wire signed [7:0] e2 = arr_in[79:72];
  wire signed [7:0] e3 = arr_in[71:64];
  wire signed [7:0] e4 = arr_in[63:56];
  wire signed [7:0] e5 = arr_in[55:48];
  wire signed [7:0] e6 = arr_in[47:40];
  wire signed [7:0] e7 = arr_in[39:32];
  wire signed [7:0] e8 = arr_in[31:24];
  wire signed [7:0] e9 = arr_in[23:16];
  wire signed [7:0] e10 = arr_in[15:8];
  wire signed [7:0] e11 = arr_in[7:0];

  // Sorting network for indices 0,3,6,9
  wire signed [7:0] a0 = e0;
  wire signed [7:0] a1 = e3;
  wire signed [7:0] a2 = e6;
  wire signed [7:0] a3 = e9;

  // Stage 1
  wire signed [7:0] s1_0_min = (a0 <= a1) ? a0 : a1;
  wire signed [7:0] s1_0_max = (a0 <= a1) ? a1 : a0;
  wire signed [7:0] s1_1_min = (a2 <= a3) ? a2 : a3;
  wire signed [7:0] s1_1_max = (a2 <= a3) ? a3 : a2;

  // Stage 2
  wire signed [7:0] s2_0_min = (s1_0_min <= s1_1_min) ? s1_0_min : s1_1_min;
  wire signed [7:0] s2_1_max = (s1_0_max <= s1_1_max) ? s1_1_max : s1_0_max;

  // Stage 3
  wire signed [7:0] s3_mid0_min = (s1_0_max <= s1_1_min) ? s1_0_max : s1_1_min;
  wire signed [7:0] s3_mid1_max = (s1_0_max <= s1_1_min) ? s1_1_min : s1_0_max;

  // Final sorted elements
  wire signed [7:0] o0 = s2_0_min;
  wire signed [7:0] o1 = (s3_mid0_min <= s3_mid1_max) ? s3_mid0_min : s3_mid1_max;
  wire signed [7:0] o2 = (s3_mid0_min <= s3_mid1_max) ? s3_mid1_max : s3_mid0_min;
  wire signed [7:0] o3 = s2_1_max;

  // Reconstruct output array
  assign arr_out = {
    o0,        // index 0 (sorted)
    e1,        // index 1
    e2,        // index 2
    o1,        // index 3 (sorted)
    e4,        // index 4
    e5,        // index 5
    o2,        // index 6 (sorted)
    e7,        // index 7
    e8,        // index 8
    o3,        // index 9 (sorted)
    e10,       // index 10
    e11        // index 11
  };

endmodule