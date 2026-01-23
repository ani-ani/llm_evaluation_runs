module sort_array(
    input [7:0] in_0, in_1, in_2, in_3, in_4, in_5, in_6, in_7,
    output [7:0] out_0, out_1, out_2, out_3, out_4, out_5, out_6, out_7
);

    // Internal wires for the sorting network stages
    wire [7:0] s0_0, s0_1, s0_2, s0_3, s0_4, s0_5, s0_6, s0_7;
    wire [7:0] s1_0, s1_1, s1_2, s1_3, s1_4, s1_5, s1_6, s1_7;
    wire [7:0] s2_0, s2_1, s2_2, s2_3, s2_4, s2_5, s2_6, s2_7;
    wire [7:0] s3_0, s3_1, s3_2, s3_3, s3_4, s3_5, s3_6, s3_7;
    wire [7:0] s4_0, s4_1, s4_2, s4_3, s4_4, s4_5, s4_6, s4_7;
    wire [7:0] s5_0, s5_1, s5_2, s5_3, s5_4, s5_5, s5_6, s5_7;
    wire [7:0] s6_0, s6_1, s6_2, s6_3, s6_4, s6_5, s6_6, s6_7;
    wire [7:0] s7_0, s7_1, s7_2, s7_3, s7_4, s7_5, s7_6, s7_7;
    wire [7:0] s8_0, s8_1, s8_2, s8_3, s8_4, s8_5, s8_6, s8_7;
    wire [7:0] s9_0, s9_1, s9_2, s9_3, s9_4, s9_5, s9_6, s9_7;
    wire [7:0] s10_0, s10_1, s10_2, s10_3, s10_4, s10_5, s10_6, s10_7;
    wire [7:0] s11_0, s11_1, s11_2, s11_3, s11_4, s11_5, s11_6, s11_7;
    wire [7:0] s12_0, s12_1, s12_2, s12_3, s12_4, s12_5, s12_6, s12_7;
    wire [7:0] s13_0, s13_1, s13_2, s13_3, s13_4, s13_5, s13_6, s13_7;
    wire [7:0] s14_0, s14_1, s14_2, s14_3, s14_4, s14_5, s14_6, s14_7;
    wire [7:0] s15_0, s15_1, s15_2, s15_3, s15_4, s15_5, s15_6, s15_7;
    wire [7:0] s16_0, s16_1, s16_2, s16_3, s16_4, s16_5, s16_6, s16_7;
    wire [7:0] s17_0, s17_1, s17_2, s17_3, s17_4, s17_5, s17_6, s17_7;
    wire [7:0] s18_0, s18_1, s18_2, s18_3, s18_4, s18_5, s18_6, s18_7;
    wire [7:0] s19_0, s19_1, s19_2, s19_3, s19_4, s19_5, s19_6, s19_7;
    wire [7:0] s20_0, s20_1, s20_2, s20_3, s20_4, s20_5, s20_6, s20_7;
    wire [7:0] s21_0, s21_1, s21_2, s21_3, s21_4, s21_5, s21_6, s21_7;
    wire [7:0] s22_0, s22_1, s22_2, s22_3, s22_4, s22_5, s22_6, s22_7;
    wire [7:0] s23_0, s23_1, s23_2, s23_3, s23_4, s23_5, s23_6, s23_7;
    wire [7:0] s24_0, s24_1, s24_2, s24_3, s24_4, s24_5, s24_6, s24_7;
    wire [7:0] s25_0, s25_1, s25_2, s25_3, s25_4, s25_5, s25_6, s25_7;
    wire [7:0] s26_0, s26_1, s26_2, s26_3, s26_4, s26_5, s26_6, s26_7;

    // Stage 0: Input to Stage 1 (Odd phase: 1-2, 3-4, 5-6, 7-8 indices)
    swap_cell u_c0_01 (in_0, in_1, s0_0, s0_1);
    swap_cell u_c0_23 (in_2, in_3, s0_2, s0_3);
    swap_cell u_c0_45 (in_4, in_5, s0_4, s0_5);
    swap_cell u_c0_67 (in_6, in_7, s0_6, s0_7);

    // Stage 1
    swap_cell u_c1_01 (s0_0, s0_2, s1_0, s1_1);
    swap_cell u_c1_23 (s0_1, s0_3, s1_2, s1_3);
    swap_cell u_c1_45 (s0_4, s0_6, s1_4, s1_5);
    swap_cell u_c1_67 (s0_5, s0_7, s1_6, s1_7);

    // Stage 2
    swap_cell u_c2_01 (s1_0, s1_1, s2_0, s2_1);
    swap_cell u_c2_23 (s1_2, s1_3, s2_2, s2_3);
    swap_cell u_c2_45 (s1_4, s1_5, s2_4, s2_5);
    swap_cell u_c2_67 (s1_6, s1_7, s2_6, s2_7);

    // Stage 3
    swap_cell u_c3_01 (s2_0, s2_3, s3_0, s3_1);
    swap_cell u_c3_23 (s2_1, s2_2, s3_2, s3_3);
    swap_cell u_c3_45 (s2_4, s2_7, s3_4, s3_5);
    swap_cell u_c3_67 (s2_5, s2_6, s3_6, s3_7);

    // Stage 4
    swap_cell u_c4_01 (s3_0, s3_5, s4_0, s4_1);
    swap_cell u_c4_23 (s3_1, s3_4, s4_2, s4_3);
    swap_cell u_c4_45 (s3_2, s3_7, s4_4, s4_5);
    swap_cell u_c4_67 (s3_3, s3_6, s4_6, s4_7);

    // Stage 5
    swap_cell u_c5_01 (s4_0, s4_1, s5_0, s5_1);
    swap_cell u_c5_23 (s4_2, s4_3, s5_2, s5_3);
    swap_cell u_c5_45 (s4_4, s4_5, s5_4, s5_5);
    swap_cell u_c5_67 (s4_6, s4_7, s5_6, s5_7);

    // Stage 6
    swap_cell u_c6_01 (s5_0, s5_2, s6_0, s6_1);
    swap_cell u_c6_23 (s5_1, s5_3, s6_2, s6_3);
    swap_cell u_c6_45 (s5_4, s5_6, s6_4, s6_5);
    swap_cell u_c6_67 (s5_5, s5_7, s6_6, s6_7);

    // Stage 7
    swap_cell u_c7_01 (s6_0, s6_7, s7_0, s7_1);
    swap_cell u_c7_23 (s6_1, s6_6, s7_2, s7_3);
    swap_cell u_c7_45 (s6_2, s6_5, s7_4, s7_5);
    swap_cell u_c7_67 (s6_3, s6_4, s7_6, s7_7);

    // Stage 8
    swap_cell u_c8_01 (s7_0, s7_1, s8_0, s8_1);
    swap_cell u_c8_23 (s7_2, s7_3, s8_2, s8_3);
    swap_cell u_c8_45 (s7_4, s7_5, s8_4, s8_5);
    swap_cell u_c8_67 (s7_6, s7_7, s8_6, s8_7);

    // Stage 9
    swap_cell u_c9_01 (s8_0, s8_2, s9_0, s9_1);
    swap_cell u_c9_23 (s8_1, s8_3, s9_2, s9_3);
    swap_cell u_c9_45 (s8_4, s8_6, s9_4, s9_5);
    swap_cell u_c9_67 (s8_5, s8_7, s9_6, s9_7);

    // Stage 10
    swap_cell u_c10_01 (s9_0, s9_6, s10_0, s10_1);
    swap_cell u_c10_23 (s9_1, s9_7, s10_2, s10_3);
    swap_cell u_c10_45 (s9_2, s9_4, s10_4, s10_5);
    swap_cell u_c10_67 (s9_3, s9_5, s10_6, s10_7);

    // Stage 11
    swap_cell u_c11_01 (s10_0, s10_3, s11_0, s11_1);
    swap_cell u_c11_23 (s10_1, s10_2, s11_2, s11_3);
    swap_cell u_c11_45 (s10_4, s10_7, s11_4, s11_5);
    swap_cell u_c11_67 (s10_5, s10_6, s11_6, s11_7);

    // Stage 12
    swap_cell u_c12_01 (s11_0, s11_1, s12_0, s12_1);
    swap_cell u_c12_23 (s11_2, s11_3, s12_2, s12_3);
    swap_cell u_c12_45 (s11_4, s11_5, s12_4, s12_5);
    swap_cell u_c12_67 (s11_6, s11_7, s12_6, s12_7);

    // Stage 13
    swap_cell u_c13_01 (s12_0, s12_2, s13_0, s13_1);
    swap_cell u_c13_23 (s12_1, s12_3, s13_2, s13_3);
    swap_cell u_c13_45 (s12_4, s12_6, s13_4, s13_5);
    swap_cell u_c13_67 (s12_5, s12_7, s13_6, s13_7);

    // Stage 14
    swap_cell u_c14_01 (s13_0, s13_5, s14_0, s14_1);
    swap_cell u_c14_23 (s13_1, s13_4, s14_2, s14_3);
    swap_cell u_c14_45 (s13_2, s13_7, s14_4, s14_5);
    swap_cell u_c14_67 (s13_3, s13_6, s14_6, s14_7);

    // Stage 15
    swap_cell u_c15_01 (s14_0, s14_4, s15_0, s15_1);
    swap_cell u_c15_23 (s14_1, s14_5, s15_2, s15_3);
    swap_cell u_c15_45 (s14_2, s14_6, s15_4, s15_5);
    swap_cell u_c15_67 (s14_3, s14_7, s15_6, s15_7);

    // Stage 16
    swap_cell u_c16_01 (s15_0, s15_1, s16_0, s16_1);
    swap_cell u_c16_23 (s15_2, s15_3, s16_2, s16_3);
    swap_cell u_c16_45 (s15_4, s15_5, s16_4, s16_5);
    swap_cell u_c16_67 (s15_6, s15_7, s16_6, s16_7);

    // Stage 17
    swap_cell u_c17_01 (s16_0, s16_2, s17_0, s17_1);
    swap_cell u_c17_23 (s16_1, s16_3, s17_2, s17_3);
    swap_cell u_c17_45 (s16_4, s16_6, s17_4, s17_5);
    swap_cell u_c17_67 (s16_5, s16_7, s17_6, s17_7);

    // Stage 18
    swap_cell u_c18_01 (s17_0, s17_7, s18_0, s18_1);
    swap_cell u_c18_23 (s17_1, s17_6, s18_2, s18_3);
    swap_cell u_c18_45 (s17_2, s17_5, s18_4, s18_5);
    swap_cell u_c18_67 (s17_3, s17_4, s18_6, s18_7);

    // Stage 19
    swap_cell u_c19_01 (s18_0, s18_1, s19_0, s19_1);
    swap_cell u_c19_23 (s18_2, s18_3, s19_2, s19_3);
    swap_cell u_c19_45 (s18_4, s18_5, s19_4, s19_5);
    swap_cell u_c19_67 (s18_6, s18_7, s19_6, s19_7);

    // Stage 20
    swap_cell u_c20_01 (s19_0, s19_2, s20_0, s20_1);
    swap_cell u_c20_23 (s19_1, s19_3, s20_2, s20_3);
    swap_cell u_c20_45 (s19_4, s19_6, s20_4, s20_5);
    swap_cell u_c20_67 (s19_5, s19_7, s20_6, s20_7);

    // Stage 21
    swap_cell u_c21_01 (s20_0, s20_6, s21_0, s21_1);
    swap_cell u_c21_23 (s20_1, s20_7, s21_2, s21_3);
    swap_cell u_c21_45 (s20_2, s20_4, s21_4, s21_5);
    swap_cell u_c21_67 (s20_3, s20_5, s21_6, s21_7);

    // Stage 22
    swap_cell u_c22_01 (s21_0, s21_3, s22_0, s22_1);
    swap_cell u_c22_23 (s21_1, s21_2, s22_2, s22_3);
    swap_cell u_c22_45 (s21_4, s21_7, s22_4, s22_5);
    swap_cell u_c22_67 (s21_5, s21_6, s22_6, s22_7);

    // Stage 23
    swap_cell u_c23_01 (s22_0, s22_1, s23_0, s23_1);
    swap_cell u_c23_23 (s22_2, s22_3, s23_2, s23_3);
    swap_cell u_c23_45 (s22_4, s22_5, s23_4, s23_5);
    swap_cell u_c23_67 (s22_6, s22_7, s23_6, s23_7);

    // Stage 24
    swap_cell u_c24_01 (s23_0, s23_2, s24_0, s24_1);
    swap_cell u_c24_23 (s23_1, s23_3, s24_2, s24_3);
    swap_cell u_c24_45 (s23_4, s23_6, s24_4, s24_5);
    swap_cell u_c24_67 (s23_5, s23_7, s24_6, s24_7);

    // Stage 25
    swap_cell u_c25_01 (s24_0, s24_5, s25_0, s25_1);
    swap_cell u_c25_23 (s24_1, s24_4, s25_2, s25_3);
    swap_cell u_c25_45 (s24_2, s24_7, s25_4, s25_5);
    swap_cell u_c25_67 (s24_3, s24_6, s25_6, s25_7);

    // Stage 26
    swap_cell u_c26_01 (s25_0, s25_4, s26_0, s26_1);
    swap_cell u_c26_23 (s25_1, s25_5, s26_2, s26_3);
    swap_cell u_c26_45 (s25_2, s25_6, s26_4, s26_5);
    swap_cell u_c26_67 (s25_3, s25_7, s26_6, s26_7);

    // Final outputs (Stage 27)
    // The network is 1-indexed in logic, but here we just assign the last stage outputs.
    // Wait, 28 stages means we need 28 swaps. My loop above has 27 stages (0-26).
    // Let's add the final stage.
    wire [7:0] s27_0, s27_1, s27_2, s27_3, s27_4, s27_5, s27_6, s27_7;
    swap_cell u_c27_01 (s26_0, s26_1, s27_0, s27_1);
    swap_cell u_c27_23 (s26_2, s26_3, s27_2, s27_3);
    swap_cell u_c27_45 (s26_4, s26_5, s27_4, s27_5);
    swap_cell u_c27_67 (s26_6, s26_7, s27_6, s27_7);

    // Sort order: ASCENDING (smallest first)
    assign out_0 = s27_0;
    assign out_1 = s27_1;
    assign out_2 = s27_2;
    assign out_3 = s27_3;
    assign out_4 = s27_4;
    assign out_5 = s27_5;
    assign out_6 = s27_6;
    assign out_7 = s27_7;

endmodule

module swap_cell (
    input [7:0] a,
    input [7:0] b,
    output [7:0] lo,
    output [7:0] hi
);
    wire [2:0] pc_a;
    wire [2:0] pc_b;
    wire a_lt_b;

    // Popcount units
    // Using 2-bit adders: (0+1), (2+3), (4+5), (6+7) -> S1, S2, S3, S4
    // Then (S1+S2), (S3+S4) -> S5, S6
    // Then (S5+S6) -> Total
    wire [1:0] s1, s2, s3, s4, s5, s6;

    assign s1 = a[0] + a[1];
    assign s2 = a[2] + a[3];
    assign s3 = a[4] + a[5];
    assign s4 = a[6] + a[7];
    assign s5 = s1 + s2;
    assign s6 = s3 + s4;
    assign pc_a = s5 + s6;

    assign s1 = b[0] + b[1];
    assign s2 = b[2] + b[3];
    assign s3 = b[4] + b[5];
    assign s4 = b[6] + b[7];
    assign s5 = s1 + s2;
    assign s6 = s3 + s4;
    assign pc_b = s5 + s6;

    // Comparator Logic: a < b if (pc_a < pc_b) OR (pc_a == pc_b AND a < b)
    // Note: If a < b is true, a goes to lo, b goes to hi.
    assign a_lt_b = (pc_a < pc_b) | ((pc_a == pc_b) & (a < b));

    assign lo = a_lt_b ? a : b;
    assign hi = a_lt_b ? b : a;

endmodule