module largest_number_formed (
  input [7:0] digit_0,
  input [7:0] digit_1,
  input [7:0] digit_2,
  input [7:0] digit_3,
  input [7:0] digit_4,
  input [7:0] digit_5,
  input [7:0] digit_6,
  input [7:0] digit_7,
  output [31:0] result
);

  // Sorting network for 8 digits (bubble-sort style)
  wire [7:0] sorted [0:7];

  // Initial assignments
  assign sorted[0] = digit_0;
  assign sorted[1] = digit_1;
  assign sorted[2] = digit_2;
  assign sorted[3] = digit_3;
  assign sorted[4] = digit_4;
  assign sorted[5] = digit_5;
  assign sorted[6] = digit_6;
  assign sorted[7] = digit_7;

  // Sorting stages (comparators)
  // Stage 1
  assign sorted[0] = (digit_0 > digit_1) ? digit_0 : digit_1;
  assign sorted[1] = (digit_0 > digit_1) ? digit_1 : digit_0;
  assign sorted[2] = (digit_2 > digit_3) ? digit_2 : digit_3;
  assign sorted[3] = (digit_2 > digit_3) ? digit_3 : digit_2;
  assign sorted[4] = (digit_4 > digit_5) ? digit_4 : digit_5;
  assign sorted[5] = (digit_4 > digit_5) ? digit_5 : digit_4;
  assign sorted[6] = (digit_6 > digit_7) ? digit_6 : digit_7;
  assign sorted[7] = (digit_6 > digit_7) ? digit_7 : digit_6;

  // Stage 2
  assign sorted[0] = (sorted[0] > sorted[2]) ? sorted[0] : sorted[2];
  assign sorted[2] = (sorted[0] > sorted[2]) ? sorted[2] : sorted[0];
  assign sorted[1] = (sorted[1] > sorted[3]) ? sorted[1] : sorted[3];
  assign sorted[3] = (sorted[1] > sorted[3]) ? sorted[3] : sorted[1];
  assign sorted[4] = (sorted[4] > sorted[6]) ? sorted[4] : sorted[6];
  assign sorted[6] = (sorted[4] > sorted[6]) ? sorted[6] : sorted[4];
  assign sorted[5] = (sorted[5] > sorted[7]) ? sorted[5] : sorted[7];
  assign sorted[7] = (sorted[5] > sorted[7]) ? sorted[7] : sorted[5];

  // Stage 3
  assign sorted[0] = (sorted[0] > sorted[4]) ? sorted[0] : sorted[4];
  assign sorted[4] = (sorted[0] > sorted[4]) ? sorted[4] : sorted[0];
  assign sorted[1] = (sorted[1] > sorted[5]) ? sorted[1] : sorted[5];
  assign sorted[5] = (sorted[1] > sorted[5]) ? sorted[5] : sorted[1];
  assign sorted[2] = (sorted[2] > sorted[6]) ? sorted[2] : sorted[6];
  assign sorted[6] = (sorted[2] > sorted[6]) ? sorted[6] : sorted[2];
  assign sorted[3] = (sorted[3] > sorted[7]) ? sorted[3] : sorted[7];
  assign sorted[7] = (sorted[3] > sorted[7]) ? sorted[7] : sorted[3];

  // Stage 4
  assign sorted[1] = (sorted[1] > sorted[2]) ? sorted[1] : sorted[2];
  assign sorted[2] = (sorted[1] > sorted[2]) ? sorted[2] : sorted[1];
  assign sorted[5] = (sorted[5] > sorted[6]) ? sorted[5] : sorted[6];
  assign sorted[6] = (sorted[5] > sorted[6]) ? sorted[6] : sorted[5];

  // Stage 5
  assign sorted[0] = (sorted[0] > sorted[1]) ? sorted[0] : sorted[1];
  assign sorted[1] = (sorted[0] > sorted[1]) ? sorted[1] : sorted[0];
  assign sorted[2] = (sorted[2] > sorted[3]) ? sorted[2] : sorted[3];
  assign sorted[3] = (sorted[2] > sorted[3]) ? sorted[3] : sorted[2];
  assign sorted[4] = (sorted[4] > sorted[5]) ? sorted[4] : sorted[5];
  assign sorted[5] = (sorted[4] > sorted[5]) ? sorted[5] : sorted[4];
  assign sorted[6] = (sorted[6] > sorted[7]) ? sorted[6] : sorted[7];
  assign sorted[7] = (sorted[6] > sorted[7]) ? sorted[7] : sorted[6];

  // Combine sorted digits into result
  assign result = (sorted[0] << 24) | (sorted[1] << 16) | (sorted[2] << 8) | sorted[3];

endmodule