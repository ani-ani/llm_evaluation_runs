module battery_allocation(
  input  [63:0] batteries_packed, // 8 batteries × 8 bits: [63:56]=bat0, [55:48]=bat1, ...[7:0]=bat7
  output [7:0]  d                 // Maximum difference between paired chips
);

  // Unpack batteries
  wire [7:0] b0 = batteries_packed[63:56];
  wire [7:0] b1 = batteries_packed[55:48];
  wire [7:0] b2 = batteries_packed[47:40];
  wire [7:0] b3 = batteries_packed[39:32];
  wire [7:0] b4 = batteries_packed[31:24];
  wire [7:0] b5 = batteries_packed[23:16];
  wire [7:0] b6 = batteries_packed[15:8];
  wire [7:0] b7 = batteries_packed[7:0];

  // Compare-and-swap (power-optimized: shared logic via ternary operators)
  function automatic [15:0] cas(input [7:0] x, input [7:0] y);
    begin
      cas = (x <= y) ? {x, y} : {y, x};
    end
  endfunction

  // Stage 1
  wire [15:0] s0_01 = cas(b0, b1);
  wire [7:0]  s0_0  = s0_01[15:8];
  wire [7:0]  s0_1  = s0_01[7:0];

  wire [15:0] s0_23 = cas(b2, b3);
  wire [7:0]  s0_2  = s0_23[15:8];
  wire [7:0]  s0_3  = s0_23[7:0];

  wire [15:0] s0_45 = cas(b4, b5);
  wire [7:0]  s0_4  = s0_45[15:8];
  wire [7:0]  s0_5  = s0_45[7:0];

  wire [15:0] s0_67 = cas(b6, b7);
  wire [7:0]  s0_6  = s0_67[15:8];
  wire [7:0]  s0_7  = s0_67[7:0];

  // Stage 2
  wire [15:0] s1_02 = cas(s0_0, s0_2);
  wire [7:0]  s1_0  = s1_02[15:8];
  wire [7:0]  s1_2  = s1_02[7:0];

  wire [15:0] s1_13 = cas(s0_1, s0_3);
  wire [7:0]  s1_1  = s1_13[15:8];
  wire [7:0]  s1_3  = s1_13[7:0];

  wire [15:0] s1_46 = cas(s0_4, s0_6);
  wire [7:0]  s1_4  = s1_46[15:8];
  wire [7:0]  s1_6  = s1_46[7:0];

  wire [15:0] s1_57 = cas(s0_5, s0_7);
  wire [7:0]  s1_5  = s1_57[15:8];
  wire [7:0]  s1_7  = s1_57[7:0];

  // Stage 3
  wire [15:0] s2_01 = cas(s1_0, s1_1);
  wire [7:0]  s2_0  = s2_01[15:8];
  wire [7:0]  s2_1  = s2_01[7:0];

  wire [15:0] s2_23 = cas(s1_2, s1_3);
  wire [7:0]  s2_2  = s2_23[15:8];
  wire [7:0]  s2_3  = s2_23[7:0];

  wire [15:0] s2_45 = cas(s1_4, s1_5);
  wire [7:0]  s2_4  = s2_45[15:8];
  wire [7:0]  s2_5  = s2_45[7:0];

  wire [15:0] s2_67 = cas(s1_6, s1_7);
  wire [7:0]  s2_6  = s2_67[15:8];
  wire [7:0]  s2_7  = s2_67[7:0];

  // Stage 4
  wire [15:0] s3_04 = cas(s2_0, s2_4);
  wire [7:0]  s3_0  = s3_04[15:8];
  wire [7:0]  s3_4  = s3_04[7:0];

  wire [15:0] s3_15 = cas(s2_1, s2_5);
  wire [7:0]  s3_1  = s3_15[15:8];
  wire [7:0]  s3_5  = s3_15[7:0];

  wire [15:0] s3_26 = cas(s2_2, s2_6);
  wire [7:0]  s3_2  = s3_26[15:8];
  wire [7:0]  s3_6  = s3_26[7:0];

  wire [15:0] s3_37 = cas(s2_3, s2_7);
  wire [7:0]  s3_3  = s3_37[15:8];
  wire [7:0]  s3_7  = s3_37[7:0];

  // Stage 5
  wire [15:0] s4_23 = cas(s3_2, s3_3);
  wire [7:0]  s4_2  = s4_23[15:8];
  wire [7:0]  s4_3  = s4_23[7:0];

  wire [15:0] s4_45 = cas(s3_4, s3_5);
  wire [7:0]  s4_4  = s4_45[15:8];
  wire [7:0]  s4_5  = s4_45[7:0];

  // Stage 6
  wire [15:0] s5_12 = cas(s3_1, s4_2);
  wire [7:0]  s5_1  = s5_12[15:8];
  wire [7:0]  s5_2  = s5_12[7:0];

  wire [15:0] s5_34 = cas(s4_3, s4_4);
  wire [7:0]  s5_3  = s5_34[15:8];
  wire [7:0]  s5_4  = s5_34[7:0];

  wire [15:0] s5_56 = cas(s4_5, s3_6);
  wire [7:0]  s5_5  = s5_56[15:8];
  wire [7:0]  s5_6  = s5_56[7:0];

  // Final sorted outputs
  wire [7:0] sorted0 = s3_0;
  wire [7:0] sorted1 = s5_1;
  wire [7:0] sorted2 = s5_2;
  wire [7:0] sorted3 = s5_3;
  wire [7:0] sorted4 = s5_4;
  wire [7:0] sorted5 = s5_5;
  wire [7:0] sorted6 = s5_6;
  wire [7:0] sorted7 = s3_7;

  // Pair differences (absolute value via max-min to minimize switching hazards)
  wire [7:0] max01 = (sorted0 >= sorted1) ? sorted0 : sorted1;
  wire [7:0] min01 = (sorted0 >= sorted1) ? sorted1 : sorted0;
  wire [7:0] diff0 = max01 - min01;

  wire [7:0] max23 = (sorted2 >= sorted3) ? sorted2 : sorted3;
  wire [7:0] min23 = (sorted2 >= sorted3) ? sorted3 : sorted2;
  wire [7:0] diff1 = max23 - min23;

  wire [7:0] max45 = (sorted4 >= sorted5) ? sorted4 : sorted5;
  wire [7:0] min45 = (sorted4 >= sorted5) ? sorted5 : sorted4;
  wire [7:0] diff2 = max45 - min45;

  wire [7:0] max67 = (sorted6 >= sorted7) ? sorted6 : sorted7;
  wire [7:0] min67 = (sorted6 >= sorted7) ? sorted7 : sorted6;
  wire [7:0] diff3 = max67 - min67;

  // Maximum of pair differences
  wire [7:0] max_d0 = (diff0 >= diff1) ? diff0 : diff1;
  wire [7:0] max_d1 = (diff2 >= diff3) ? diff2 : diff3;
  wire [7:0] max_d  = (max_d0 >= max_d1) ? max_d0 : max_d1;

  assign d = max_d;

endmodule