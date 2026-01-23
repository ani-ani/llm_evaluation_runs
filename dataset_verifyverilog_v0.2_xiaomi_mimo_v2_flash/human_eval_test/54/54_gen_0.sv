module same_chars(
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

    // Sort s0 using bubble sort (fully unrolled)
    wire [7:0] s0_sorted [0:7];
    assign s0_sorted[0] = s0_chars[0];
    assign s0_sorted[1] = s0_chars[1];
    assign s0_sorted[2] = s0_chars[2];
    assign s0_sorted[3] = s0_chars[3];
    assign s0_sorted[4] = s0_chars[4];
    assign s0_sorted[5] = s0_chars[5];
    assign s0_sorted[6] = s0_chars[6];
    assign s0_sorted[7] = s0_chars[7];

    wire [7:0] s0_stage1 [0:7];
    assign s0_stage1[0] = (s0_sorted[0] > s0_sorted[1]) ? s0_sorted[1] : s0_sorted[0];
    assign s0_stage1[1] = (s0_sorted[0] > s0_sorted[1]) ? s0_sorted[0] : s0_sorted[1];
    assign s0_stage1[2] = s0_sorted[2];
    assign s0_stage1[3] = s0_sorted[3];
    assign s0_stage1[4] = s0_sorted[4];
    assign s0_stage1[5] = s0_sorted[5];
    assign s0_stage1[6] = s0_sorted[6];
    assign s0_stage1[7] = s0_sorted[7];

    wire [7:0] s0_stage2 [0:7];
    assign s0_stage2[0] = s0_stage1[0];
    assign s0_stage2[1] = (s0_stage1[1] > s0_stage1[2]) ? s0_stage1[2] : s0_stage1[1];
    assign s0_stage2[2] = (s0_stage1[1] > s0_stage1[2]) ? s0_stage1[1] : s0_stage1[2];
    assign s0_stage2[3] = s0_stage1[3];
    assign s0_stage2[4] = s0_stage1[4];
    assign s0_stage2[5] = s0_stage1[5];
    assign s0_stage2[6] = s0_stage1[6];
    assign s0_stage2[7] = s0_stage1[7];

    wire [7:0] s0_stage3 [0:7];
    assign s0_stage3[0] = s0_stage2[0];
    assign s0_stage3[1] = s0_stage2[1];
    assign s0_stage3[2] = (s0_stage2[2] > s0_stage2[3]) ? s0_stage2[3] : s0_stage2[2];
    assign s0_stage3[3] = (s0_stage2[2] > s0_stage2[3]) ? s0_stage2[2] : s0_stage2[3];
    assign s0_stage3[4] = s0_stage2[4];
    assign s0_stage3[5] = s0_stage2[5];
    assign s0_stage3[6] = s0_stage2[6];
    assign s0_stage3[7] = s0_stage2[7];

    wire [7:0] s0_stage4 [0:7];
    assign s0_stage4[0] = s0_stage3[0];
    assign s0_stage4[1] = s0_stage3[1];
    assign s0_stage4[2] = s0_stage3[2];
    assign s0_stage4[3] = (s0_stage3[3] > s0_stage3[4]) ? s0_stage3[4] : s0_stage3[3];
    assign s0_stage4[4] = (s0_stage3[3] > s0_stage3[4]) ? s0_stage3[3] : s0_stage3[4];
    assign s0_stage4[5] = s0_stage3[5];
    assign s0_stage4[6] = s0_stage3[6];
    assign s0_stage4[7] = s0_stage3[7];

    wire [7:0] s0_stage5 [0:7];
    assign s0_stage5[0] = s0_stage4[0];
    assign s0_stage5[1] = s0_stage4[1];
    assign s0_stage5[2] = s0_stage4[2];
    assign s0_stage5[3] = s0_stage4[3];
    assign s0_stage5[4] = (s0_stage4[4] > s0_stage4[5]) ? s0_stage4[5] : s0_stage4[4];
    assign s0_stage5[5] = (s0_stage4[4] > s0_stage4[5]) ? s0_stage4[4] : s0_stage4[5];
    assign s0_stage5[6] = s0_stage4[6];
    assign s0_stage5[7] = s0_stage4[7];

    wire [7:0] s0_stage6 [0:7];
    assign s0_stage6[0] = s0_stage5[0];
    assign s0_stage6[1] = s0_stage5[1];
    assign s0_stage6[2] = s0_stage5[2];
    assign s0_stage6[3] = s0_stage5[3];
    assign s0_stage6[4] = s0_stage5[4];
    assign s0_stage6[5] = (s0_stage5[5] > s0_stage5[6]) ? s0_stage5[6] : s0_stage5[5];
    assign s0_stage6[6] = (s0_stage5[5] > s0_stage5[6]) ? s0_stage5[5] : s0_stage5[6];
    assign s0_stage6[7] = s0_stage5[7];

    wire [7:0] s0_stage7 [0:7];
    assign s0_stage7[0] = s0_stage6[0];
    assign s0_stage7[1] = s0_stage6[1];
    assign s0_stage7[2] = s0_stage6[2];
    assign s0_stage7[3] = s0_stage6[3];
    assign s0_stage7[4] = s0_stage6[4];
    assign s0_stage7[5] = s0_stage6[5];
    assign s0_stage7[6] = (s0_stage6[6] > s0_stage6[7]) ? s0_stage6[7] : s0_stage6[6];
    assign s0_stage7[7] = (s0_stage6[6] > s0_stage6[7]) ? s0_stage6[6] : s0_stage6[7];

    // Second pass of bubble sort
    wire [7:0] s0_stage8 [0:7];
    assign s0_stage8[0] = (s0_stage7[0] > s0_stage7[1]) ? s0_stage7[1] : s0_stage7[0];
    assign s0_stage8[1] = (s0_stage7[0] > s0_stage7[1]) ? s0_stage7[0] : s0_stage7[1];
    assign s0_stage8[2] = s0_stage7[2];
    assign s0_stage8[3] = s0_stage7[3];
    assign s0_stage8[4] = s0_stage7[4];
    assign s0_stage8[5] = s0_stage7[5];
    assign s0_stage8[6] = s0_stage7[6];
    assign s0_stage8[7] = s0_stage7[7];

    wire [7:0] s0_stage9 [0:7];
    assign s0_stage9[0] = s0_stage8[0];
    assign s0_stage9[1] = (s0_stage8[1] > s0_stage8[2]) ? s0_stage8[2] : s0_stage8[1];
    assign s0_stage9[2] = (s0_stage8[1] > s0_stage8[2]) ? s0_stage8[1] : s0_stage8[2];
    assign s0_stage9[3] = s0_stage8[3];
    assign s0_stage9[4] = s0_stage8[4];
    assign s0_stage9[5] = s0_stage8[5];
    assign s0_stage9[6] = s0_stage8[6];
    assign s0_stage9[7] = s0_stage8[7];

    wire [7:0] s0_stage10 [0:7];
    assign s0_stage10[0] = s0_stage9[0];
    assign s0_stage10[1] = s0_stage9[1];
    assign s0_stage10[2] = (s0_stage9[2] > s0_stage9[3]) ? s0_stage9[3] : s0_stage9[2];
    assign s0_stage10[3] = (s0_stage9[2] > s0_stage9[3]) ? s0_stage9[2] : s0_stage9[3];
    assign s0_stage10[4] = s0_stage9[4];
    assign s0_stage10[5] = s0_stage9[5];
    assign s0_stage10[6] = s0_stage9[6];
    assign s0_stage10[7] = s0_stage9[7];

    wire [7:0] s0_stage11 [0:7];
    assign s0_stage11[0] = s0_stage10[0];
    assign s0_stage11[1] = s0_stage10[1];
    assign s0_stage11[2] = s0_stage10[2];
    assign s0_stage11[3] = (s0_stage10[3] > s0_stage10[4]) ? s0_stage10[4] : s0_stage10[3];
    assign s0_stage11[4] = (s0_stage10[3] > s0_stage10[4]) ? s0_stage10[3] : s0_stage10[4];
    assign s0_stage11[5] = s0_stage10[5];
    assign s0_stage11[6] = s0_stage10[6];
    assign s0_stage11[7] = s0_stage10[7];

    wire [7:0] s0_stage12 [0:7];
    assign s0_stage12[0] = s0_stage11[0];
    assign s0_stage12[1] = s0_stage11[1];
    assign s0_stage12[2] = s0_stage11[2];
    assign s0_stage12[3] = s0_stage11[3];
    assign s0_stage12[4] = (s0_stage11[4] > s0_stage11[5]) ? s0_stage11[5] : s0_stage11[4];
    assign s0_stage12[5] = (s0_stage11[4] > s0_stage11[5]) ? s0_stage11[4] : s0_stage11[5];
    assign s0_stage12[6] = s0_stage11[6];
    assign s0_stage12[7] = s0_stage11[7];

    wire [7:0] s0_stage13 [0:7];
    assign s0_stage13[0] = s0_stage12[0];
    assign s0_stage13[1] = s0_stage12[1];
    assign s0_stage13[2] = s0_stage12[2];
    assign s0_stage13[3] = s0_stage12[3];
    assign s0_stage13[4] = s0_stage12[4];
    assign s0_stage13[5] = (s0_stage12[5] > s0_stage12[6]) ? s0_stage12[6] : s0_stage12[5];
    assign s0_stage13[6] = (s0_stage12[5] > s0_stage12[6]) ? s0_stage12[5] : s0_stage12[6];
    assign s0_stage13[7] = s0_stage12[7];

    wire [7:0] s0_stage14 [0:7];
    assign s0_stage14[0] = s0_stage13[0];
    assign s0_stage14[1] = s0_stage13[1];
    assign s0_stage14[2] = s0_stage13[2];
    assign s0_stage14[3] = s0_stage13[3];
    assign s0_stage14[4] = s0_stage13[4];
    assign s0_stage14[5] = s0_stage13[5];
    assign s0_stage14[6] = (s0_stage13[6] > s0_stage13[7]) ? s0_stage13[7] : s0_stage13[6];
    assign s0_stage14[7] = (s0_stage13[6] > s0_stage13[7]) ? s0_stage13[6] : s0_stage13[7];

    // Third pass of bubble sort
    wire [7:0] s0_stage15 [0:7];
    assign s0_stage15[0] = (s0_stage14[0] > s0_stage14[1]) ? s0_stage14[1] : s0_stage14[0];
    assign s0_stage15[1] = (s0_stage14[0] > s0_stage14[1]) ? s0_stage14[0] : s0_stage14[1];
    assign s0_stage15[2] = s0_stage14[2];
    assign s0_stage15[3] = s0_stage14[3];
    assign s0_stage15[4] = s0_stage14[4];
    assign s0_stage15[5] = s0_stage14[5];
    assign s0_stage15[6] = s0_stage14[6];
    assign s0_stage15[7] = s0_stage14[7];

    wire [7:0] s0_stage16 [0:7];
    assign s0_stage16[0] = s0_stage15[0];
    assign s0_stage16[1] = (s0_stage15[1] > s0_stage15[2]) ? s0_stage15[2] : s0_stage15[1];
    assign s0_stage16[2] = (s0_stage15[1] > s0_stage15[2]) ? s0_stage15[1] : s0_stage15[2];
    assign s0_stage16[3] = s0_stage15[3];
    assign s0_stage16[4] = s0_stage15[4];
    assign s0_stage16[5] = s0_stage15[5];
    assign s0_stage16[6] = s0_stage15[6];
    assign s0_stage16[7] = s0_stage15[7];

    wire [7:0] s0_stage17 [0:7];
    assign s0_stage17[0] = s0_stage16[0];
    assign s0_stage17[1] = s0_stage16[1];
    assign s0_stage17[2] = (s0_stage16[2] > s0_stage16[3]) ? s0_stage16[3] : s0_stage16[2];
    assign s0_stage17[3] = (s0_stage16[2] > s0_stage16[3]) ? s0_stage16[2] : s0_stage16[3];
    assign s0_stage17[4] = s0_stage16[4];
    assign s0_stage17[5] = s0_stage16[5];
    assign s0_stage17[6] = s0_stage16[6];
    assign s0_stage17[7] = s0_stage16[7];

    wire [7:0] s0_stage18 [0:7];
    assign s0_stage18[0] = s0_stage17[0];
    assign s0_stage18[1] = s0_stage17[1];
    assign s0_stage18[2] = s0_stage17[2];
    assign s0_stage18[3] = (s0_stage17[3] > s0_stage17[4]) ? s0_stage17[4] : s0_stage17[3];
    assign s0_stage18[4] = (s0_stage17[3] > s0_stage17[4]) ? s0_stage17[3] : s0_stage17[4];
    assign s0_stage18[5] = s0_stage17[5];
    assign s0_stage18[6] = s0_stage17[6];
    assign s0_stage18[7] = s0_stage17[7];

    wire [7:0] s0_stage19 [0:7];
    assign s0_stage19[0] = s0_stage18[0];
    assign s0_stage19[1] = s0_stage18[1];
    assign s0_stage19[2] = s0_stage18[2];
    assign s0_stage19[3] = s0_stage18[3];
    assign s0_stage19[4] = (s0_stage18[4] > s0_stage18[5]) ? s0_stage18[5] : s0_stage18[4];
    assign s0_stage19[5] = (s0_stage18[4] > s0_stage18[5]) ? s0_stage18[4] : s0_stage18[5];
    assign s0_stage19[6] = s0_stage18[6];
    assign s0_stage19[7] = s0_stage18[7];

    wire [7:0] s0_stage20 [0:7];
    assign s0_stage20[0] = s0_stage19[0];
    assign s0_stage20[1] = s0_stage19[1];
    assign s0_stage20[2] = s0_stage19[2];
    assign s0_stage20[3] = s0_stage19[3];
    assign s0_stage20[4] = s0_stage19[4];
    assign s0_stage20[5] = (s0_stage19[5] > s0_stage19[6]) ? s0_stage19[6] : s0_stage19[5];
    assign s0_stage20[6] = (s0_stage19[5] > s0_stage19[6]) ? s0_stage19[5] : s0_stage19[6];
    assign s0_stage20[7] = s0_stage19[7];

    wire [7:0] s0_stage21 [0:7];
    assign s0_stage21[0] = s0_stage20[0];
    assign s0_stage21[1] = s0_stage20[1];
    assign s0_stage21[2] = s0_stage20[2];
    assign s0_stage21[3] = s0_stage20[3];
    assign s0_stage21[4] = s0_stage20[4];
    assign s0_stage21[5] = s0_stage20[5];
    assign s0_stage21[6] = (s0_stage20[6] > s0_stage20[7]) ? s0_stage20[7] : s0_stage20[6];
    assign s0_stage21[7] = (s0_stage20[6] > s0_stage20[7]) ? s0_stage20[6] : s0_stage20[7];

    // Fourth pass of bubble sort
    wire [7:0] s0_stage22 [0:7];
    assign s0_stage22[0] = (s0_stage21[0] > s0_stage21[1]) ? s0_stage21[1] : s0_stage21[0];
    assign s0_stage22[1] = (s0_stage21[0] > s0_stage21[1]) ? s0_stage21[0] : s0_stage21[1];
    assign s0_stage22[2] = s0_stage21[2];
    assign s0_stage22[3] = s0_stage21[3];
    assign s0_stage22[4] = s0_stage21[4];
    assign s0_stage22[5] = s0_stage21[5];
    assign s0_stage22[6] = s0_stage21[6];
    assign s0_stage22[7] = s0_stage21[7];

    wire [7:0] s0_stage23 [0:7];
    assign s0_stage23[0] = s0_stage22[0];
    assign s0_stage23[1] = (s0_stage22[1] > s0_stage22[2]) ? s0_stage22[2] : s0_stage22[1];
    assign s0_stage23[2] = (s0_stage22[1] > s0_stage22[2]) ? s0_stage22[1] : s0_stage22[2];
    assign s0_stage23[3] = s0_stage22[3];
    assign s0_stage23[4] = s0_stage22[4];
    assign s0_stage23[5] = s0_stage22[5];
    assign s0_stage23[6] = s0_stage22[6];
    assign s0_stage23[7] = s0_stage22[7];

    wire [7:0] s0_stage24 [0:7];
    assign s0_stage24[0] = s0_stage23[0];
    assign s0_stage24[1] = s0_stage23[1];
    assign s0_stage24[2] = (s0_stage23[2] > s0_stage23[3]) ? s0_stage23[3] : s0_stage23[2];
    assign s0_stage24[3] = (s0_stage23[2] > s0_stage23[3]) ? s0_stage23[2] : s0_stage23[3];
    assign s0_stage24[4] = s0_stage23[4];
    assign s0_stage24[5] = s0_stage23[5];
    assign s0_stage24[6] = s0_stage23[6];
    assign s0_stage24[7] = s0_stage23[7];

    wire [7:0] s0_stage25 [0:7];
    assign s0_stage25[0] = s0_stage24[0];
    assign s0_stage25[1] = s0_stage24[1];
    assign s0_stage25[2] = s0_stage24[2];
    assign s0_stage25[3] = (s0_stage24[3] > s0_stage24[4]) ? s0_stage24[4] : s0_stage24[3];
    assign s0_stage25[4] = (s0_stage24[3] > s0_stage24[4]) ? s0_stage24[3] : s0_stage24[4];
    assign s0_stage25[5] = s0_stage24[5];
    assign s0_stage25[6] = s0_stage24[6];
    assign s0_stage25[7] = s0_stage24[7];

    wire [7:0] s0_stage26 [0:7];
    assign s0_stage26[0] = s0_stage25[0];
    assign s0_stage26[1] = s0_stage25[1];
    assign s0_stage26[2] = s0_stage25[2];
    assign s0_stage26[3] = s0_stage25[3];
    assign s0_stage26[4] = (s0_stage25[4] > s0_stage25[5]) ? s0_stage25[5] : s0_stage25[4];
    assign s0_stage26[5] = (s0_stage25[4] > s0_stage25[5]) ? s0_stage25[4] : s0_stage25[5];
    assign s0_stage26[6] = s0_stage25[6];
    assign s0_stage26[7] = s0_stage25[7];

    wire [7:0] s0_stage27 [0:7];
    assign s0_stage27[0] = s0_stage26[0];
    assign s0_stage27[1] = s0_stage26[1];
    assign s0_stage27[2] = s0_stage26[2];
    assign s0_stage27[3] = s0_stage26[3];
    assign s0_stage27[4] = s0_stage26[4];
    assign s0_stage27[5] = (s0_stage26[5] > s0_stage26[6]) ? s0_stage26[6] : s0_stage26[5];
    assign s0_stage27[6] = (s0_stage26[5] > s0_stage26[6]) ? s0_stage26[5] : s0_stage26[6];
    assign s0_stage27[7] = s0_stage26[7];

    wire [7:0] s0_stage28 [0:7];
    assign s0_stage28[0] = s0_stage27[0];
    assign s0_stage28[1] = s0_stage27[1];
    assign s0_stage28[2] = s0_stage27[2];
    assign s0_stage28[3] = s0_stage27[3];
    assign s0_stage28[4] = s0_stage27[4];
    assign s0_stage28[5] = s0_stage27[5];
    assign s0_stage28[6] = (s0_stage27[6] > s0_stage27[7]) ? s0_stage27[7] : s0_stage27[6];
    assign s0_stage28[7] = (s0_stage27[6] > s0_stage27[7]) ? s0_stage27[6] : s0_stage27[7];

    // Fifth pass of bubble sort
    wire [7:0] s0_stage29 [0:7];
    assign s0_stage29[0] = (s0_stage28[0] > s0_stage28[1]) ? s0_stage28[1] : s0_stage28[0];
    assign s0_stage29[1] = (s0_stage28[0] > s0_stage28[1]) ? s0_stage28[0] : s0_stage28[1];
    assign s0_stage29[2] = s0_stage28[2];
    assign s0_stage29[3] = s0_stage28[3];
    assign s0_stage29[4] = s0_stage28[4];
    assign s0_stage29[5] = s0_stage28[5];
    assign s0_stage29[6] = s0_stage28[6];
    assign s0_stage29[7] = s0_stage28[7];

    wire [7:0] s0_stage30 [0:7];
    assign s0_stage30[0] = s0_stage29[0];
    assign s0_stage30[1] = (s0_stage29[1] > s0_stage29[2]) ? s0_stage29[2] : s0_stage29[1];
    assign s0_stage30[2] = (s0_stage29[1] > s0_stage29[2]) ? s0_stage29[1] : s0_stage29[2];
    assign s0_stage30[3] = s0_stage29[3];
    assign s0_stage30[4] = s0_stage29[4];
    assign s0_stage30[5] = s0_stage29[5];
    assign s0_stage30[6] = s0_stage29[6];
    assign s0_stage30[7] = s0_stage29[7];

    wire [7:0] s0_stage31 [0:7];
    assign s0_stage31[0] = s0_stage30[0];
    assign s0_stage31[1] = s0_stage30[1];
    assign s0_stage31[2] = (s0_stage30[2] > s0_stage30[3]) ? s0_stage30[3] : s0_stage30[2];
    assign s0_stage31[3] = (s0_stage30[2] > s0_stage30[3]) ? s0_stage30[2] : s0_stage30[3];
    assign s0_stage31[4] = s0_stage30[4];
    assign s0_stage31[5] = s0_stage30[5];
    assign s0_stage31[6] = s0_stage30[6];
    assign s0_stage31[7] = s0_stage30[7];

    wire [7:0] s0_stage32 [0:7];
    assign s0_stage32[0] = s0_stage31[0];
    assign s0_stage32[1] = s0_stage31[1];
    assign s0_stage32[2] = s0_stage31[2];
    assign s0_stage32[3] = (s0_stage31[3] > s0_stage31[4]) ? s0_stage31[4] : s0_stage31[3];
    assign s0_stage32[4] = (s0_stage31[3] > s0_stage31[4]) ? s0_stage31[3] : s0_stage31[4];
    assign s0_stage32[5] = s0_stage31[5];
    assign s0_stage32[6] = s0_stage31[6];
    assign s0_stage32[7] = s0_stage31[7];

    wire [7:0] s0_stage33 [0:7];
    assign s0_stage33[0] = s0_stage32[0];
    assign s0_stage33[1] = s0_stage32[1];
    assign s0_stage33[2] = s0_stage32[2];
    assign s0_stage33[3] = s0_stage32[3];
    assign s0_stage33[4] = (s0_stage32[4] > s0_stage32[5]) ? s0_stage32[5] : s0_stage32[4];
    assign s0_stage33[5] = (s0_stage32[4] > s0_stage32[5]) ? s0_stage32[4] : s0_stage32[5];
    assign s0_stage33[6] = s0_stage32[6];
    assign s0_stage33[7] = s0_stage32[7];

    wire [7:0] s0_stage34 [0:7];
    assign s0_stage34[0] = s0_stage33[0];
    assign s0_stage34[1] = s0_stage33[1];
    assign s0_stage34[2] = s0_stage33[2];
    assign s0_stage34[3] = s0_stage33[3];
    assign s0_stage34[4] = s0_stage33[4];
    assign s0_stage34[5] = (s0_stage33[5] > s0_stage33[6]) ? s0_stage33[6] : s0_stage33[5];
    assign s0_stage34[6] = (s0_stage33[5] > s0_stage33[6]) ? s0_stage33[5] : s0_stage33[6];
    assign s0_stage34[7] = s0_stage33[7];

    wire [7:0] s0_stage35 [0:7];
    assign s0_stage35[0] = s0_stage34[0];
    assign s0_stage35[1] = s0_stage34[1];
    assign s0_stage35[2] = s0_stage34[2];
    assign s0_stage35[3] = s0_stage34[3];
    assign s0_stage35[4] = s0_stage34[4];
    assign s0_stage35[5] = s0_stage34[5];
    assign s0_stage35[6] = (s0_stage34[6] > s0_stage34[7]) ? s0_stage34[7] : s0_stage34[6];
    assign s0_stage35[7] = (s0_stage34[6] > s0_stage34[7]) ? s0_stage34[6] : s0_stage34[7];

    // Sixth pass of bubble sort
    wire [7:0] s0_stage36 [0:7];
    assign s0_stage36[0] = (s0_stage35[0] > s0_stage35[1]) ? s0_stage35[1] : s0_stage35[0];
    assign s0_stage36[1] = (s0_stage35[0] > s0_stage35[1]) ? s0_stage35[0] : s0_stage35[1];
    assign s0_stage36[2] = s0_stage35[2];
    assign s0_stage36[3] = s0_stage35[3];
    assign s0_stage36[4] = s0_stage35[4];
    assign s0_stage36[5] = s0_stage35[5];
    assign s0_stage36[6] = s0_stage35[6];
    assign s0_stage36[7] = s0_stage35[7];

    wire [7:0] s0_stage37 [0:7];
    assign s0_stage37[0] = s0_stage36[0];
    assign s0_stage37[1] = (s0_stage36[1] > s0_stage36[2]) ? s0_stage36[2] : s0_stage36[1];
    assign s0_stage37[2] = (s0_stage36[1] > s0_stage36[2]) ? s0_stage36[1] : s0_stage36[2];
    assign s0_stage37[3] = s0_stage36[3];
    assign s0_stage37[4] = s0_stage36[4];
    assign s0_stage37[5] = s0_stage36[5];
    assign s0_stage37[6] = s0_stage36[6];
    assign s0_stage37[7] = s0_stage36[7];

    wire [7:0] s0_stage38 [0:7];
    assign s0_stage38[0] = s0_stage37[0];
    assign s0_stage38[1] = s0_stage37[1];
    assign s0_stage38[2] = (s0_stage37[2] > s0_stage37[3]) ? s0_stage37[3] : s0_stage37[2];
    assign s0_stage38[3] = (s0_stage37[2] > s0_stage37[3]) ? s0_stage37[2] : s0_stage37[3];
    assign s0_stage38[4] = s0_stage37[4];
    assign s0_stage38[5] = s0_stage37[5];
    assign s0_stage38[6] = s0_stage37[6];
    assign s0_stage38[7] = s0_stage37[7];

    wire [7:0] s0_stage39 [0:7];
    assign s0_stage39[0] = s0_stage38[0];
    assign s0_stage39[1] = s0_stage38[1];
    assign s0_stage39[2] = s0_stage38[2];
    assign s0_stage39[3] = (s0_stage38[3] > s0_stage38[4]) ? s0_stage38[4] : s0_stage38[3];
    assign s0_stage39[4] = (s0_stage38[3] > s0_stage38[4]) ? s0_stage38[3] : s0_stage38[4];
    assign s0_stage39[5] = s0_stage38[5];
    assign s0_stage39[6] = s0_stage38[6];
    assign s0_stage39[7] = s0_stage38[7];

    wire [7:0] s0_stage40 [0:7];
    assign s0_stage40[0] = s0_stage39[0];
    assign s0_stage40[1] = s0_stage39[1];
    assign s0_stage40[2] = s0_stage39[2];
    assign s0_stage40[3] = s0_stage39[3];
    assign s0_stage40[4] = (s0_stage39[4] > s0_stage39[5]) ? s0_stage39[5] : s0_stage39[4];
    assign s0_stage40[5] = (s0_stage39[4] > s0_stage39[5]) ? s0_stage39[4] : s0_stage39[5];
    assign s0_stage40[6] = s0_stage39[6];
    assign s0_stage40[7] = s0_stage39[7];

    wire [7:0] s0_stage41 [0:7];
    assign s0_stage41[0] = s0_stage40[0];
    assign s0_stage41[1] = s0_stage40[1];
    assign s0_stage41[2] = s0_stage40[2];
    assign s0_stage41[3] = s0_stage40[3];
    assign s0_stage41[4] = s0_stage40[4];
    assign s0_stage41[5] = (s0_stage40[5] > s0_stage40[6]) ? s0_stage40[6] : s0_stage40[5];
    assign s0_stage41[6] = (s0_stage40[5] > s0_stage40[6]) ? s0_stage40[5] : s0_stage40[6];
    assign s0_stage41[7] = s0_stage40[7];

    wire [7:0] s0_stage42 [0:7];
    assign s0_stage42[0] = s0_stage41[0];
    assign s0_stage42[1] = s0_stage41[1];
    assign s0_stage42[2] = s0_stage41[2];
    assign s0_stage42[3] = s0_stage41[3];
    assign s0_stage42[4] = s0_stage41[4];
    assign s0_stage42[5] = s0_stage41[5];
    assign s0_stage42[6] = (s0_stage41[6] > s0_stage41[7]) ? s0_stage41[7] : s0_stage41[6];
    assign s0_stage42[7] = (s0_stage41[6] > s0_stage41[7]) ? s0_stage41[6] : s0_stage41[7];

    // Seventh pass of bubble sort
    wire [7:0] s0_stage43 [0:7];
    assign s0_stage43[0] = (s0_stage42[0] > s0_stage42[1]) ? s0_stage42[1] : s0_stage42[0];
    assign s0_stage43[1] = (s0_stage42[0] > s0_stage42[1]) ? s0_stage42[0] : s0_stage42[1];
    assign s0_stage43[2] = s0_stage42[2];
    assign s0_stage43[3] = s0_stage42[3];
    assign s0_stage43[4] = s0_stage42[4];
    assign s0_stage43[5] = s0_stage42[5];
    assign s0_stage43[6] = s0_stage42[6];
    assign s0_stage43[7] = s0_stage42[7];

    wire [7:0] s0_stage44 [0:7];
    assign s0_stage44[0] = s0_stage43[0];
    assign s0_stage44[1] = (s0_stage43[1] > s0_stage43[2]) ? s0_stage43[2] : s0_stage43[1];
    assign s0_stage44[2] = (s0_stage43[1] > s0_stage43[2]) ? s0_stage43[1] : s0_stage43[2];
    assign s0_stage44[3] = s0_stage43[3];
    assign s0_stage44[4] = s0_stage43[4];
    assign s0_stage44[5] = s0_stage43[5];
    assign s0_stage44[6] = s0_stage43[6];
    assign s0_stage44[7] = s0_stage43[7];

    wire [7:0] s0_stage45 [0:7];
    assign s0_stage45[0] = s0_stage44[0];
    assign s0_stage45[1] = s0_stage44[1];
    assign s0_stage45[2] = (s0_stage44[2] > s0_stage44[3]) ? s0_stage44[3] : s0_stage44[2];
    assign s0_stage45[3] = (s0_stage44[2] > s0_stage44[3]) ? s0_stage44[2] : s0_stage44[3];
    assign s0_stage45[4] = s0_stage44[4];
    assign s0_stage45[5] = s0_stage44[5];
    assign s0_stage45[6] = s0_stage44[6];
    assign s0_stage45[7] = s0_stage44[7];

    wire [7:0] s0_stage46 [0:7];
    assign s0_stage46[0] = s0_stage45[0];
    assign s0_stage46[1] = s0_stage45[1];
    assign s0_stage46[2] = s0_stage45[2];
    assign s0_stage46[3] = (s0_stage45[3] > s0_stage45[4]) ? s0_stage45[4] : s0_stage45[3];
    assign s0_stage46[4] = (s0_stage45[3] > s0_stage45[4]) ? s0_stage45[3] : s0_stage45[4];
    assign s0_stage46[5] = s0_stage45[5];
    assign s0_stage46[6] = s0_stage45[6];
    assign s0_stage46[7] = s0_stage45[7];

    wire [7:0] s0_stage47 [0:7];
    assign s0_stage47[0] = s0_stage46[0];
    assign s0_stage47[1] = s0_stage46[1];
    assign s0_stage47[2] = s0_stage46[2];
    assign s0_stage47[3] = s0_stage46[3];
    assign s0_stage47[4] = (s0_stage46[4] > s0_stage46[5]) ? s0_stage46[5] : s0_stage46[4];
    assign s0_stage47[5] = (s0_stage46[4] > s0_stage46[5]) ? s0_stage46[4] : s0_stage46[5];
    assign s0_stage47[6] = s0_stage46[6];
    assign s0_stage47[7] = s0_stage46[7];

    wire [7:0] s0_stage48 [0:7];
    assign s0_stage48[0] = s0_stage47[0];
    assign s0_stage48[1] = s0_stage47[1];
    assign s0_stage48[2] = s0_stage47[2];
    assign s0_stage48[3] = s0_stage47[3];
    assign s0_stage48[4] = s0_stage47[4];
    assign s0_stage48[5] = (s0_stage47[5] > s0_stage47[6]) ? s0_stage47[6] : s0_stage47[5];
    assign s0_stage48[6] = (s0_stage47[5] > s0_stage47[6]) ? s0_stage47[5] : s0_stage47[6];
    assign s0_stage48[7] = s0_stage47[7];

    wire [7:0] s0_stage49 [0:7];
    assign s0_stage49[0] = s0_stage48[0];
    assign s0_stage49[1] = s0_stage48[1];
    assign s0_stage49[2] = s0_stage48[2];
    assign s0_stage49[3] = s0_stage48[3];
    assign s0_stage49[4] = s0_stage48[4];
    assign s0_stage49[5] = s0_stage48[5];
    assign s0_stage49[6] = (s0_stage48[6] > s0_stage48[7]) ? s0_stage48[7] : s0_stage48[6];
    assign s0_stage49[7] = (s0_stage48[6] > s0_stage48[7]) ? s0_stage48[6] : s0_stage48[7];

    // Eighth pass of bubble sort
    wire [7:0] s0_stage50 [0:7];
    assign s0_stage50[0] = (s0_stage49[0] > s0_stage49[1]) ? s0_stage49[1] : s0_stage49[0];
    assign s0_stage50[1] = (s0_stage49[0] > s0_stage49[1]) ? s0_stage49[0] : s0_stage49[1];
    assign s0_stage50[2] = s0_stage49[2];
    assign s0_stage50[3] = s0_stage49[3];
    assign s0_stage50[4] = s0_stage49[4];
    assign s0_stage50[5] = s0_stage49[5];
    assign s0_stage50[6] = s0_stage49[6];
    assign s0_stage50[7] = s0_stage49[7];

    wire [7:0] s0_stage51 [0:7];
    assign s0_stage51[0] = s0_stage50[0];
    assign s0_stage51[1] = (s0_stage50[1] > s0_stage50[2]) ? s0_stage50[2] : s0_stage50[1];
    assign s0_stage51[2] = (s0_stage50[1] > s0_stage50[2]) ? s0_stage50[1] : s0_stage50[2];
    assign s0_stage51[3] = s0_stage50[3];
    assign s0_stage51[4] = s0_stage50[4];
    assign s0_stage51[5] = s0_stage50[5];
    assign s0_stage51[6] = s0_stage50[6];
    assign s0_stage51[7] = s0_stage50[7];

    wire [7:0] s0_stage52 [0:7];
    assign s0_stage52[0] = s0_stage51[0];
    assign s0_stage52[1] = s0_stage51[1];
    assign s0_stage52[2] = (s0_stage51[2] > s0_stage51[3]) ? s0_stage51[3] : s0_stage51[2];
    assign s0_stage52[3] = (s0_stage51[2] > s0_stage51[3]) ? s0_stage51[2] : s0_stage51[3];
    assign s0_stage52[4] = s0_stage51[4];
    assign s0_stage52[5] = s0_stage51[5];
    assign s0_stage52[6] = s0_stage51[6];
    assign s0_stage52[7] = s0_stage51[7];

    wire [7:0] s0_stage53 [0:7];
    assign s0_stage53[0] = s0_stage52[0];
    assign s0_stage53[1] = s0_stage52[1];
    assign s0_stage53[2] = s0_stage52[2];
    assign s0_stage53[3] = (s0_stage52[3] > s0_stage52[4]) ? s0_stage52[4] : s0_stage52[3];
    assign s0_stage53[4] = (s0_stage52[3] > s0_stage52[4]) ? s0_stage52[3] : s0_stage52[4];
    assign s0_stage53[5] = s0_stage52[5];
    assign s0_stage53[6] = s0_stage52[6];
    assign s0_stage53[7] = s0_stage52[7];

    wire [7:0] s0_stage54 [0:7];
    assign s0_stage54[0] = s0_stage53[0];
    assign s0_stage54[1] = s0_stage53[1];
    assign s0_stage54[2] = s0_stage53[2];
    assign s0_stage54[3] = s0_stage53[3];
    assign s0_stage54[4] = (s0_stage53[4] > s0_stage53[5]) ? s0_stage53[5] : s0_stage53[4];
    assign s0_stage54[5] = (s0_stage53[4] > s0_stage53[5]) ? s0_stage53[4] : s0_stage53[5];
    assign s0_stage54[6] = s0_stage53[6];
    assign s0_stage54[7] = s0_stage53[7];

    wire [7:0] s0_stage55 [0:7];
    assign s0_stage55[0] = s0_stage54[0];
    assign s0_stage55[1] = s0_stage54[1];
    assign s0_stage55[2] = s0_stage54[2];
    assign s0_stage55[3] = s0_stage54[3];
    assign s0_stage55[4] = s0_stage54[4];
    assign s0_stage55[5] = (s0_stage54[5] > s0_stage54[6]) ? s0_stage54[6] : s0_stage54[5];
    assign s0_stage55[6] = (s0_stage54[5] > s0_stage54[6]) ? s0_stage54[5] : s0_stage54[6];
    assign s0_stage55[7] = s0_stage54[7];

    wire [7:0] s0_stage56 [0:7];
    assign s0_stage56[0] = s0_stage55[0];
    assign s0_stage56[1] = s0_stage55[1];
    assign s0_stage56[2] = s0_stage55[2];
    assign s0_stage56[3] = s0_stage55[3];
    assign s0_stage56[4] = s0_stage55[4];
    assign s0_stage56[5] = s0_stage55[5];
    assign s0_stage56[6] = (s0_stage55[6] > s0_stage55[7]) ? s0_stage55[7] : s0_stage55[6];
    assign s0_stage56[7] = (s0_stage55[6] > s0_stage55[7]) ? s0_stage55[6] : s0_stage55[7];

    // Final sorted s0
    assign s0_sorted[0] = s0_stage56[0];
    assign s0_sorted[1] = s0_stage56[1];
    assign s0_sorted[2] = s0_stage56[2];
    assign s0_sorted[3] = s0_stage56[3];
    assign s0_sorted[4] = s0_stage56[4];
    assign s0_sorted[5] = s0_stage56[5];
    assign s0_sorted[6] = s0_stage56[6];
    assign s0_sorted[7] = s0_stage56[7];

    // Sort s1 using bubble sort (fully unrolled)
    wire [7:0] s1_sorted [0:7];
    assign s1_sorted[0] = s1_chars[0];
    assign s1_sorted[1] = s1_chars[1];
    assign s1_sorted[2] = s1_chars[2];
    assign s1_sorted[3] = s1_chars[3];
    assign s1_sorted[4] = s1_chars[4];
    assign s1_sorted[5] = s1_chars[5];
    assign s1_sorted[6] = s1_chars[6];
    assign s1_sorted[7] = s1_chars[7];

    wire [7:0] s1_stage1 [0:7];
    assign s1_stage1[0] = (s1_sorted[0] > s1_sorted[1]) ? s1_sorted[1] : s1_sorted[0];
    assign s1_stage1[1] = (s1_sorted[0] > s1_sorted[1]) ? s1_sorted[0] : s1_sorted[1];
    assign s1_stage1[2] = s1_sorted[2];
    assign s1_stage1[3] = s1_sorted[3];
    assign s1_stage1[4] = s1_sorted[4];
    assign s1_stage1[5] = s1_sorted[5];
    assign s1_stage1[6] = s1_sorted[6];
    assign s1_stage1[7] = s1_sorted[7];

    wire [7:0] s1_stage2 [0:7];
    assign s1_stage2[0] = s1_stage1[0];
    assign s1_stage2[1] = (s1_stage1[1] > s1_stage1[2]) ? s1_stage1[2] : s1_stage1[1];
    assign s1_stage2[2] = (s1_stage1[1] > s1_stage1[2]) ? s1_stage1[1] : s1_stage1[2];
    assign s1_stage2[3] = s1_stage1[3];
    assign s1_stage2[4] = s1_stage1[4];
    assign s1_stage2[5] = s1_stage1[5];
    assign s1_stage2[6] = s1_stage1[6];
    assign s1_stage2[7] = s1_stage1[7];

    wire [7:0] s1_stage3 [0:7];
    assign s1_stage3[0] = s1_stage2[0];
    assign s1_stage3[1] = s1_stage2[1];
    assign s1_stage3[2] = (s1_stage2[2] > s1_stage2[3]) ? s1_stage2[3] : s1_stage2[2];
    assign s1_stage3[3] = (s1_stage2[2] > s1_stage2[3]) ? s1_stage2[2] : s1_stage2[3];
    assign s1_stage3[4] = s1_stage2[4];
    assign s1_stage3[5] = s1_stage2[5];
    assign s1_stage3[6] = s1_stage2[6];
    assign s1_stage3[7] = s1_stage2[7];

    wire [7:0] s1_stage4 [0:7];
    assign s1_stage4[0] = s1_stage3[0];
    assign s1_stage4[1] = s1_stage3[1];
    assign s1_stage4[2] = s1_stage3[2];
    assign s1_stage4[3] = (s1_stage3[3] > s1_stage3[4]) ? s1_stage3[4] : s1_stage3[3];
    assign s1_stage4[4] = (s1_stage3[3] > s1_stage3[4]) ? s1_stage3[3] : s1_stage3[4];
    assign s1_stage4[5] = s1_stage3[5];
    assign s1_stage4[6] = s1_stage3[6];
    assign s1_stage4[7] = s1_stage3[7];

    wire [7:0] s1_stage5 [0:7];
    assign s1_stage5[0] = s1_stage4[0];
    assign s1_stage5[1] = s1_stage4[1];
    assign s1_stage5[2] = s1_stage4[2];
    assign s1_stage5[3] = s1_stage4[3];
    assign s1_stage5[4] = (s1_stage4[4] > s1_stage4[5]) ? s1_stage4[5] : s1_stage4[4];
    assign s1_stage5[5] = (s1_stage4[4] > s1_stage4[5]) ? s1_stage4[4] : s1_stage4[5];
    assign s1_stage5[6] = s1_stage4[6];
    assign s1_stage5[7] = s1_stage4[7];

    wire [7:0] s1_stage6 [0:7];
    assign s1_stage6[0] = s1_stage5[0];
    assign s1_stage6[1] = s1_stage5[1];
    assign s1_stage6[2] = s1_stage5[2];
    assign s1_stage6[3] = s1_stage5[3];
    assign s1_stage6[4] = s1_stage5[4];
    assign s1_stage6[5] = (s1_stage5[5] > s1_stage5[6]) ? s1_stage5[6] : s1_stage5[5];
    assign s1_stage6[6] = (s1_stage5[5] > s1_stage5[6]) ? s1_stage5[5] : s1_stage5[6];
    assign s1_stage6[7] = s1_stage5[7];

    wire [7:0] s1_stage7 [0:7];
    assign s1_stage7[0] = s1_stage6[0];
    assign s1_stage7[1] = s1_stage6[1];
    assign s1_stage7[2] = s1_stage6[2];
    assign s1_stage7[3] = s1_stage6[3];
    assign s1_stage7[4] = s1_stage6[4];
    assign s1_stage7[5] = s1_stage6[5];
    assign s1_stage7[6] = (s1_stage6[6] > s1_stage6[7]) ? s1_stage6[7] : s1_stage6[6];
    assign s1_stage7[7] = (s1_stage6[6] > s1_stage6[7]) ? s1_stage6[6] : s1_stage6[7];

    // Second pass of bubble sort for s1
    wire [7:0] s1_stage8 [0:7];
    assign s1_stage8[0] = (s1_stage7[0] > s1_stage7[1]) ? s1_stage7[1] : s1_stage7[0];
    assign s1_stage8[1] = (s1_stage7[0] > s1_stage7[1]) ? s1_stage7[0] : s1_stage7[1];
    assign s1_stage8[2] = s1_stage7[2];
    assign s1_stage8[3] = s1_stage7[3];
    assign s1_stage8[4] = s1_stage7[4];
    assign s1_stage8[5] = s1_stage7[5];
    assign s1_stage8[6] = s1_stage7[6];
    assign s1_stage8[7] = s1_stage7[7];

    wire [7:0] s1_stage9 [0:7];
    assign s1_stage9[0] = s1_stage8[0];
    assign s1_stage9[1] = (s1_stage8[1] > s1_stage8[2]) ? s1_stage8[2] : s1_stage8[1];
    assign s1_stage9[2] = (s1_stage8[1] > s1_stage8[2]) ? s1_stage8[1] : s1_stage8[2];
    assign s1_stage9[3] = s1_stage8[3];
    assign s1_stage9[4] = s1_stage8[4];
    assign s1_stage9[5] = s1_stage8[5];
    assign s1_stage9[6] = s1_stage8[6];
    assign s1_stage9[7] = s1_stage8[7];

    wire [7:0] s1_stage10 [0:7];
    assign s1_stage10[0] = s1_stage9[0];
    assign s1_stage10[1] = s1_stage9[1];
    assign s1_stage10[2] = (s1_stage9[2] > s1_stage9[3]) ? s1_stage9[3] : s1_stage9[2];
    assign s1_stage10[3] = (s1_stage9[2] > s1_stage9[3]) ? s1_stage9[2] : s1_stage9[3];
    assign s1_stage10[4] = s1_stage9[4];
    assign s1_stage10[5] = s1_stage9[5];
    assign s1_stage10[6] = s1_stage9[6];
    assign s1_stage10[7] = s1_stage9[7];

    wire [7:0] s1_stage11 [0:7];
    assign s1_stage11[0] = s1_stage10[0];
    assign s1_stage11[1] = s1_stage10[1];
    assign s1_stage11[2] = s1_stage10[2];
    assign s1_stage11[3] = (s1_stage10[3] > s1_stage10[4]) ? s1_stage10[4] : s1_stage10[3];
    assign s1_stage11[4] = (s1_stage10[3] > s1_stage10[4]) ? s1_stage10[3] : s1_stage10[4];
    assign s1_stage11[5] = s1_stage10[5];
    assign s1_stage11[6] = s1_stage10[6];
    assign s1_stage11[7] = s1_stage10[7];

    wire [7:0] s1_stage12 [0:7];
    assign s1_stage12[0] = s1_stage11[0];
    assign s1_stage12[1] = s1_stage11[1];
    assign s1_stage12[2] = s1_stage11[2];
    assign s1_stage12[3] = s1_stage11[3];
    assign s1_stage12[4] = (s1_stage11[4] > s1_stage11[5]) ? s1_stage11[5] : s1_stage11[4];
    assign s1_stage12[5] = (s1_stage11[4] > s1_stage11[5]) ? s1_stage11[4] : s1_stage11[5];
    assign s1_stage12[6] = s1_stage11[6];
    assign s1_stage12[7] = s1_stage11[7];

    wire [7:0] s1_stage13 [0:7];
    assign s1_stage13[0] = s1_stage12[0];
    assign s1_stage13[1] = s1_stage12[1];
    assign s1_stage13[2] = s1_stage12[2];
    assign s1_stage13[3] = s1_stage12[3];
    assign s1_stage13[4] = s1_stage12[4];
    assign s1_stage13[5] = (s1_stage12[5] > s1_stage12[6]) ? s1_stage12[6] : s1_stage12[5];
    assign s1_stage13[6] = (s1_stage12[5] > s1_stage12[6]) ? s1_stage12[5] : s1_stage12[6];
    assign s1_stage13[7] = s1_stage12[7];

    wire [7:0] s1_stage14 [0:7];
    assign s1_stage14[0] = s1_stage13[0];
    assign s1_stage14[1] = s1_stage13[1];
    assign s1_stage14[2] = s1_stage13[2];
    assign s1_stage14[3] = s1_stage13[3];
    assign s1_stage14[4] = s1_stage13[4];
    assign s1_stage14[5] = s1_stage13[5];
    assign s1_stage14[6] = (s1_stage13[6] > s1_stage13[7]) ? s1_stage13[7] : s1_stage13[6];
    assign s1_stage14[7] = (s1_stage13[6] > s1_stage13[7]) ? s1_stage13[6] : s1_stage13[7];

    // Third pass of bubble sort for s1
    wire [7:0] s1_stage15 [0:7];
    assign s1_stage15[0] = (s1_stage14[0] > s1_stage14[1]) ? s1_stage14[1] : s1_stage14[0];
    assign s1_stage15[1] = (s1_stage14[0] > s1_stage14[1]) ? s1_stage14[0] : s1_stage14[1];
    assign s1_stage15[2] = s1_stage14[2];
    assign s1_stage15[3] = s1_stage14[3];
    assign s1_stage15[4] = s1_stage14[4];
    assign s1_stage15[5] = s1_stage14[5];
    assign s1_stage15[6] = s1_stage14[6];
    assign s1_stage15[7] = s1_stage14[7];

    wire [7:0] s1_stage16 [0:7];
    assign s1_stage16[0] = s1_stage15[0];
    assign s1_stage16[1] = (s1_stage15[1] > s1_stage15[2]) ? s1_stage15[2] : s1_stage15[1];
    assign s1_stage16[2] = (s1_stage15[1] > s1_stage15[2]) ? s1_stage15[1] : s1_stage15[2];
    assign s1_stage16[3] = s1_stage15[3];
    assign s1_stage16[4] = s1_stage15[4];
    assign s1_stage16[5] = s1_stage15[5];
    assign s1_stage16[6] = s1_stage15[6];
    assign s1_stage16[7] = s1_stage15[7];

    wire [7:0] s1_stage17 [0:7];
    assign s1_stage17[0] = s1_stage16[0];
    assign s1_stage17[1] = s1_stage16[1];
    assign s1_stage17[2] = (s1_stage16[2] > s1_stage16[3]) ? s1_stage16[3] : s1_stage16[2];
    assign s1_stage17[3] = (s1_stage16[2] > s1_stage16[3]) ? s1_stage16[2] : s1_stage16[3];
    assign s1_stage17[4] = s1_stage16[4];
    assign s1_stage17[5] = s1_stage16[5];
    assign s1_stage17[6] = s1_stage16[6];
    assign s1_stage17[7] = s1_stage16[7];

    wire [7:0] s1_stage18 [0:7];
    assign s1_stage18[0] = s1_stage17[0];
    assign s1_stage18[1] = s1_stage17[1];
    assign s1_stage18[2] = s1_stage17[2];
    assign s1_stage18[3] = (s1_stage17[3] > s1_stage17[4]) ? s1_stage17[4] : s1_stage17[3];
    assign s1_stage18[4] = (s1_stage17[3] > s1_stage17[4]) ? s1_stage17[3] : s1_stage17[4];
    assign s1_stage18[5] = s1_stage17[5];
    assign s1_stage18[6] = s1_stage17[6];
    assign s1_stage18[7] = s1_stage17[7];

    wire [7:0] s1_stage19 [0:7];
    assign s1_stage19[0] = s1_stage18[0];
    assign s1_stage19[1] = s1_stage18[1];
    assign s1_stage19[2] = s1_stage18[2];
    assign s1_stage19[3] = s1_stage18[3];
    assign s1_stage19[4] = (s1_stage18[4] > s1_stage18[5]) ? s1_stage18[5] : s1_stage18[4];
    assign s1_stage19[5] = (s1_stage18[4] > s1_stage18[5]) ? s1_stage18[4] : s1_stage18[5];
    assign s1_stage19[6] = s1_stage18[6];
    assign s1_stage19[7] = s1_stage18[7];

    wire [7:0] s1_stage20 [0:7];
    assign s1_stage20[0] = s1_stage19[0];
    assign s1_stage20[1] = s1_stage19[1];
    assign s1_stage20[2] = s1_stage19[2];
    assign s1_stage20[3] = s1_stage19[3];
    assign s1_stage20[4] = s1_stage19[4];
    assign s1_stage20[5] = (s1_stage19[5] > s1_stage19[6]) ? s1_stage19[6] : s1_stage19[5];
    assign s1_stage20[6] = (s1_stage19[5] > s1_stage19[6]) ? s1_stage19[5] : s1_stage19[6];
    assign s1_stage20[7] = s1_stage19[7];

    wire [7:0] s1_stage21 [0:7];
    assign s1_stage21[0] = s1_stage20[0];
    assign s1_stage21[1] = s1_stage20[1];
    assign s1_stage21[2] = s1_stage20[2];
    assign s1_stage21[3] = s1_stage20[3];
    assign s1_stage21[4] = s1_stage20[4];
    assign s1_stage21[5] = s1_stage20[5];
    assign s1_stage21[6] = (s1_stage20[6] > s1_stage20[7]) ? s1_stage20[7] : s1_stage20[6];
    assign s1_stage21[7] = (s1_stage20[6] > s1_stage20[7]) ? s1_stage20[6] : s1_stage20[7];

    // Fourth pass of bubble sort for s1
    wire [7:0] s1_stage22 [0:7];
    assign s1_stage22[0] = (s1_stage21[0] > s1_stage21[1]) ? s1_stage21[1] : s1_stage21[0];
    assign s1_stage22[1] = (s1_stage21[0] > s1_stage21[1]) ? s1_stage21[0] : s1_stage21[1];
    assign s1_stage22[2] = s1_stage21[2];
    assign s1_stage22[3] = s1_stage21[3];
    assign s1_stage22[4] = s1_stage21[4];
    assign s1_stage22[5] = s1_stage21[5];
    assign s1_stage22[6] = s1_stage21[6];
    assign s1_stage22[7] = s1_stage21[7];

    wire [7:0] s1_stage23 [0:7];
    assign s1_stage23[0] = s1_stage22[0];
    assign s1_stage23[1] = (s1_stage22[1] > s1_stage22[2]) ? s1_stage22[2] : s1_stage22[1];
    assign s1_stage23[2] = (s1_stage22[1] > s1_stage22[2]) ? s1_stage22[1] : s1_stage22[2];
    assign s1_stage23[3] = s1_stage22[3];
    assign s1_stage23[4] = s1_stage22[4];
    assign s1_stage23[5] = s1_stage22[5];
    assign s1_stage23[6] = s1_stage22[6];
    assign s1_stage23[7] = s1_stage22[7];

    wire [7:0] s1_stage24 [0:7];
    assign s1_stage24[0] = s1_stage23[0];
    assign s1_stage24[1] = s1_stage23[1];
    assign s1_stage24[2] = (s1_stage23[2] > s1_stage23[3]) ? s1_stage23[3] : s1_stage23[2];
    assign s1_stage24[3] = (s1_stage23[2] > s1_stage23[3]) ? s1_stage23[2] : s1_stage23[3];
    assign s1_stage24[4] = s1_stage23[4];
    assign s1_stage24[5] = s1_stage23[5];
    assign s1_stage24[6] = s1_stage23[6];
    assign s1_stage24[7] = s1_stage23[7];

    wire [7:0] s1_stage25 [0:7];
    assign s1_stage25[0] = s1_stage24[0];
    assign s1_stage25[1] = s1_stage24[1];
    assign s1_stage25[2] = s1_stage24[2];
    assign s1_stage25[3] = (s1_stage24[3] > s1_stage24[4]) ? s1_stage24[4] : s1_stage24[3];
    assign s1_stage25[4] = (s1_stage24[3] > s1_stage24[4]) ? s1_stage24[3] : s1_stage24[4];
    assign s1_stage25[5] = s1_stage24[5];
    assign s1_stage25[6] = s1_stage24[6];
    assign s1_stage25[7] = s1_stage24[7];

    wire [7:0] s1_stage26 [0:7];
    assign s1_stage26[0] = s1_stage25[0];
    assign s1_stage26[1] = s1_stage25[1];
    assign s1_stage26[2] = s1_stage25[2];
    assign s1_stage26[3] = s1_stage25[3];
    assign s1_stage26[4] = (s1_stage25[4] > s1_stage25[5]) ? s1_stage25[5] : s1_stage25[4];
    assign s1_stage26[5] = (s1_stage25[4] > s1_stage25[5]) ? s1_stage25[4] : s1_stage25[5];
    assign s1_stage26[6] = s1_stage25[6];
    assign s1_stage26[7] = s1_stage25[7];

    wire [7:0] s1_stage27 [0:7];
    assign s1_stage27[0] = s1_stage26[0];
    assign s1_stage27[1] = s1_stage26[1];
    assign s1_stage27[2] = s1_stage26[2];
    assign s1_stage27[3] = s1_stage26[3];
    assign s1_stage27[4] = s1_stage26[4];
    assign s1_stage27[5] = (s1_stage26[5] > s1_stage26[6]) ? s1_stage26[6] : s1_stage26[5];
    assign s1_stage27[6] = (s1_stage26[5] > s1_stage26[6]) ? s1_stage26[5] : s1_stage26[6];
    assign s1_stage27[7] = s1_stage26[7];

    wire [7:0] s1_stage28 [0:7];
    assign s1_stage28[0] = s1_stage27[0];
    assign s1_stage28[1] = s1_stage27[1];
    assign s1_stage28[2] = s1_stage27[2];
    assign s1_stage28[3] = s1_stage27[3];
    assign s1_stage28[4] = s1_stage27[4];
    assign s1_stage28[5] = s1_stage27[5];
    assign s1_stage28[6] = (s1_stage27[6] > s1_stage27[7]) ? s1_stage27[7] : s1_stage27[6];
    assign s1_stage28[7] = (s1_stage27[6] > s1_stage27[7]) ? s1_stage27[6] : s1_stage27[7];

    // Fifth pass of bubble sort for s1
    wire [7:0] s1_stage29 [0:7];
    assign s1_stage29[0] = (s1_stage28[0] > s1_stage28[1]) ? s1_stage28[1] : s1_stage28[0];
    assign s1_stage29[1] = (s1_stage28[0] > s1_stage28[1]) ? s1_stage28[0] : s1_stage28[1];
    assign s1_stage29[2] = s1_stage28[2];
    assign s1_stage29[3] = s1_stage28[3];
    assign s1_stage29[4] = s1_stage28[4];
    assign s1_stage29[5] = s1_stage28[5];
    assign s1_stage29[6] = s1_stage28[6];
    assign s1_stage29[7] = s1_stage28[7];

    wire [7:0] s1_stage30 [0:7];
    assign s1_stage30[0] = s1_stage29[0];
    assign s1_stage30[1] = (s1_stage29[1] > s1_stage29[2]) ? s1_stage29[2] : s1_stage29[1];
    assign s1_stage30[2] = (s1_stage29[1] > s1_stage29[2]) ? s1_stage29[1] : s1_stage29[2];
    assign s1_stage30[3] = s1_stage29[3];
    assign s1_stage30[4] = s1_stage29[4];
    assign s1_stage30[5] = s1_stage29[5];
    assign s1_stage30[6] = s1_stage29[6];
    assign s1_stage30[7] = s1_stage29[7];

    wire [7:0] s1_stage31 [0:7];
    assign s1_stage31[0] = s1_stage30[0];
    assign s1_stage31[1] = s1_stage30[1];
    assign s1_stage31[2] = (s1_stage30[2] > s1_stage30[3]) ? s1_stage30[3] : s1_stage30[2];
    assign s1_stage31[3] = (s1_stage30[2] > s1_stage30[3]) ? s1_stage30[2] : s1_stage30[3];
    assign s1_stage31[4] = s1_stage30[4];
    assign s1_stage31[5] = s1_stage30[5];
    assign s1_stage31[6] = s1_stage30[6];
    assign s1_stage31[7] = s1_stage30[7];

    wire [7:0] s1_stage32 [0:7];
    assign s1_stage32[0] = s1_stage31[0];
    assign s1_stage32[1] = s1_stage31[1];
    assign s1_stage32[2] = s1_stage31[2];
    assign s1_stage32[3] = (s1_stage31[3] > s1_stage31[4]) ? s1_stage31[4] : s1_stage31[3];
    assign s1_stage32[4] = (s1_stage31[3] > s1_stage31[4]) ? s1_stage31[3] : s1_stage31[4];
    assign s1_stage32[5] = s1_stage31[5];
    assign s1_stage32[6] = s1_stage31[6];
    assign s1_stage32[7] = s1_stage31[7];

    wire [7:0] s1_stage33 [0:7];
    assign s1_stage33[0] = s1_stage32[0];
    assign s1_stage33[1] = s1_stage32[1];
    assign s1_stage33[2] = s1_stage32[2];
    assign s1_stage33[3] = s1_stage32[3];
    assign s1_stage33[4] = (s1_stage32[4] > s1_stage32[5]) ? s1_stage32[5] : s1_stage32[4];
    assign s1_stage33[5] = (s1_stage32[4] > s1_stage32[5]) ? s1_stage32[4] : s1_stage32[5];
    assign s1_stage33[6] = s1_stage32[6];
    assign s1_stage33[7] = s1_stage32[7];

    wire [7:0] s1_stage34 [0:7];
    assign s1_stage34[0] = s1_stage33[0];
    assign s1_stage34[1] = s1_stage33[1];
    assign s1_stage34[2] = s1_stage33[2];
    assign s1_stage34[3] = s1_stage33[3];
    assign s1_stage34[4] = s1_stage33[4];
    assign s1_stage34[5] = (s1_stage33[5] > s1_stage33[6]) ? s1_stage33[6] : s1_stage33[5];
    assign s1_stage34[6] = (s1_stage33[5] > s1_stage33[6]) ? s1_stage33[5] : s1_stage33[6];
    assign s1_stage34[7] = s1_stage33[7];

    wire [7:0] s1_stage35 [0:7];
    assign s1_stage35[0] = s1_stage34[0];
    assign s1_stage35[1] = s1_stage34[1];
    assign s1_stage35[2] = s1_stage34[2];
    assign s1_stage35[3] = s1_stage34[3];
    assign s1_stage35[4] = s1_stage34[4];
    assign s1_stage35[5] = s1_stage34[5];
    assign s1_stage35[6] = (s1_stage34[6] > s1_stage34[7]) ? s1_stage34[7] : s1_stage34[6];
    assign s1_stage35[7] = (s1_stage34[6] > s1_stage34[7]) ? s1_stage34[6] : s1_stage34[7];

    // Sixth pass of bubble sort for s1
    wire [7:0] s1_stage36 [0:7];
    assign s1_stage36[0] = (s1_stage35[0] > s1_stage35[1]) ? s1_stage35[1] : s1_stage35[0];
    assign s1_stage36[1] = (s1_stage35[0] > s1_stage35[1]) ? s1_stage35[0] : s1_stage35[1];
    assign s1_stage36[2] = s1_stage35[2];
    assign s1_stage36[3] = s1_stage35[3];
    assign s1_stage36[4] = s1_stage35[4];
    assign s1_stage36[5] = s1_stage35[5];
    assign s1_stage36[6] = s1_stage35[6];
    assign s1_stage36[7] = s1_stage35[7];

    wire [7:0] s1_stage37 [0:7];
    assign s1_stage37[0] = s1_stage36[0];
    assign s1_stage37[1] = (s1_stage36[1] > s1_stage36[2]) ? s1_stage36[2] : s1_stage36[1];
    assign s1_stage37[2] = (s1_stage36[1] > s1_stage36[2]) ? s1_stage36[1] : s1_stage36[2];
    assign s1_stage37[3] = s1_stage36[3];
    assign s1_stage37[4] = s1_stage36[4];
    assign s1_stage37[5] = s1_stage36[5];
    assign s1_stage37[6] = s1_stage36[6];
    assign s1_stage37[7] = s1_stage36[7];

    wire [7:0] s1_stage38 [0:7];
    assign s1_stage38[0] = s1_stage37[0];
    assign s1_stage38[1] = s1_stage37[1];
    assign s1_stage38[2] = (s1_stage37[2] > s1_stage37[3]) ? s1_stage37[3] : s1_stage37[2];
    assign s1_stage38[3] = (s1_stage37[2] > s1_stage37[3]) ? s1_stage37[2] : s1_stage37[3];
    assign s1_stage38[4] = s1_stage37[4];
    assign s1_stage38[5] = s1_stage37[5];
    assign s1_stage38[6] = s1_stage37[6];
    assign s1_stage38[7] = s1_stage37[7];

    wire [7:0] s1_stage39 [0:7];
    assign s1_stage39[0] = s1_stage38[0];
    assign s1_stage39[1] = s1_stage38[1];
    assign s1_stage39[2] = s1_stage38[2];
    assign s1_stage39[3] = (s1_stage38[3] > s1_stage38[4]) ? s1_stage38[4] : s1_stage38[3];
    assign s1_stage39[4] = (s1_stage38[3] > s1_stage38[4]) ? s1_stage38[3] : s1_stage38[4];
    assign s1_stage39[5] = s1_stage38[5];
    assign s1_stage39[6] = s1_stage38[6];
    assign s1_stage39[7] = s1_stage38[7];

    wire [7:0] s1_stage40 [0:7];
    assign s1_stage40[0] = s1_stage39[0];
    assign s1_stage40[1] = s1_stage39[1];
    assign s1_stage40[2] = s1_stage39[2];
    assign s1_stage40[3] = s1_stage39[3];
    assign s1_stage40[4] = (s1_stage39[4] > s1_stage39[5]) ? s1_stage39[5] : s1_stage39[4];
    assign s1_stage40[5] = (s1_stage39[4] > s1_stage39[5]) ? s1_stage39[4] : s1_stage39[5];
    assign s1_stage40[6] = s1_stage39[6];
    assign s1_stage40[7] = s1_stage39[7];

    wire [7:0] s1_stage41 [0:7];
    assign s1_stage41[0] = s1_stage40[0];
    assign s1_stage41[1] = s1_stage40[1];
    assign s1_stage41[2] = s1_stage40[2];
    assign s1_stage41[3] = s1_stage40[3];
    assign s1_stage41[4] = s1_stage40[4];
    assign s1_stage41[5] = (s1_stage40[5] > s1_stage40[6]) ? s1_stage40[6] : s1_stage40[5];
    assign s1_stage41[6] = (s1_stage40[5] > s1_stage40[6]) ? s1_stage40[5] : s1_stage40[6];
    assign s1_stage41[7] = s1_stage40[7];

    wire [7:0] s1_stage42 [0:7];
    assign s1_stage42[0] = s1_stage41[0];
    assign s1_stage42[1] = s1_stage41[1];
    assign s1_stage42[2] = s1_stage41[2];
    assign s1_stage42[3] = s1_stage41[3];
    assign s1_stage42[4] = s1_stage41[4];
    assign s1_stage42[5] = s1_stage41[5];
    assign s1_stage42[6] = (s1_stage41[6] > s1_stage41[7]) ? s1_stage41[7] : s1_stage41[6];
    assign s1_stage42[7] = (s1_stage41[6] > s1_stage41[7]) ? s1_stage41[6] : s1_stage41[7];

    // Seventh pass of bubble sort for s1
    wire [7:0] s1_stage43 [0:7];
    assign s1_stage43[0] = (s1_stage42[0] > s1_stage42[1]) ? s1_stage42[1] : s1_stage42[0];
    assign s1_stage43[1] = (s1_stage42[0] > s1_stage42[1]) ? s1_stage42[0] : s1_stage42[1];
    assign s1_stage43[2] = s1_stage42[2];
    assign s1_stage43[3] = s1_stage42[3];
    assign s1_stage43[4] = s1_stage42[4];
    assign s1_stage43[5] = s1_stage42[5];
    assign s1_stage43[6] = s1_stage42[6];
    assign s1_stage43[7] = s1_stage42[7];

    wire [7:0] s1_stage44 [0:7];
    assign s1_stage44[0] = s1_stage43[0];
    assign s1_stage44[1] = (s1_stage43[1] > s1_stage43[2]) ? s1_stage43[2] : s1_stage43[1];
    assign s1_stage44[2] = (s1_stage43[1] > s1_stage43[2]) ? s1_stage43[1] : s1_stage43[2];
    assign s1_stage44[3] = s1_stage43[3];
    assign s1_stage44[4] = s1_stage43[4];
    assign s1_stage44[5] = s1_stage43[5];
    assign s1_stage44[6] = s1_stage43[6];
    assign s1_stage44[7] = s1_stage43[7];

    wire [7:0] s1_stage45 [0:7];
    assign s1_stage45[0] = s1_stage44[0];
    assign s1_stage45[1] = s1_stage44[1];
    assign s1_stage45[2] = (s1_stage44[2] > s1_stage44[3]) ? s1_stage44[3] : s1_stage44[2];
    assign s1_stage45[3] = (s1_stage44[2] > s1_stage44[3]) ? s1_stage44[2] : s1_stage44[3];
    assign s1_stage45[4] = s1_stage44[4];
    assign s1_stage45[5] = s1_stage44[5];
    assign s1_stage45[6] = s1_stage44[6];
    assign s1_stage45[7] = s1_stage44[7];

    wire [7:0] s1_stage46 [0:7];
    assign s1_stage46[0] = s1_stage45[0];
    assign s1_stage46[1] = s1_stage45[1];
    assign s1_stage46[2] = s1_stage45[2];
    assign s1_stage46[3] = (s1_stage45[3] > s1_stage45[4]) ? s1_stage45[4] : s1_stage45[3];
    assign s1_stage46[4] = (s1_stage45[3] > s1_stage45[4]) ? s1_stage45[3] : s1_stage45[4];
    assign s1_stage46[5] = s1_stage45[5];
    assign s1_stage46[6] = s1_stage45[6];
    assign s1_stage46[7] = s1_stage45[7];

    wire [7:0] s1_stage47 [0:7];
    assign s1_stage47[0] = s1_stage46[0];
    assign s1_stage47[1] = s1_stage46[1];
    assign s1_stage47[2] = s1_stage46[2];
    assign s1_stage47[3] = s1_stage46[3];
    assign s1_stage47[4] = (s1_stage46[4] > s1_stage46[5]) ? s1_stage46[5] : s1_stage46[4];
    assign s1_stage47[5] = (s1_stage46[4] > s1_stage46[5]) ? s1_stage46[4] : s1_stage46[5];
    assign s1_stage47[6] = s1_stage46[6];
    assign s1_stage47[7] = s1_stage46[7];

    wire [7:0] s1_stage48 [0:7];
    assign s1_stage48[0] = s1_stage47[0];
    assign s1_stage48[1] = s1_stage47[1];
    assign s1_stage48[2] = s1_stage47[2];
    assign s1_stage48[3] = s1_stage47[3];
    assign s1_stage48[4] = s1_stage47[4];
    assign s1_stage48[5] = (s1_stage47[5] > s1_stage47[6]) ? s1_stage47[6] : s1_stage47[5];
    assign s1_stage48[6] = (s1_stage47[5] > s1_stage47[6]) ? s1_stage47[5] : s1_stage47[6];
    assign s1_stage48[7] = s1_stage47[7];

    wire [7:0] s1_stage49 [0:7];
    assign s1_stage49[0] = s1_stage48[0];
    assign s1_stage49[1] = s1_stage48[1];
    assign s1_stage49[2] = s1_stage48[2];
    assign s1_stage49[3] = s1_stage48[3];
    assign s1_stage49[4] = s1_stage48[4];
    assign s1_stage49[5] = s1_stage48[5];
    assign s1_stage49[6] = (s1_stage48[6] > s1_stage48[7]) ? s1_stage48[7] : s1_stage48[6];
    assign s1_stage49[7] = (s1_stage48[6] > s1_stage48[7]) ? s1_stage48[6] : s1_stage48[7];

    // Eighth pass of bubble sort for s1
    wire [7:0] s1_stage50 [0:7];
    assign s1_stage50[0] = (s1_stage49[0] > s1_stage49[1]) ? s1_stage49[1] : s1_stage49[0];
    assign s1_stage50[1] = (s1_stage49[0] > s1_stage49[1]) ? s1_stage49[0] : s1_stage49[1];
    assign s1_stage50[2] = s1_stage49[2];
    assign s1_stage50[3] = s1_stage49[3];
    assign s1_stage50[4] = s1_stage49[4];
    assign s1_stage50[5] = s1_stage49[5];
    assign s1_stage50[6] = s1_stage49[6];
    assign s1_stage50[7] = s1_stage49[7];

    wire [7:0] s1_stage51 [0:7];
    assign s1_stage51[0] = s1_stage50[0];
    assign s1_stage51[1] = (s1_stage50[1] > s1_stage50[2]) ? s1_stage50[2] : s1_stage50[1];
    assign s1_stage51[2] = (s1_stage50[1] > s1_stage50[2]) ? s1_stage50[1] : s1_stage50[2];
    assign s1_stage51[3] = s1_stage50[3];
    assign s1_stage51[4] = s1_stage50[4];
    assign s1_stage51[5] = s1_stage50[5];
    assign s1_stage51[6] = s1_stage50[6];
    assign s1_stage51[7] = s1_stage50[7];

    wire [7:0] s1_stage52 [0:7];
    assign s1_stage52[0] = s1_stage51[0];
    assign s1_stage52[1] = s1_stage51[1];
    assign s1_stage52[2] = (s1_stage51[2] > s1_stage51[3]) ? s1_stage51[3] : s1_stage51[2];
    assign s1_stage52[3] = (s1_stage51[2] > s1_stage51[3]) ? s1_stage51[2] : s1_stage51[3];
    assign s1_stage52[4] = s1_stage51[4];
    assign s1_stage52[5] = s1_stage51[5];
    assign s1_stage52[6] = s1_stage51[6];
    assign s1_stage52[7] = s1_stage51[7];

    wire [7:0] s1_stage53 [0:7];
    assign s1_stage53[0] = s1_stage52[0];
    assign s1_stage53[1] = s1_stage52[1];
    assign s1_stage53[2] = s1_stage52[2];
    assign s1_stage53[3] = (s1_stage52[3] > s1_stage52[4]) ? s1_stage52[4] : s1_stage52[3];
    assign s1_stage53[4] = (s1_stage52[3] > s1_stage52[4]) ? s1_stage52[3] : s1_stage52[4];
    assign s1_stage53[5] = s1_stage52[5];
    assign s1_stage53[6] = s1_stage52[6];
    assign s1_stage53[7] = s1_stage52[7];

    wire [7:0] s1_stage54 [0:7];
    assign s1_stage54[0] = s1_stage53[0];
    assign s1_stage54[1] = s1_stage53[1];
    assign s1_stage54[2] = s1_stage53[2];
    assign s1_stage54[3] = s1_stage53[3];
    assign s1_stage54[4] = (s1_stage53[4] > s1_stage53[5]) ? s1_stage53[5] : s1_stage53[4];
    assign s1_stage54[5] = (s1_stage53[4] > s1_stage53[5]) ? s1_stage53[4] : s1_stage53[5];
    assign s1_stage54[6] = s1_stage53[6];
    assign s1_stage54[7] = s1_stage53[7];

    wire [7:0] s1_stage55 [0:7];
    assign s1_stage55[0] = s1_stage54[0];
    assign s1_stage55[1] = s1_stage54[1];
    assign s1_stage55[2] = s1_stage54[2];
    assign s1_stage55[3] = s1_stage54[3];
    assign s1_stage55[4] = s1_stage54[4];
    assign s1_stage55[5] = (s1_stage54[5] > s1_stage54[6]) ? s1_stage54[6] : s1_stage54[5];
    assign s1_stage55[6] = (s1_stage54[5] > s1_stage54[6]) ? s1_stage54[5] : s1_stage54[6];
    assign s1_stage55[7] = s1_stage54[7];

    wire [7:0] s1_stage56 [0:7];
    assign s1_stage56[0] = s1_stage55[0];
    assign s1_stage56[1] = s1_stage55[1];
    assign s1_stage56[2] = s1_stage55[2];
    assign s1_stage56[3] = s1_stage55[3];
    assign s1_stage56[4] = s1_stage55[4];
    assign s1_stage56[5] = s1_stage55[5];
    assign s1_stage56[6] = (s1_stage55[6] > s1_stage55[7]) ? s1_stage55[7] : s1_stage55[6];
    assign s1_stage56[7] = (s1_stage55[6] > s1_stage55[7]) ? s1_stage55[6] : s1_stage55[7];

    // Final sorted s1
    assign s1_sorted[0] = s1_stage56[0];
    assign s1_sorted[1] = s1_stage56[1];
    assign s1_sorted[2] = s1_stage56[2];
    assign s1_sorted[3] = s1_stage56[3];
    assign s1_sorted[4] = s1_stage56[4];
    assign s1_sorted[5] = s1_stage56[5];
    assign s1_sorted[6] = s1_stage56[6];
    assign s1_sorted[7] = s1_stage56[7];

    // Compare sorted arrays
    wire match0 = (s0_sorted[0] == s1_sorted[0]);
    wire match1 = (s0_sorted[1] == s1_sorted[1]);
    wire match2 = (s0_sorted[2] == s1_sorted[2]);
    wire match3 = (s0_sorted[3] == s1_sorted[3]);
    wire match4 = (s0_sorted[4] == s1_sorted[4]);
    wire match5 = (s0_sorted[5] == s1_sorted[5]);
    wire match6 = (s0_sorted[6] == s1_sorted[6]);
    wire match7 = (s0_sorted[7] == s1_sorted[7]);

    assign result = match0 & match1 & match2 & match3 & match4 & match5 & match6 & match7;

endmodule