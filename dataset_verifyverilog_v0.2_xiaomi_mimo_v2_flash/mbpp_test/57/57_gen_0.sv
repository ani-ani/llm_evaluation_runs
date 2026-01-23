module largest_number_formed(
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

    // Wires for sorting network stages
    wire [7:0] d0, d1, d2, d3, d4, d5, d6, d7;
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

    // Input buffer/assignment
    assign d0 = digit_0;
    assign d1 = digit_1;
    assign d2 = digit_2;
    assign d3 = digit_3;
    assign d4 = digit_4;
    assign d5 = digit_5;
    assign d6 = digit_6;
    assign d7 = digit_7;

    // Stage 0: Compare (0,1), (2,3), (4,5), (6,7)
    assign s0_0 = (d0 > d1) ? d0 : d1;
    assign s0_1 = (d0 > d1) ? d1 : d0;
    assign s0_2 = (d2 > d3) ? d2 : d3;
    assign s0_3 = (d2 > d3) ? d3 : d2;
    assign s0_4 = (d4 > d5) ? d4 : d5;
    assign s0_5 = (d4 > d5) ? d5 : d4;
    assign s0_6 = (d6 > d7) ? d6 : d7;
    assign s0_7 = (d6 > d7) ? d7 : d6;

    // Stage 1: Compare (0,2), (1,3), (4,6), (5,7)
    assign s1_0 = (s0_0 > s0_2) ? s0_0 : s0_2;
    assign s1_2 = (s0_0 > s0_2) ? s0_2 : s0_0;
    assign s1_1 = (s0_1 > s0_3) ? s0_1 : s0_3;
    assign s1_3 = (s0_1 > s0_3) ? s0_3 : s0_1;
    assign s1_4 = (s0_4 > s0_6) ? s0_4 : s0_6;
    assign s1_6 = (s0_4 > s0_6) ? s0_6 : s0_4;
    assign s1_5 = (s0_5 > s0_7) ? s0_5 : s0_7;
    assign s1_7 = (s0_5 > s0_7) ? s0_7 : s0_5;

    // Stage 2: Compare (1,2), (5,6)
    assign s2_0 = s1_0;
    assign s2_1 = (s1_1 > s1_2) ? s1_1 : s1_2;
    assign s2_2 = (s1_1 > s1_2) ? s1_2 : s1_1;
    assign s2_3 = s1_3;
    assign s2_4 = s1_4;
    assign s2_5 = (s1_5 > s1_6) ? s1_5 : s1_6;
    assign s2_6 = (s1_5 > s1_6) ? s1_6 : s1_5;
    assign s2_7 = s1_7;

    // Stage 3: Compare (0,4), (1,5), (2,6), (3,7)
    assign s3_0 = (s2_0 > s2_4) ? s2_0 : s2_4;
    assign s3_4 = (s2_0 > s2_4) ? s2_4 : s2_0;
    assign s3_1 = (s2_1 > s2_5) ? s2_1 : s2_5;
    assign s3_5 = (s2_1 > s2_5) ? s2_5 : s2_1;
    assign s3_2 = (s2_2 > s2_6) ? s2_2 : s2_6;
    assign s3_6 = (s2_2 > s2_6) ? s2_6 : s2_2;
    assign s3_3 = (s2_3 > s2_7) ? s2_3 : s2_7;
    assign s3_7 = (s2_3 > s2_7) ? s2_7 : s2_3;

    // Stage 4: Compare (1,2), (3,4), (5,6)
    assign s4_0 = s3_0;
    assign s4_1 = (s3_1 > s3_2) ? s3_1 : s3_2;
    assign s4_2 = (s3_1 > s3_2) ? s3_2 : s3_1;
    assign s4_3 = (s3_3 > s3_4) ? s3_3 : s3_4;
    assign s4_4 = (s3_3 > s3_4) ? s3_4 : s3_3;
    assign s4_5 = (s3_5 > s3_6) ? s3_5 : s3_6;
    assign s4_6 = (s3_5 > s3_6) ? s3_6 : s3_5;
    assign s4_7 = s3_7;

    // Stage 5: Compare (0,1), (2,3), (4,5), (6,7)
    assign s5_0 = (s4_0 > s4_1) ? s4_0 : s4_1;
    assign s5_1 = (s4_0 > s4_1) ? s4_1 : s4_0;
    assign s5_2 = (s4_2 > s4_3) ? s4_2 : s4_3;
    assign s5_3 = (s4_2 > s4_3) ? s4_3 : s4_2;
    assign s5_4 = (s4_4 > s4_5) ? s4_4 : s4_5;
    assign s5_5 = (s4_4 > s4_5) ? s4_5 : s4_4;
    assign s5_6 = (s4_6 > s4_7) ? s4_6 : s4_7;
    assign s5_7 = (s4_6 > s4_7) ? s4_7 : s4_6;

    // Stage 6: Compare (1,2), (3,4), (5,6)
    assign s6_0 = s5_0;
    assign s6_1 = (s5_1 > s5_2) ? s5_1 : s5_2;
    assign s6_2 = (s5_1 > s5_2) ? s5_2 : s5_1;
    assign s6_3 = (s5_3 > s5_4) ? s5_3 : s5_4;
    assign s6_4 = (s5_3 > s5_4) ? s5_4 : s5_3;
    assign s6_5 = (s5_5 > s5_6) ? s5_5 : s5_6;
    assign s6_6 = (s5_5 > s5_6) ? s5_6 : s5_5;
    assign s6_7 = s5_7;

    // Stage 7: Compare (2,3), (4,5)
    assign s7_0 = s6_0;
    assign s7_1 = s6_1;
    assign s7_2 = (s6_2 > s6_3) ? s6_2 : s6_3;
    assign s7_3 = (s6_2 > s6_3) ? s6_3 : s6_2;
    assign s7_4 = (s6_4 > s6_5) ? s6_4 : s6_5;
    assign s7_5 = (s6_4 > s6_5) ? s6_5 : s6_4;
    assign s7_6 = s6_6;
    assign s7_7 = s6_7;

    // Stage 8: Compare (3,4)
    assign s8_0 = s7_0;
    assign s8_1 = s7_1;
    assign s8_2 = s7_2;
    assign s8_3 = (s7_3 > s7_4) ? s7_3 : s7_4;
    assign s8_4 = (s7_3 > s7_4) ? s7_4 : s7_3;
    assign s8_5 = s7_5;
    assign s8_6 = s7_6;
    assign s8_7 = s7_7;

    // Stage 9: Compare (1,2), (5,6)
    assign s9_0 = s8_0;
    assign s9_1 = (s8_1 > s8_2) ? s8_1 : s8_2;
    assign s9_2 = (s8_1 > s8_2) ? s8_2 : s8_1;
    assign s9_3 = s8_3;
    assign s9_4 = s8_4;
    assign s9_5 = (s8_5 > s8_6) ? s8_5 : s8_6;
    assign s9_6 = (s8_5 > s8_6) ? s8_6 : s8_5;
    assign s9_7 = s8_7;

    // Stage 10: Compare (2,3), (4,5)
    assign s10_0 = s9_0;
    assign s10_1 = s9_1;
    assign s10_2 = (s9_2 > s9_3) ? s9_2 : s9_3;
    assign s10_3 = (s9_2 > s9_3) ? s9_3 : s9_2;
    assign s10_4 = (s9_4 > s9_5) ? s9_4 : s9_5;
    assign s10_5 = (s9_4 > s9_5) ? s9_5 : s9_4;
    assign s10_6 = s9_6;
    assign s10_7 = s9_7;

    // Stage 11: Compare (3,4)
    assign s11_0 = s10_0;
    assign s11_1 = s10_1;
    assign s11_2 = s10_2;
    assign s11_3 = (s10_3 > s10_4) ? s10_3 : s10_4;
    assign s11_4 = (s10_3 > s10_4) ? s10_4 : s10_3;
    assign s11_5 = s10_5;
    assign s11_6 = s10_6;
    assign s11_7 = s10_7;

    // Result assembly (descending order: s11_0 is largest, s11_7 is smallest)
    // Each digit is 8 bits, total 32 bits
    assign result = {s11_0, s11_1, s11_2, s11_3};

endmodule
