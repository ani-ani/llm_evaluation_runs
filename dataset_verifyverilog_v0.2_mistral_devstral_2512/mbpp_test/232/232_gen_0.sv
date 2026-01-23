module largest_n_finder (
    input [7:0] data_in [0:7],
    input [2:0] n,
    output reg [7:0] result [0:3]
);

    // Internal wires for sorting network stages
    reg [7:0] stage0 [0:7];
    reg [7:0] stage1 [0:7];
    reg [7:0] stage2 [0:7];
    reg [7:0] stage3 [0:7];
    reg [7:0] stage4 [0:7];
    reg [7:0] stage5 [0:7];
    reg [7:0] stage6 [0:7];
    reg [7:0] stage7 [0:7];
    reg [7:0] stage8 [0:7];
    reg [7:0] stage9 [0:7];
    reg [7:0] stage10 [0:7];
    reg [7:0] stage11 [0:7];
    reg [7:0] stage12 [0:7];
    reg [7:0] stage13 [0:7];
    reg [7:0] stage14 [0:7];
    reg [7:0] stage15 [0:7];
    reg [7:0] stage16 [0:7];
    reg [7:0] stage17 [0:7];
    reg [7:0] stage18 [0:7];
    reg [7:0] stage19 [0:7];

    // Stage 0: Initial assignment
    always @* begin
        stage0[0] = data_in[0];
        stage0[1] = data_in[1];
        stage0[2] = data_in[2];
        stage0[3] = data_in[3];
        stage0[4] = data_in[4];
        stage0[5] = data_in[5];
        stage0[6] = data_in[6];
        stage0[7] = data_in[7];
    end

    // Stage 1: Compare and swap (0,1), (2,3), (4,5), (6,7)
    always @* begin
        stage1[0] = (stage0[0] > stage0[1]) ? stage0[0] : stage0[1];
        stage1[1] = (stage0[0] > stage0[1]) ? stage0[1] : stage0[0];
        stage1[2] = (stage0[2] > stage0[3]) ? stage0[2] : stage0[3];
        stage1[3] = (stage0[2] > stage0[3]) ? stage0[3] : stage0[2];
        stage1[4] = (stage0[4] > stage0[5]) ? stage0[4] : stage0[5];
        stage1[5] = (stage0[4] > stage0[5]) ? stage0[5] : stage0[4];
        stage1[6] = (stage0[6] > stage0[7]) ? stage0[6] : stage0[7];
        stage1[7] = (stage0[6] > stage0[7]) ? stage0[7] : stage0[6];
    end

    // Stage 2: Compare and swap (0,2), (1,3), (4,6), (5,7)
    always @* begin
        stage2[0] = (stage1[0] > stage1[2]) ? stage1[0] : stage1[2];
        stage2[1] = (stage1[1] > stage1[3]) ? stage1[1] : stage1[3];
        stage2[2] = (stage1[0] > stage1[2]) ? stage1[2] : stage1[0];
        stage2[3] = (stage1[1] > stage1[3]) ? stage1[3] : stage1[1];
        stage2[4] = (stage1[4] > stage1[6]) ? stage1[4] : stage1[6];
        stage2[5] = (stage1[5] > stage1[7]) ? stage1[5] : stage1[7];
        stage2[6] = (stage1[4] > stage1[6]) ? stage1[6] : stage1[4];
        stage2[7] = (stage1[5] > stage1[7]) ? stage1[7] : stage1[5];
    end

    // Stage 3: Compare and swap (0,4), (1,5), (2,6), (3,7)
    always @* begin
        stage3[0] = (stage2[0] > stage2[4]) ? stage2[0] : stage2[4];
        stage3[1] = (stage2[1] > stage2[5]) ? stage2[1] : stage2[5];
        stage3[2] = (stage2[2] > stage2[6]) ? stage2[2] : stage2[6];
        stage3[3] = (stage2[3] > stage2[7]) ? stage2[3] : stage2[7];
        stage3[4] = (stage2[0] > stage2[4]) ? stage2[4] : stage2[0];
        stage3[5] = (stage2[1] > stage2[5]) ? stage2[5] : stage2[1];
        stage3[6] = (stage2[2] > stage2[6]) ? stage2[6] : stage2[2];
        stage3[7] = (stage2[3] > stage2[7]) ? stage2[7] : stage2[3];
    end

    // Stage 4: Compare and swap (0,1), (2,3), (4,5), (6,7)
    always @* begin
        stage4[0] = (stage3[0] > stage3[1]) ? stage3[0] : stage3[1];
        stage4[1] = (stage3[0] > stage3[1]) ? stage3[1] : stage3[0];
        stage4[2] = (stage3[2] > stage3[3]) ? stage3[2] : stage3[3];
        stage4[3] = (stage3[2] > stage3[3]) ? stage3[3] : stage3[2];
        stage4[4] = (stage3[4] > stage3[5]) ? stage3[4] : stage3[5];
        stage4[5] = (stage3[4] > stage3[5]) ? stage3[5] : stage3[4];
        stage4[6] = (stage3[6] > stage3[7]) ? stage3[6] : stage3[7];
        stage4[7] = (stage3[6] > stage3[7]) ? stage3[7] : stage3[6];
    end

    // Stage 5: Compare and swap (1,2), (5,6)
    always @* begin
        stage5[0] = stage4[0];
        stage5[1] = (stage4[1] > stage4[2]) ? stage4[1] : stage4[2];
        stage5[2] = (stage4[1] > stage4[2]) ? stage4[2] : stage4[1];
        stage5[3] = stage4[3];
        stage5[4] = stage4[4];
        stage5[5] = (stage4[5] > stage4[6]) ? stage4[5] : stage4[6];
        stage5[6] = (stage4[5] > stage4[6]) ? stage4[6] : stage4[5];
        stage5[7] = stage4[7];
    end

    // Stage 6: Compare and swap (0,1), (2,3), (4,5), (6,7)
    always @* begin
        stage6[0] = (stage5[0] > stage5[1]) ? stage5[0] : stage5[1];
        stage6[1] = (stage5[0] > stage5[1]) ? stage5[1] : stage5[0];
        stage6[2] = (stage5[2] > stage5[3]) ? stage5[2] : stage5[3];
        stage6[3] = (stage5[2] > stage5[3]) ? stage5[3] : stage5[2];
        stage6[4] = (stage5[4] > stage5[5]) ? stage5[4] : stage5[5];
        stage6[5] = (stage5[4] > stage5[5]) ? stage5[5] : stage5[4];
        stage6[6] = (stage5[6] > stage5[7]) ? stage5[6] : stage5[7];
        stage6[7] = (stage5[6] > stage5[7]) ? stage5[7] : stage5[6];
    end

    // Stage 7: Compare and swap (1,4), (3,6)
    always @* begin
        stage7[0] = stage6[0];
        stage7[1] = (stage6[1] > stage6[4]) ? stage6[1] : stage6[4];
        stage7[2] = stage6[2];
        stage7[3] = (stage6[3] > stage6[6]) ? stage6[3] : stage6[6];
        stage7[4] = (stage6[1] > stage6[4]) ? stage6[4] : stage6[1];
        stage7[5] = stage6[5];
        stage7[6] = (stage6[3] > stage6[6]) ? stage6[6] : stage6[3];
        stage7[7] = stage6[7];
    end

    // Stage 8: Compare and swap (2,4), (3,5)
    always @* begin
        stage8[0] = stage7[0];
        stage8[1] = stage7[1];
        stage8[2] = (stage7[2] > stage7[4]) ? stage7[2] : stage7[4];
        stage8[3] = (stage7[3] > stage7[5]) ? stage7[3] : stage7[5];
        stage8[4] = (stage7[2] > stage7[4]) ? stage7[4] : stage7[2];
        stage8[5] = (stage7[3] > stage7[5]) ? stage7[5] : stage7[3];
        stage8[6] = stage7[6];
        stage8[7] = stage7[7];
    end

    // Stage 9: Compare and swap (1,2), (3,4), (5,6)
    always @* begin
        stage9[0] = stage8[0];
        stage9[1] = (stage8[1] > stage8[2]) ? stage8[1] : stage8[2];
        stage9[2] = (stage8[1] > stage8[2]) ? stage8[2] : stage8[1];
        stage9[3] = (stage8[3] > stage8[4]) ? stage8[3] : stage8[4];
        stage9[4] = (stage8[3] > stage8[4]) ? stage8[4] : stage8[3];
        stage9[5] = (stage8[5] > stage8[6]) ? stage8[5] : stage8[6];
        stage9[6] = (stage8[5] > stage8[6]) ? stage8[6] : stage8[5];
        stage9[7] = stage8[7];
    end

    // Stage 10: Compare and swap (0,1), (2,3), (4,5), (6,7)
    always @* begin
        stage10[0] = (stage9[0] > stage9[1]) ? stage9[0] : stage9[1];
        stage10[1] = (stage9[0] > stage9[1]) ? stage9[1] : stage9[0];
        stage10[2] = (stage9[2] > stage9[3]) ? stage9[2] : stage9[3];
        stage10[3] = (stage9[2] > stage9[3]) ? stage9[3] : stage9[2];
        stage10[4] = (stage9[4] > stage9[5]) ? stage9[4] : stage9[5];
        stage10[5] = (stage9[4] > stage9[5]) ? stage9[5] : stage9[4];
        stage10[6] = (stage9[6] > stage9[7]) ? stage9[6] : stage9[7];
        stage10[7] = (stage9[6] > stage9[7]) ? stage9[7] : stage9[6];
    end

    // Stage 11: Compare and swap (1,2), (3,5), (4,6)
    always @* begin
        stage11[0] = stage10[0];
        stage11[1] = (stage10[1] > stage10[2]) ? stage10[1] : stage10[2];
        stage11[2] = (stage10[1] > stage10[2]) ? stage10[2] : stage10[1];
        stage11[3] = (stage10[3] > stage10[5]) ? stage10[3] : stage10[5];
        stage11[4] = (stage10[4] > stage10[6]) ? stage10[4] : stage10[6];
        stage11[5] = (stage10[3] > stage10[5]) ? stage10[5] : stage10[3];
        stage11[6] = (stage10[4] > stage10[6]) ? stage10[6] : stage10[4];
        stage11[7] = stage10[7];
    end

    // Stage 12: Compare and swap (2,3), (4,5)
    always @* begin
        stage12[0] = stage11[0];
        stage12[1] = stage11[1];
        stage12[2] = (stage11[2] > stage11[3]) ? stage11[2] : stage11[3];
        stage12[3] = (stage11[2] > stage11[3]) ? stage11[3] : stage11[2];
        stage12[4] = (stage11[4] > stage11[5]) ? stage11[4] : stage11[5];
        stage12[5] = (stage11[4] > stage11[5]) ? stage11[5] : stage11[4];
        stage12[6] = stage11[6];
        stage12[7] = stage11[7];
    end

    // Stage 13: Compare and swap (1,4), (2,5), (3,6)
    always @* begin
        stage13[0] = stage12[0];
        stage13[1] = (stage12[1] > stage12[4]) ? stage12[1] : stage12[4];
        stage13[2] = (stage12[2] > stage12[5]) ? stage12[2] : stage12[5];
        stage13[3] = (stage12[3] > stage12[6]) ? stage12[3] : stage12[6];
        stage13[4] = (stage12[1] > stage12[4]) ? stage12[4] : stage12[1];
        stage13[5] = (stage12[2] > stage12[5]) ? stage12[5] : stage12[2];
        stage13[6] = (stage12[3] > stage12[6]) ? stage12[6] : stage12[3];
        stage13[7] = stage12[7];
    end

    // Stage 14: Compare and swap (0,1), (2,3), (4,5), (6,7)
    always @* begin
        stage14[0] = (stage13[0] > stage13[1]) ? stage13[0] : stage13[1];
        stage14[1] = (stage13[0] > stage13[1]) ? stage13[1] : stage13[0];
        stage14[2] = (stage13[2] > stage13[3]) ? stage13[2] : stage13[3];
        stage14[3] = (stage13[2] > stage13[3]) ? stage13[3] : stage13[2];
        stage14[4] = (stage13[4] > stage13[5]) ? stage13[4] : stage13[5];
        stage14[5] = (stage13[4] > stage13[5]) ? stage13[5] : stage13[4];
        stage14[6] = (stage13[6] > stage13[7]) ? stage13[6] : stage13[7];
        stage14[7] = (stage13[6] > stage13[7]) ? stage13[7] : stage13[6];
    end

    // Stage 15: Compare and swap (1,2), (3,4), (5,6)
    always @* begin
        stage15[0] = stage14[0];
        stage15[1] = (stage14[1] > stage14[2]) ? stage14[1] : stage14[2];
        stage15[2] = (stage14[1] > stage14[2]) ? stage14[2] : stage14[1];
        stage15[3] = (stage14[3] > stage14[4]) ? stage14[3] : stage14[4];
        stage15[4] = (stage14[3] > stage14[4]) ? stage14[4] : stage14[3];
        stage15[5] = (stage14[5] > stage14[6]) ? stage14[5] : stage14[6];
        stage15[6] = (stage14[5] > stage14[6]) ? stage14[6] : stage14[5];
        stage15[7] = stage14[7];
    end

    // Stage 16: Compare and swap (2,3), (4,5)
    always @* begin
        stage16[0] = stage15[0];
        stage16[1] = stage15[1];
        stage16[2] = (stage15[2] > stage15[3]) ? stage15[2] : stage15[3];
        stage16[3] = (stage15[2] > stage15[3]) ? stage15[3] : stage15[2];
        stage16[4] = (stage15[4] > stage15[5]) ? stage15[4] : stage15[5];
        stage16[5] = (stage15[4] > stage15[5]) ? stage15[5] : stage15[4];
        stage16[6] = stage15[6];
        stage16[7] = stage15[7];
    end

    // Stage 17: Compare and swap (1,2), (3,4), (5,6)
    always @* begin
        stage17[0] = stage16[0];
        stage17[1] = (stage16[1] > stage16[2]) ? stage16[1] : stage16[2];
        stage17[2] = (stage16[1] > stage16[2]) ? stage16[2] : stage16[1];
        stage17[3] = (stage16[3] > stage16[4]) ? stage16[3] : stage16[4];
        stage17[4] = (stage16[3] > stage16[4]) ? stage16[4] : stage16[3];
        stage17[5] = (stage16[5] > stage16[6]) ? stage16[5] : stage16[6];
        stage17[6] = (stage16[5] > stage16[6]) ? stage16[6] : stage16[5];
        stage17[7] = stage16[7];
    end

    // Stage 18: Compare and swap (2,3), (4,5)
    always @* begin
        stage18[0] = stage17[0];
        stage18[1] = stage17[1];
        stage18[2] = (stage17[2] > stage17[3]) ? stage17[2] : stage17[3];
        stage18[3] = (stage17[2] > stage17[3]) ? stage17[3] : stage17[2];
        stage18[4] = (stage17[4] > stage17[5]) ? stage17[4] : stage17[5];
        stage18[5] = (stage17[4] > stage17[5]) ? stage17[5] : stage17[4];
        stage18[6] = stage17[6];
        stage18[7] = stage17[7];
    end

    // Stage 19: Compare and swap (3,4)
    always @* begin
        stage19[0] = stage18[0];
        stage19[1] = stage18[1];
        stage19[2] = stage18[2];
        stage19[3] = (stage18[3] > stage18[4]) ? stage18[3] : stage18[4];
        stage19[4] = (stage18[3] > stage18[4]) ? stage18[4] : stage18[3];
        stage19[5] = stage18[5];
        stage19[6] = stage18[6];
        stage19[7] = stage18[7];
    end

    // Final selection of n largest elements
    always @* begin
        result[0] = (n >= 1) ? stage19[0] : 8'b0;
        result[1] = (n >= 2) ? stage19[1] : 8'b0;
        result[2] = (n >= 3) ? stage19[2] : 8'b0;
        result[3] = (n >= 4) ? stage19[3] : 8'b0;
    end

endmodule