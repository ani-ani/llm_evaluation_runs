module max_game_score (
  input [3:0] n,
  input [15:0] arr [0:7],
  output reg [31:0] score
);
  // Internal wires
  wire [15:0] sorted [0:7];
  wire [15:0] stage0 [0:7];
  wire [15:0] stage1 [0:7];
  wire [15:0] stage2 [0:7];
  wire [15:0] stage3 [0:7];
  wire [15:0] stage4 [0:7];
  wire [15:0] stage5 [0:7];
  wire [15:0] stage6 [0:7];

  // Pad the array so that elements beyond 'n' do not affect sorting
  // (they become large, so they sort to the end)
  assign stage0[0] = (n >= 4'd1) ? arr[0] : 16'hFFFF;
  assign stage0[1] = (n >= 4'd2) ? arr[1] : 16'hFFFF;
  assign stage0[2] = (n >= 4'd3) ? arr[2] : 16'hFFFF;
  assign stage0[3] = (n >= 4'd4) ? arr[3] : 16'hFFFF;
  assign stage0[4] = (n >= 4'd5) ? arr[4] : 16'hFFFF;
  assign stage0[5] = (n >= 4'd6) ? arr[5] : 16'hFFFF;
  assign stage0[6] = (n >= 4'd7) ? arr[6] : 16'hFFFF;
  assign stage0[7] = (n >= 4'd8) ? arr[7] : 16'hFFFF;

  // Sorting network (bitonic odd-even mergesort for 8 inputs)
  // Level 0: sort pairs 0..7
  compare_and_swap u0_0 (.a(stage0[0]), .b(stage0[1]), .lo(stage1[0]), .hi(stage1[1]));
  compare_and_swap u0_1 (.a(stage0[2]), .b(stage0[3]), .lo(stage1[2]), .hi(stage1[3]));
  compare_and_swap u0_2 (.a(stage0[4]), .b(stage0[5]), .lo(stage1[4]), .hi(stage1[5]));
  compare_and_swap u0_3 (.a(stage0[6]), .b(stage0[7]), .lo(stage1[6]), .hi(stage1[7]));

  // Level 1: sort pairs (0,2),(1,3) and (4,6),(5,7)
  compare_and_swap u1_0 (.a(stage1[0]), .b(stage1[2]), .lo(stage2[0]), .hi(stage2[2]));
  compare_and_swap u1_1 (.a(stage1[1]), .b(stage1[3]), .lo(stage2[1]), .hi(stage2[3]));
  compare_and_swap u1_2 (.a(stage1[4]), .b(stage1[6]), .lo(stage2[4]), .hi(stage2[6]));
  compare_and_swap u1_3 (.a(stage1[5]), .b(stage1[7]), .lo(stage2[5]), .hi(stage2[7]));

  // Level 2: sort pairs (0,4),(1,5),(2,6),(3,7)
  compare_and_swap u2_0 (.a(stage2[0]), .b(stage2[4]), .lo(stage3[0]), .hi(stage3[4]));
  compare_and_swap u2_1 (.a(stage2[1]), .b(stage2[5]), .lo(stage3[1]), .hi(stage3[5]));
  compare_and_swap u2_2 (.a(stage2[2]), .b(stage2[6]), .lo(stage3[2]), .hi(stage3[6]));
  compare_and_swap u2_3 (.a(stage2[3]), .b(stage2[7]), .lo(stage3[3]), .hi(stage3[7]));

  // Merge the two 4-element bitonic sequences
  // Level 3: even-odd merge of first 4
  compare_and_swap m3_0 (.a(stage3[0]), .b(stage3[1]), .lo(stage4[0]), .hi(stage4[1]));
  compare_and_swap m3_1 (.a(stage3[2]), .b(stage3[3]), .lo(stage4[2]), .hi(stage4[3]));

  // Level 3: even-odd merge of last 4
  compare_and_swap m3_2 (.a(stage3[4]), .b(stage3[5]), .lo(stage4[4]), .hi(stage4[5]));
  compare_and_swap m3_3 (.a(stage3[6]), .b(stage3[7]), .lo(stage4[6]), .hi(stage4[7]));

  // Merge the two 4-element halves into a single 8-element sorted sequence
  // Level 4: even-odd merge across halves (distance = 4)
  compare_and_swap m4_0 (.a(stage4[0]), .b(stage4[4]), .lo(stage5[0]), .hi(stage5[4]));
  compare_and_swap m4_1 (.a(stage4[1]), .b(stage4[5]), .lo(stage5[1]), .hi(stage5[5]));
  compare_and_swap m4_2 (.a(stage4[2]), .b(stage4[6]), .lo(stage5[2]), .hi(stage5[6]));
  compare_and_swap m4_3 (.a(stage4[3]), .b(stage4[7]), .lo(stage5[3]), .hi(stage5[7]));

  // Level 5: continue merge (distance = 2)
  compare_and_swap m5_0 (.a(stage5[0]), .b(stage5[2]), .lo(stage6[0]), .hi(stage6[2]));
  compare_and_swap m5_1 (.a(stage5[1]), .b(stage5[3]), .lo(stage6[1]), .hi(stage6[3]));
  compare_and_swap m5_2 (.a(stage5[4]), .b(stage5[6]), .lo(stage6[4]), .hi(stage6[6]));
  compare_and_swap m5_3 (.a(stage5[5]), .b(stage5[7]), .lo(stage6[5]), .hi(stage6[7]));

  // Level 6: final merge (distance = 1)
  compare_and_swap m6_0 (.a(stage6[0]), .b(stage6[1]), .lo(sorted[0]), .hi(sorted[1]));
  compare_and_swap m6_1 (.a(stage6[2]), .b(stage6[3]), .lo(sorted[2]), .hi(sorted[3]));
  compare_and_swap m6_2 (.a(stage6[4]), .b(stage6[5]), .lo(sorted[4]), .hi(sorted[5]));
  compare_and_swap m6_3 (.a(stage6[6]), .b(stage6[7]), .lo(sorted[6]), .hi(sorted[7]));

  // Compute score from the sorted first n elements.
  // Weights: for i=0..n-2 weight = i+2; for i=n-1 weight = n (or 1 if n==1)
  // This matches the provided description exactly.
  always @(*) begin
    if (n == 4'd0) begin
      score = 32'd0;
    end else begin
      score = $unsigned(sorted[0]) * ((n > 4'd1) ? 32'd2 : 32'd1);
      if (n > 4'd1) score = score + $unsigned(sorted[1]) * 32'd3;
      if (n > 4'd2) score = score + $unsigned(sorted[2]) * 32'd4;
      if (n > 4'd3) score = score + $unsigned(sorted[3]) * 32'd5;
      if (n > 4'd4) score = score + $unsigned(sorted[4]) * 32'd6;
      if (n > 4'd5) score = score + $unsigned(sorted[5]) * 32'd7;
      if (n > 4'd6) score = score + $unsigned(sorted[6]) * 32'd8;
      if (n > 4'd7) score = score + $unsigned(sorted[7]) * 32'd8;
    end
  end

endmodule

// 2-input sorting primitive
module compare_and_swap (
  input  [15:0] a,
  input  [15:0] b,
  output [15:0] lo,
  output [15:0] hi
);
  assign lo = (a <= b) ? a : b;
  assign hi = (a <= b) ? b : a;
endmodule