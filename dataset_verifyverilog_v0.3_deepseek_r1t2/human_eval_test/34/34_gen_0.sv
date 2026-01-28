module unique_sorter(
    input [7:0][15:0] numbers,
    output [7:0][15:0] result
);
    wire [15:0] stage1 [0:7];
    assign {stage1[0], stage1[1]} = (numbers[0] <= numbers[1]) ? {numbers[0], numbers[1]} : {numbers[1], numbers[0]};
    assign {stage1[2], stage1[3]} = (numbers[2] <= numbers[3]) ? {numbers[2], numbers[3]} : {numbers[3], numbers[2]};
    assign {stage1[4], stage1[5]} = (numbers[4] <= numbers[5]) ? {numbers[4], numbers[5]} : {numbers[5], numbers[4]};
    assign {stage1[6], stage1[7]} = (numbers[6] <= numbers[7]) ? {numbers[6], numbers[7]} : {numbers[7], numbers[6]};

    wire [15:0] stage2 [0:7];
    assign {stage2[0], stage2[2]} = (stage1[0] <= stage1[2]) ? {stage1[0], stage1[2]} : {stage1[2], stage1[0]};
    assign {stage2[1], stage2[3]} = (stage1[1] <= stage1[3]) ? {stage1[1], stage1[3]} : {stage1[3], stage1[1]};
    assign {stage2[4], stage2[6]} = (stage1[4] <= stage1[6]) ? {stage1[4], stage1[6]} : {stage1[6], stage1[4]};
    assign {stage2[5], stage2[7]} = (stage1[5] <= stage1[7]) ? {stage1[5], stage1[7]} : {stage1[7], stage1[5]};

    wire [15:0] stage3 [0:7];
    assign {stage3[0], stage3[4]} = (stage2[0] <= stage2[4]) ? {stage2[0], stage2[4]} : {stage2[4], stage2[0]};
    assign {stage3[1], stage3[5]} = (stage2[1] <= stage2[5]) ? {stage2[1], stage2[5]} : {stage2[5], stage2[1]};
    assign {stage3[2], stage3[6]} = (stage2[2] <= stage2[6]) ? {stage2[2], stage2[6]} : {stage2[6], stage2[2]};
    assign {stage3[3], stage3[7]} = (stage2[3] <= stage2[7]) ? {stage2[3], stage2[7]} : {stage2[7], stage2[3]};

    wire [15:0] stage4 [0:7];
    assign {stage4[0], stage4[2]} = (stage3[0] <= stage3[2]) ? {stage3[0], stage3[2]} : {stage3[2], stage3[0]};
    assign {stage4[1], stage4[3]} = (stage3[1] <= stage3[3]) ? {stage3[1], stage3[3]} : {stage3[3], stage3[1]};
    assign {stage4[4], stage4[6]} = (stage3[4] <= stage3[6]) ? {stage3[4], stage3[6]} : {stage3[6], stage3[4]};
    assign {stage4[5], stage4[7]} = (stage3[5] <= stage3[7]) ? {stage3[5], stage3[7]} : {stage3[7], stage3[5]};

    wire [15:0] stage5 [0:7];
    assign {stage5[0], stage5[1]} = (stage4[0] <= stage4[1]) ? {stage4[0], stage4[1]} : {stage4[1], stage4[0]};
    assign {stage5[2], stage5[3]} = (stage4[2] <= stage4[3]) ? {stage4[2], stage4[3]} : {stage4[3], stage4[2]};
    assign {stage5[4], stage5[5]} = (stage4[4] <= stage4[5]) ? {stage4[4], stage4[5]} : {stage4[5], stage4[4]};
    assign {stage5[6], stage5[7]} = (stage4[6] <= stage4[7]) ? {stage4[6], stage4[7]} : {stage4[7], stage4[6]};

    wire [15:0] sorted [0:7];
    assign sorted[0] = stage5[0];
    assign sorted[1] = stage5[1];
    assign sorted[2] = stage5[2];
    assign sorted[3] = stage5[3];
    assign sorted[4] = stage5[4];
    assign sorted[5] = stage5[5];
    assign sorted[6] = stage5[6];
    assign sorted[7] = stage5[7];

    wire [15:0] unique_sorted [0:7];
    assign unique_sorted[0] = sorted[0];
    assign unique_sorted[1] = (sorted[1] == sorted[0]) ? 16'd0 : sorted[1];
    assign unique_sorted[2] = (sorted[2] == sorted[1]) ? 16'd0 : sorted[2];
    assign unique_sorted[3] = (sorted[3] == sorted[2]) ? 16'd0 : sorted[3];
    assign unique_sorted[4] = (sorted[4] == sorted[3]) ? 16'd0 : sorted[4];
    assign unique_sorted[5] = (sorted[5] == sorted[4]) ? 16'd0 : sorted[5];
    assign unique_sorted[6] = (sorted[6] == sorted[5]) ? 16'd0 : sorted[6];
    assign unique_sorted[7] = (sorted[7] == sorted[6]) ? 16'd0 : sorted[7];

    wire [7:0] valid [0:7];
    assign valid[0] = (unique_sorted[0] != 16'd0);
    assign valid[1] = (unique_sorted[1] != 16'd0);
    assign valid[2] = (unique_sorted[2] != 16'd0);
    assign valid[3] = (unique_sorted[3] != 16'd0);
    assign valid[4] = (unique_sorted[4] != 16'd0);
    assign valid[5] = (unique_sorted[5] != 16'd0);
    assign valid[6] = (unique_sorted[6] != 16'd0);
    assign valid[7] = (unique_sorted[7] != 16'd0);

    wire [3:0] count_0 = valid[0];
    wire [3:0] count_1 = count_0 + valid[1];
    wire [3:0] count_2 = count_1 + valid[2];
    wire [3:0] count_3 = count_2 + valid[3];
    wire [3:0] count_4 = count_3 + valid[4];
    wire [3:0] count_5 = count_4 + valid[5];
    wire [3:0] count_6 = count_5 + valid[6];
    wire [3:0] count_7 = count_6 + valid[7];

    reg [15:0] compacted [0:7];
    always @(*) begin
        compacted[0] = ((count_0 == 4'd1) & valid[0]) ? unique_sorted[0] :
                       ((count_1 == 4'd1) & valid[1]) ? unique_sorted[1] :
                       ((count_2 == 4'd1) & valid[2]) ? unique_sorted[2] :
                       ((count_3 == 4'd1) & valid[3]) ? unique_sorted[3] :
                       ((count_4 == 4'd1) & valid[4]) ? unique_sorted[4] :
                       ((count_5 == 4'd1) & valid[5]) ? unique_sorted[5] :
                       ((count_6 == 4'd1) & valid[6]) ? unique_sorted[6] :
                       ((count_7 == 4'd1) & valid[7]) ? unique_sorted[7] : 16'd0;

        compacted[1] = ((count_0 == 4'd2) & valid[0]) ? unique_sorted[0] :
                       ((count_1 == 4'd2) & valid[1]) ? unique_sorted[1] :
                       ((count_2 == 4'd2) & valid[2]) ? unique_sorted[2] :
                       ((count_3 == 4'd2) & valid[3]) ? unique_sorted[3] :
                       ((count_4 == 4'd2) & valid[4]) ? unique_sorted[4] :
                       ((count_5 == 4'd2) & valid[5]) ? unique_sorted[5] :
                       ((count_6 == 4'd2) & valid[6]) ? unique_sorted[6] :
                       ((count_7 == 4'd2) & valid[7]) ? unique_sorted[7] : 16'd0;

        compacted[2] = ((count_0 == 4'd3) & valid[0]) ? unique_sorted[0] :
                       ((count_1 == 4'd3) & valid[1]) ? unique_sorted[1] :
                       ((count_2 == 4'd3) & valid[2]) ? unique_sorted[2] :
                       ((count_3 == 4'd3) & valid[3]) ? unique_sorted[3] :
                       ((count_4 == 4'd3) & valid[4]) ? unique_sorted[4] :
                       ((count_5 == 4'd3) & valid[5]) ? unique_sorted[5] :
                       ((count_6 == 4'd3) & valid[6]) ? unique_sorted[6] :
                       ((count_7 == 4'd3) & valid[7]) ? unique_sorted[7] : 16'd0;

        compacted[3] = ((count_0 == 4'd4) & valid[0]) ? unique_sorted[0] :
                       ((count_1 == 4'd4) & valid[1]) ? unique_sorted[1] :
                       ((count_2 == 4'd4) & valid[2]) ? unique_sorted[2] :
                       ((count_3 == 4'd4) & valid[3]) ? unique_sorted[3] :
                       ((count_4 == 4'd4) & valid[4]) ? unique_sorted[4] :
                       ((count_5 == 4'd4) & valid[5]) ? unique_sorted[5] :
                       ((count_6 == 4'd4) & valid[6]) ? unique_sorted[6] :
                       ((count_7 == 4'd4) & valid[7]) ? unique_sorted[7] : 16'd0;

        compacted[4] = ((count_0 == 4'd5) & valid[0]) ? unique_sorted[0] :
                       ((count_1 == 4'd5) & valid[1]) ? unique_sorted[1] :
                       ((count_2 == 4'd5) & valid[2]) ? unique_sorted[2] :
                       ((count_3 == 4'd5) & valid[3]) ? unique_sorted[3] :
                       ((count_4 == 4'd5) & valid[4]) ? unique_sorted[4] :
                       ((count_5 == 4'd5) & valid[5]) ? unique_sorted[5] :
                       ((count_6 == 4'd5) & valid[6]) ? unique_sorted[6] :
                       ((count_7 == 4'd5) & valid[7]) ? unique_sorted[7] : 16'd0;

        compacted[5] = ((count_0 == 4'd6) & valid[0]) ? unique_sorted[0] :
                       ((count_1 == 4'd6) & valid[1]) ? unique_sorted[1] :
                       ((count_2 == 4'd6) & valid[2]) ? unique_sorted[2] :
                       ((count_3 == 4'd6) & valid[3]) ? unique_sorted[3] :
                       ((count_4 == 4'd6) & valid[4]) ? unique_sorted[4] :
                       ((count_5 == 4'd6) & valid[5]) ? unique_sorted[5] :
                       ((count_6 == 4'd6) & valid[6]) ? unique_sorted[6] :
                       ((count_7 == 4'd6) & valid[7]) ? unique_sorted[7] : 16'd0;

        compacted[6] = ((count_0 == 4'd7) & valid[0]) ? unique_sorted[0] :
                       ((count_1 == 4'd7) & valid[1]) ? unique_sorted[1] :
                       ((count_2 == 4'd7) & valid[2]) ? unique_sorted[2] :
                       ((count_3 == 4'd7) & valid[3]) ? unique_sorted[3] :
                       ((count_4 == 4'd7) & valid[4]) ? unique_sorted[4] :
                       ((count_5 == 4'd7) & valid[5]) ? unique_sorted[5] :
                       ((count_6 == 4'd7) & valid[6]) ? unique_sorted[6] :
                       ((count_7 == 4'd7) & valid[7]) ? unique_sorted[7] : 16'd0;

        compacted[7] = ((count_0 == 4'd8) & valid[0]) ? unique_sorted[0] :
                       ((count_1 == 4'd8) & valid[1]) ? unique_sorted[1] :
                       ((count_2 == 4'd8) & valid[2]) ? unique_sorted[2] :
                       ((count_3 == 4'd8) & valid[3]) ? unique_sorted[3] :
                       ((count_4 == 4'd8) & valid[4]) ? unique_sorted[4] :
                       ((count_5 == 4'd8) & valid[5]) ? unique_sorted[5] :
                       ((count_6 == 4'd8) & valid[6]) ? unique_sorted[6] :
                       ((count_7 == 4'd8) & valid[7]) ? unique_sorted[7] : 16'd0;

        // Handle cases where total count is less than index+1
        if (count_7 <= 4'd1) compacted[1] = 16'd0;
        if (count_7 <= 4'd2) compacted[2] = 16'd0;
        if (count_7 <= 4'd3) compacted[3] = 16'd0;
        if (count_7 <= 4'd4) compacted[4] = 16'd0;
        if (count_7 <= 4'd5) compacted[5] = 16'd0;
        if (count_7 <= 4'd6) compacted[6] = 16'd0;
        if (count_7 <= 4'd7) compacted[7] = 16'd0;
    end

    assign result = compacted;
endmodule