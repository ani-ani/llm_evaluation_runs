module battery_allocation(
  input [63:0] batteries_packed,
  output reg [7:0] d
);

  // Unpack batteries
  wire [7:0] b0, b1, b2, b3, b4, b5, b6, b7;
  assign b0 = batteries_packed[63:56];
  assign b1 = batteries_packed[55:48];
  assign b2 = batteries_packed[47:40];
  assign b3 = batteries_packed[39:32];
  assign b4 = batteries_packed[31:24];
  assign b5 = batteries_packed[23:16];
  assign b6 = batteries_packed[15:8];
  assign b7 = batteries_packed[7:0];

  // Sorting network wires
  wire [7:0] stage0_0, stage0_1, stage0_2, stage0_3, stage0_4, stage0_5, stage0_6, stage0_7;
  wire [7:0] stage1_0, stage1_1, stage1_2, stage1_3, stage1_4, stage1_5, stage1_6, stage1_7;
  wire [7:0] stage2_0, stage2_1, stage2_2, stage2_3, stage2_4, stage2_5, stage2_6, stage2_7;
  wire [7:0] stage3_0, stage3_1, stage3_2, stage3_3, stage3_4, stage3_5, stage3_6, stage3_7;
  wire [7:0] stage4_0, stage4_1, stage4_2, stage4_3, stage4_4, stage4_5, stage4_6, stage4_7;
  wire [7:0] stage5_0, stage5_1, stage5_2, stage5_3, stage5_4, stage5_5, stage5_6, stage5_7;

  // Stage 0: (0,1), (2,3), (4,5), (6,7)
  assign {stage0_0, stage0_1} = (b0 < b1) ? {b0, b1} : {b1, b0};
  assign {stage0_2, stage0_3} = (b2 < b3) ? {b2, b3} : {b3, b2};
  assign {stage0_4, stage0_5} = (b4 < b5) ? {b4, b5} : {b5, b4};
  assign {stage0_6, stage0_7} = (b6 < b7) ? {b6, b7} : {b7, b6};

  // Stage 1: (0,2), (1,3), (4,6), (5,7)
  assign {stage1_0, stage1_2} = (stage0_0 < stage0_2) ? {stage0_0, stage0_2} : {stage0_2, stage0_0};
  assign {stage1_1, stage1_3} = (stage0_1 < stage0_3) ? {stage0_1, stage0_3} : {stage0_3, stage0_1};
  assign {stage1_4, stage1_6} = (stage0_4 < stage0_6) ? {stage0_4, stage0_6} : {stage0_6, stage0_4};
  assign {stage1_5, stage1_7} = (stage0_5 < stage0_7) ? {stage0_5, stage0_7} : {stage0_7, stage0_5};

  // Stage 2: (0,4), (1,5), (2,6), (3,7)
  assign {stage2_0, stage2_4} = (stage1_0 < stage1_4) ? {stage1_0, stage1_4} : {stage1_4, stage1_0};
  assign {stage2_1, stage2_5} = (stage1_1 < stage1_5) ? {stage1_1, stage1_5} : {stage1_5, stage1_1};
  assign {stage2_2, stage2_6} = (stage1_2 < stage1_6) ? {stage1_2, stage1_6} : {stage1_6, stage1_2};
  assign {stage2_3, stage2_7} = (stage1_3 < stage1_7) ? {stage1_3, stage1_7} : {stage1_7, stage1_3};

  // Stage 3: (0,1), (2,3), (4,5), (6,7)
  assign {stage3_0, stage3_1} = (stage2_0 < stage2_1) ? {stage2_0, stage2_1} : {stage2_1, stage2_0};
  assign {stage3_2, stage3_3} = (stage2_2 < stage2_3) ? {stage2_2, stage2_3} : {stage2_3, stage2_2};
  assign {stage3_4, stage3_5} = (stage2_4 < stage2_5) ? {stage2_4, stage2_5} : {stage2_5, stage2_4};
  assign {stage3_6, stage3_7} = (stage2_6 < stage2_7) ? {stage2_6, stage2_7} : {stage2_7, stage2_6};

  // Stage 4: (0,2), (1,3), (4,6), (5,7)
  assign {stage4_0, stage4_2} = (stage3_0 < stage3_2) ? {stage3_0, stage3_2} : {stage3_2, stage3_0};
  assign {stage4_1, stage4_3} = (stage3_1 < stage3_3) ? {stage3_1, stage3_3} : {stage3_3, stage3_1};
  assign {stage4_4, stage4_6} = (stage3_4 < stage3_6) ? {stage3_4, stage3_6} : {stage3_6, stage3_4};
  assign {stage4_5, stage4_7} = (stage3_5 < stage3_7) ? {stage3_5, stage3_7} : {stage3_7, stage3_5};

  // Stage 5: (0,1), (2,3), (4,5), (6,7)
  assign {stage5_0, stage5_1} = (stage4_0 < stage4_1) ? {stage4_0, stage4_1} : {stage4_1, stage4_0};
  assign {stage5_2, stage5_3} = (stage4_2 < stage4_3) ? {stage4_2, stage4_3} : {stage4_3, stage4_2};
  assign {stage5_4, stage5_5} = (stage4_4 < stage4_5) ? {stage4_4, stage4_5} : {stage4_5, stage4_4};
  assign {stage5_6, stage5_7} = (stage4_6 < stage4_7) ? {stage4_6, stage4_7} : {stage4_7, stage4_6};

  // Compute differences and maximum
  wire [7:0] diff0, diff1, diff2, diff3, max01, max23;
  assign diff0 = stage5_1 - stage5_0;  // First pair
  assign diff1 = stage5_3 - stage5_2;  // Second pair
  assign diff2 = stage5_5 - stage5_4;  // Third pair
  assign diff3 = stage5_7 - stage5_6;  // Fourth pair

  assign max01 = (diff0 > diff1) ? diff0 : diff1;
  assign max23 = (diff2 > diff3) ? diff2 : diff3;

  always @(*) begin
    d = (max01 > max23) ? max01 : max23;
  end

endmodule