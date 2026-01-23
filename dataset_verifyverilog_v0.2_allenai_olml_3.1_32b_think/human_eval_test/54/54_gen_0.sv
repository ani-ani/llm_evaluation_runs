module same_chars(
    input [63:0] s0,
    input [63:0] s1,
    output result
);

    reg [7:0] s0_chars [7:0];
    reg [7:0] s1_chars [7:0];

    always @(*) begin
        s0_chars[0] = s0[63:56];
        s0_chars[1] = s0[55:48];
        s0_chars[2] = s0[47:40];
        s0_chars[3] = s0[39:32];
        s0_chars[4] = s0[31:24];
        s0_chars[5] = s0[23:16];
        s0_chars[6] = s0[15:8];
        s0_chars[7] = s0[7:0];

        s1_chars[0] = s1[63:56];
        s1_chars[1] = s1[55:48];
        s1_chars[2] = s1[47:40];
        s1_chars[3] = s1[39:32];
        s1_chars[4] = s1[31:24];
        s1_chars[5] = s1[23:16];
        s1_chars[6] = s1[15:8];
        s1_chars[7] = s1[7:0];

        reg [7:0] s0_stage1 [7:0];
        s0_stage1[0] = (s0_chars[0] > s0_chars[1]) ? s0_chars[1] : s0_chars[0];
        s0_stage1[1] = (s0_chars[0] > s0_chars[1]) ? s0_chars[0] : s0_chars[1];
        s0_stage1[2] = (s0_chars[2] > s0_chars[3]) ? s0_chars[3] : s0_chars[2];
        s0_stage1[3] = (s0_chars[2] > s0_chars[3]) ? s0_chars[2] : s0_chars[3];
        s0_stage1[4] = (s0_chars[4] > s0_chars[5]) ? s0_chars[5] : s0_chars[4];
        s0_stage1[5] = (s0_chars[4] > s0_chars[5]) ? s0_chars[4] : s0_chars[5];
        s0_stage1[6] = (s0_chars[6] > s0_chars[7]) ? s0_chars[7] : s0_chars[6];
        s0_stage1[7] = (s0_chars[6] > s0_chars[7]) ? s0_chars[6] : s0_chars[7];

        reg [7:0] s0_stage2 [7:0];
        s0_stage2[0] = (s0_stage1[0] > s0_stage1[2]) ? s0_stage1[2] : s0_stage1[0];
        s0_stage2[2] = (s0_stage1[0] > s0_stage1[2]) ? s0_stage1[0] : s0_stage1[2];
        s0_stage2[1] = (s0_stage1[1] > s0_stage1[3]) ? s0_stage1[3] : s0_stage1[1];
        s0_stage2[3] = (s0_stage1[1] > s0_stage1[3]) ? s0_stage1[1] : s0_stage1[3];
        s0_stage2[4] = (s0_stage1[4] > s0_stage1[6]) ? s0_stage1[6] : s0_stage1[4];
        s0_stage2[6] = (s0_stage1[4] > s0_stage1[6]) ? s0_stage1[4] : s0_stage1[6];
        s0_stage2[5] = (s0_stage1[5] > s0_stage1[7]) ? s0_stage1[7] : s0_stage1[5];
        s0_stage2[7] = (s0_stage1[5] > s0_stage1[7]) ? s0_stage1[5] : s0_stage1[7];

        reg [7:0] s0_stage3 [7:0];
        s0_stage3[0] = (s0_stage2[0] > s0_stage2[4]) ? s0_stage2[4] : s0_stage2[0];
        s0_stage3[4] = (s0_stage2[0] > s0_stage2[4]) ? s0_stage2[0] : s0_stage2[4];
        s0_stage3[1] = (s0_stage2[1] > s0_stage2[5]) ? s0_stage2[5] : s0_stage2[1];
        s0_stage3[5] = (s0_stage2[1] > s0_stage2[5]) ? s0_stage2[1] : s0_stage2[5];
        s0_stage3[2] = (s0_stage2[2] > s0_stage2[6]) ? s0_stage2[6] : s0_stage2[2];
        s0_stage3[6] = (s0_stage2[2] > s0_stage2[6]) ? s0_stage2[2] : s0_stage2[6];
        s0_stage3[3] = (s0_stage2[3] > s0_stage2[7]) ? s0_stage2[7] : s0_stage2[3];
        s0_stage3[7] = (s0_stage2[3] > s0_stage2[7]) ? s0_stage2[3] : s0_stage2[7];

        reg [7:0] s1_stage1 [7:0];
        s1_stage1[0] = (s1_chars[0] > s1_chars[1]) ? s1_chars[1] : s1_chars[0];
        s1_stage1[1] = (s1_chars[0] > s1_chars[1]) ? s1_chars[0] : s1_chars[1];
        s1_stage1[2] = (s1_chars[2] > s1_chars[3]) ? s1_chars[3] : s1_chars[2];
        s1_stage1[3] = (s1_chars[2] > s1_chars[3]) ? s1_chars[2] : s1_chars[3];
        s1_stage1[4] = (s1_chars[4] > s1_chars[5]) ? s1_chars[5] : s1_chars[4];
        s1_stage1[5] = (s1_chars[4] > s1_chars[5]) ? s1_chars[4] : s1_chars[5];
        s1_stage1[6] = (s1_chars[6] > s1_chars[7]) ? s1_chars[7] : s1_chars[6];
        s1_stage1[7] = (s1_chars[6] > s1_chars[7]) ? s1_chars[6] : s1_chars[7];

        reg [7:0] s1_stage2 [7:0];
        s1_stage2[0] = (s1_stage1[0] > s1_stage1[2]) ? s1_stage1[2] : s1_stage1[0];
        s1_stage2[2] = (s1_stage1[0] > s1_stage1[2]) ? s1_stage1[0] : s1_stage1[2];
        s1_stage2[1] = (s1_stage1[1] > s1_stage1[3]) ? s1_stage1[3] : s1_stage1[1];
        s1_stage2[3] = (s1_stage1[1] > s1_stage1[3]) ? s1_stage1[1] : s1_stage1[3];
        s1_stage2[4] = (s1_stage1[4] > s1_stage1[6]) ? s1_stage1[6] : s1_stage1[4];
        s1_stage2[6] = (s1_stage1[4] > s1_stage1[6]) ? s1_stage1[4] : s1_stage1[6];
        s1_stage2[5] = (s1_stage1[5] > s1_stage1[7]) ? s1_stage1[7] : s1_stage1[5];
        s1_stage2[7] = (s1_stage1[5] > s1_stage1[7]) ? s1_stage1[5] : s1_stage1[7];

        reg [7:0] s1_stage3 [7:0];
        s1_stage3[0] = (s1_stage2[0] > s1_stage2[4]) ? s1_stage2[4] : s1_stage2[0];
        s1_stage3[4] = (s1_stage2[0] > s1_stage2[4]) ? s1_stage2[0] : s1_stage2[4];
        s1_stage3[1] = (s1_stage2[1] > s1_stage2[5]) ? s1_stage2[5] : s1_stage2[1];
        s1_stage3[5] = (s1_stage2[1] > s1_stage2[5]) ? s1_stage2[1] : s1_stage2[5];
        s1_stage3[2] = (s1_stage2[2] > s1_stage2[6]) ? s1_stage2[6] : s1_stage2[2];
        s1_stage3[6] = (s1_stage2[2] > s1_stage2[6]) ? s1_stage2[2] : s1_stage2[6];
        s1_stage3[3] = (s1_stage2[3] > s1_stage2[7]) ? s1_stage2[7] : s1_stage2[3];
        s1_stage3[7] = (s1_stage2[3] > s1_stage2[7]) ? s1_stage2[3] : s1_stage2[7];

        wire equal_all = 1'b1;
        equal_all = equal_all & (s0_stage3[0] == s1_stage3[0]);
        equal_all = equal_all & (s0_stage3[1] == s1_stage3[1]);
        equal_all = equal_all & (s0_stage3[2] == s1_stage3[2]);
        equal_all = equal_all & (s0_stage3[3] == s1_stage3[3]);
        equal_all = equal_all & (s0_stage3[4] == s1_stage3[4]);
        equal_all = equal_all & (s0_stage3[5] == s1_stage3[5]);
        equal_all = equal_all & (s0_stage3[6] == s1_stage3[6]);
        equal_all = equal_all & (s0_stage3[7] == s1_stage3[7]);

        result = equal_all;
    end
endmodule