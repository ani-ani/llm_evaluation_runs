module event_duration_calculator(
    input clk,
    input rst_n,
    input start,
    input [4:0] n_telem,
    input [4:0] m_types,
    input [8:0] start_day_0,
    input [8:0] end_day_0,
    input [7:0] events_0_0,
    input [7:0] events_0_1,
    input [7:0] events_0_2,
    input [7:0] events_0_3,
    input [7:0] events_0_4,
    input [7:0] events_0_5,
    input [7:0] events_0_6,
    input [7:0] events_0_7,
    input [7:0] events_0_8,
    input [7:0] events_0_9,
    input [7:0] events_0_10,
    input [7:0] events_0_11,
    input [7:0] events_0_12,
    input [7:0] events_0_13,
    input [7:0] events_0_14,
    input [7:0] events_0_15,
    input [8:0] start_day_1,
    input [8:0] end_day_1,
    input [7:0] events_1_0,
    input [7:0] events_1_1,
    input [7:0] events_1_2,
    input [7:0] events_1_3,
    input [7:0] events_1_4,
    input [7:0] events_1_5,
    input [7:0] events_1_6,
    input [7:0] events_1_7,
    input [7:0] events_1_8,
    input [7:0] events_1_9,
    input [7:0] events_1_10,
    input [7:0] events_1_11,
    input [7:0] events_1_12,
    input [7:0] events_1_13,
    input [7:0] events_1_14,
    input [7:0] events_1_15,
    input [8:0] start_day_2,
    input [8:0] end_day_2,
    input [7:0] events_2_0,
    input [7:0] events_2_1,
    input [7:0] events_2_2,
    input [7:0] events_2_3,
    input [7:0] events_2_4,
    input [7:0] events_2_5,
    input [7:0] events_2_6,
    input [7:0] events_2_7,
    input [7:0] events_2_8,
    input [7:0] events_2_9,
    input [7:0] events_2_10,
    input [7:0] events_2_11,
    input [7:0] events_2_12,
    input [7:0] events_2_13,
    input [7:0] events_2_14,
    input [7:0] events_2_15,
    input [8:0] start_day_3,
    input [8:0] end_day_3,
    input [7:0] events_3_0,
    input [7:0] events_3_1,
    input [7:0] events_3_2,
    input [7:0] events_3_3,
    input [7:0] events_3_4,
    input [7:0] events_3_5,
    input [7:0] events_3_6,
    input [7:0] events_3_7,
    input [7:0] events_3_8,
    input [7:0] events_3_9,
    input [7:0] events_3_10,
    input [7:0] events_3_11,
    input [7:0] events_3_12,
    input [7:0] events_3_13,
    input [7:0] events_3_14,
    input [7:0] events_3_15,
    input [8:0] start_day_4,
    input [8:0] end_day_4,
    input [7:0] events_4_0,
    input [7:0] events_4_1,
    input [7:0] events_4_2,
    input [7:0] events_4_3,
    input [7:0] events_4_4,
    input [7:0] events_4_5,
    input [7:0] events_4_6,
    input [7:0] events_4_7,
    input [7:0] events_4_8,
    input [7:0] events_4_9,
    input [7:0] events_4_10,
    input [7:0] events_4_11,
    input [7:0] events_4_12,
    input [7:0] events_4_13,
    input [7:0] events_4_14,
    input [7:0] events_4_15,
    input [8:0] start_day_5,
    input [8:0] end_day_5,
    input [7:0] events_5_0,
    input [7:0] events_5_1,
    input [7:0] events_5_2,
    input [7:0] events_5_3,
    input [7:0] events_5_4,
    input [7:0] events_5_5,
    input [7:0] events_5_6,
    input [7:0] events_5_7,
    input [7:0] events_5_8,
    input [7:0] events_5_9,
    input [7:0] events_5_10,
    input [7:0] events_5_11,
    input [7:0] events_5_12,
    input [7:0] events_5_13,
    input [7:0] events_5_14,
    input [7:0] events_5_15,
    input [8:0] start_day_6,
    input [8:0] end_day_6,
    input [7:0] events_6_0,
    input [7:0] events_6_1,
    input [7:0] events_6_2,
    input [7:0] events_6_3,
    input [7:0] events_6_4,
    input [7:0] events_6_5,
    input [7:0] events_6_6,
    input [7:0] events_6_7,
    input [7:0] events_6_8,
    input [7:0] events_6_9,
    input [7:0] events_6_10,
    input [7:0] events_6_11,
    input [7:0] events_6_12,
    input [7:0] events_6_13,
    input [7:0] events_6_14,
    input [7:0] events_6_15,
    input [8:0] start_day_7,
    input [8:0] end_day_7,
    input [7:0] events_7_0,
    input [7:0] events_7_1,
    input [7:0] events_7_2,
    input [7:0] events_7_3,
    input [7:0] events_7_4,
    input [7:0] events_7_5,
    input [7:0] events_7_6,
    input [7:0] events_7_7,
    input [7:0] events_7_8,
    input [7:0] events_7_9,
    input [7:0] events_7_10,
    input [7:0] events_7_11,
    input [7:0] events_7_12,
    input [7:0] events_7_13,
    input [7:0] events_7_14,
    input [7:0] events_7_15,
    input [8:0] start_day_8,
    input [8:0] end_day_8,
    input [7:0] events_8_0,
    input [7:0] events_8_1,
    input [7:0] events_8_2,
    input [7:0] events_8_3,
    input [7:0] events_8_4,
    input [7:0] events_8_5,
    input [7:0] events_8_6,
    input [7:0] events_8_7,
    input [7:0] events_8_8,
    input [7:0] events_8_9,
    input [7:0] events_8_10,
    input [7:0] events_8_11,
    input [7:0] events_8_12,
    input [7:0] events_8_13,
    input [7:0] events_8_14,
    input [7:0] events_8_15,
    input [8:0] start_day_9,
    input [8:0] end_day_9,
    input [7:0] events_9_0,
    input [7:0] events_9_1,
    input [7:0] events_9_2,
    input [7:0] events_9_3,
    input [7:0] events_9_4,
    input [7:0] events_9_5,
    input [7:0] events_9_6,
    input [7:0] events_9_7,
    input [7:0] events_9_8,
    input [7:0] events_9_9,
    input [7:0] events_9_10,
    input [7:0] events_9_11,
    input [7:0] events_9_12,
    input [7:0] events_9_13,
    input [7:0] events_9_14,
    input [7:0] events_9_15,
    input [8:0] start_day_10,
    input [8:0] end_day_10,
    input [7:0] events_10_0,
    input [7:0] events_10_1,
    input [7:0] events_10_2,
    input [7:0] events_10_3,
    input [7:0] events_10_4,
    input [7:0] events_10_5,
    input [7:0] events_10_6,
    input [7:0] events_10_7,
    input [7:0] events_10_8,
    input [7:0] events_10_9,
    input [7:0] events_10_10,
    input [7:0] events_10_11,
    input [7:0] events_10_12,
    input [7:0] events_10_13,
    input [7:0] events_10_14,
    input [7:0] events_10_15,
    input [8:0] start_day_11,
    input [8:0] end_day_11,
    input [7:0] events_11_0,
    input [7:0] events_11_1,
    input [7:0] events_11_2,
    input [7:0] events_11_3,
    input [7:0] events_11_4,
    input [7:0] events_11_5,
    input [7:0] events_11_6,
    input [7:0] events_11_7,
    input [7:0] events_11_8,
    input [7:0] events_11_9,
    input [7:0] events_11_10,
    input [7:0] events_11_11,
    input [7:0] events_11_12,
    input [7:0] events_11_13,
    input [7:0] events_11_14,
    input [7:0] events_11_15,
    input [8:0] start_day_12,
    input [8:0] end_day_12,
    input [7:0] events_12_0,
    input [7:0] events_12_1,
    input [7:0] events_12_2,
    input [7:0] events_12_3,
    input [7:0] events_12_4,
    input [7:0] events_12_5,
    input [7:0] events_12_6,
    input [7:0] events_12_7,
    input [7:0] events_12_8,
    input [7:0] events_12_9,
    input [7:0] events_12_10,
    input [7:0] events_12_11,
    input [7:0] events_12_12,
    input [7:0] events_12_13,
    input [7:0] events_12_14,
    input [7:0] events_12_15,
    input [8:0] start_day_13,
    input [8:0] end_day_13,
    input [7:0] events_13_0,
    input [7:0] events_13_1,
    input [7:0] events_13_2,
    input [7:0] events_13_3,
    input [7:0] events_13_4,
    input [7:0] events_13_5,
    input [7:0] events_13_6,
    input [7:0] events_13_7,
    input [7:0] events_13_8,
    input [7:0] events_13_9,
    input [7:0] events_13_10,
    input [7:0] events_13_11,
    input [7:0] events_13_12,
    input [7:0] events_13_13,
    input [7:0] events_13_14,
    input [7:0] events_13_15,
    input [8:0] start_day_14,
    input [8:0] end_day_14,
    input [7:0] events_14_0,
    input [7:0] events_14_1,
    input [7:0] events_14_2,
    input [7:0] events_14_3,
    input [7:0] events_14_4,
    input [7:0] events_14_5,
    input [7:0] events_14_6,
    input [7:0] events_14_7,
    input [7:0] events_14_8,
    input [7:0] events_14_9,
    input [7:0] events_14_10,
    input [7:0] events_14_11,
    input [7:0] events_14_12,
    input [7:0] events_14_13,
    input [7:0] events_14_14,
    input [7:0] events_14_15,
    input [8:0] start_day_15,
    input [8:0] end_day_15,
    input [7:0] events_15_0,
    input [7:0] events_15_1,
    input [7:0] events_15_2,
    input [7:0] events_15_3,
    input [7:0] events_15_4,
    input [7:0] events_15_5,
    input [7:0] events_15_6,
    input [7:0] events_15_7,
    input [7:0] events_15_8,
    input [7:0] events_15_9,
    input [7:0] events_15_10,
    input [7:0] events_15_11,
    input [7:0] events_15_12,
    input [7:0] events_15_13,
    input [7:0] events_15_14,
    input [7:0] events_15_15,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg [7:0] result_8,
    output reg [7:0] result_9,
    output reg [7:0] result_10,
    output reg [7:0] result_11,
    output reg [7:0] result_12,
    output reg [7:0] result_13,
    output reg [7:0] result_14,
    output reg [7:0] result_15,
    output reg done,
    output reg valid
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] VALIDATE = 3'd2;
    localparam [2:0] COMPLETE = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] current_duration;
    reg [3:0] current_event_type;
    reg [3:0] current_telescope;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    reg [8:0] len_reg [0:15];
    reg [7:0] events_reg [0:15][0:15];

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_duration <= 8'd0;
            current_event_type <= 4'd0;
            current_telescope <= 4'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                result_0 <= 8'd0;
                result_1 <= 8'd0;
                result_2 <= 8'd0;
                result_3 <= 8'd0;
                result_4 <= 8'd0;
                result_5 <= 8'd0;
                result_6 <= 8'd0;
                result_7 <= 8'd0;
                result_8 <= 8'd0;
                result_9 <= 8'd0;
                result_10 <= 8'd0;
                result_11 <= 8'd0;
                result_12 <= 8'd0;
                result_13 <= 8'd0;
                result_14 <= 8'd0;
                result_15 <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                    current_event_type = 4'd0;
                    current_duration = 8'd1;
                    cycle_count = 8'd0;
                    valid = 1'b1;
                    done = 1'b0;

                    for (i = 0; i < 16; i = i + 1) begin
                        if (i == 0) len_reg[0] = (end_day_0 - start_day_0 + 9'd365) % 9'd365;
                        else if (i == 1) len_reg[1] = (end_day_1 - start_day_1 + 9'd365) % 9'd365;
                        else if (i == 2) len_reg[2] = (end_day_2 - start_day_2 + 9'd365) % 9'd365;
                        else if (i == 3) len_reg[3] = (end_day_3 - start_day_3 + 9'd365) % 9'd365;
                        else if (i == 4) len_reg[4] = (end_day_4 - start_day_4 + 9'd365) % 9'd365;
                        else if (i == 5) len_reg[5] = (end_day_5 - start_day_5 + 9'd365) % 9'd365;
                        else if (i == 6) len_reg[6] = (end_day_6 - start_day_6 + 9'd365) % 9'd365;
                        else if (i == 7) len_reg[7] = (end_day_7 - start_day_7 + 9'd365) % 9'd365;
                        else if (i == 8) len_reg[8] = (end_day_8 - start_day_8 + 9'd365) % 9'd365;
                        else if (i == 9) len_reg[9] = (end_day_9 - start_day_9 + 9'd365) % 9'd365;
                        else if (i == 10) len_reg[10] = (end_day_10 - start_day_10 + 9'd365) % 9'd365;
                        else if (i == 11) len_reg[11] = (end_day_11 - start_day_11 + 9'd365) % 9'd365;
                        else if (i == 12) len_reg[12] = (end_day_12 - start_day_12 + 9'd365) % 9'd365;
                        else if (i == 13) len_reg[13] = (end_day_13 - start_day_13 + 9'd365) % 9'd365;
                        else if (i == 14) len_reg[14] = (end_day_14 - start_day_14 + 9'd365) % 9'd365;
                        else if (i == 15) len_reg[15] = (end_day_15 - start_day_15 + 9'd365) % 9'd365;

                        if (len_reg[i] == 9'd0) len_reg[i] = 9'd365;
                    end

                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            if (i == 0 && j == 0) events_reg[0][0] = events_0_0;
                            else if (i == 0 && j == 1) events_reg[0][1] = events_0_1;
                            else if (i == 0 && j == 2) events_reg[0][2] = events_0_2;
                            else if (i == 0 && j == 3) events_reg[0][3] = events_0_3;
                            else if (i == 0 && j == 4) events_reg[0][4] = events_0_4;
                            else if (i == 0 && j == 5) events_reg[0][5] = events_0_5;
                            else if (i == 0 && j == 6) events_reg[0][6] = events_0_6;
                            else if (i == 0 && j == 7) events_reg[0][7] = events_0_7;
                            else if (i == 0 && j == 8) events_reg[0][8] = events_0_8;
                            else if (i == 0 && j == 9) events_reg[0][9] = events_0_9;
                            else if (i == 0 && j == 10) events_reg[0][10] = events_0_10;
                            else if (i == 0 && j == 11) events_reg[0][11] = events_0_11;
                            else if (i == 0 && j == 12) events_reg[0][12] = events_0_12;
                            else if (i == 0 && j == 13) events_reg[0][13] = events_0_13;
                            else if (i == 0 && j == 14) events_reg[0][14] = events_0_14;
                            else if (i == 0 && j == 15) events_reg[0][15] = events_0_15;
                            else if (i == 1 && j == 0) events_reg[1][0] = events_1_0;
                            else if (i == 1 && j == 1) events_reg[1][1] = events_1_1;
                            else if (i == 1 && j == 2) events_reg[1][2] = events_1_2;
                            else if (i == 1 && j == 3) events_reg[1][3] = events_1_3;
                            else if (i == 1 && j == 4) events_reg[1][4] = events_1_4;
                            else if (i == 1 && j == 5) events_reg[1][5] = events_1_5;
                            else if (i == 1 && j == 6) events_reg[1][6] = events_1_6;
                            else if (i == 1 && j == 7) events_reg[1][7] = events_1_7;
                            else if (i == 1 && j == 8) events_reg[1][8] = events_1_8;
                            else if (i == 1 && j == 9) events_reg[1][9] = events_1_9;
                            else if (i == 1 && j == 10) events_reg[1][10] = events_1_10;
                            else if (i == 1 && j == 11) events_reg[1][11] = events_1_11;
                            else if (i == 1 && j == 12) events_reg[1][12] = events_1_12;
                            else if (i == 1 && j == 13) events_reg[1][13] = events_1_13;
                            else if (i == 1 && j == 14) events_reg[1][14] = events_1_14;
                            else if (i == 1 && j == 15) events_reg[1][15] = events_1_15;
                            else if (i == 2 && j == 0) events_reg[2][0] = events_2_0;
                            else if (i == 2 && j == 1) events_reg[2][1] = events_2_1;
                            else if (i == 2 && j == 2) events_reg[2][2] = events_2_2;
                            else if (i == 2 && j == 3) events_reg[2][3] = events_2_3;
                            else if (i == 2 && j == 4) events_reg[2][4] = events_2_4;
                            else if (i == 2 && j == 5) events_reg[2][5] = events_2_5;
                            else if (i == 2 && j == 6) events_reg[2][6] = events_2_6;
                            else if (i == 2 && j == 7) events_reg[2][7] = events_2_7;
                            else if (i == 2 && j == 8) events_reg[2][8] = events_2_8;
                            else if (i == 2 && j == 9) events_reg[2][9] = events_2_9;
                            else if (i == 2 && j == 10) events_reg[2][10] = events_2_10;
                            else if (i == 2 && j == 11) events_reg[2][11] = events_2_11;
                            else if (i == 2 && j == 12) events_reg[2][12] = events_2_12;
                            else if (i == 2 && j == 13) events_reg[2][13] = events_2_13;
                            else if (i == 2 && j == 14) events_reg[2][14] = events_2_14;
                            else if (i == 2 && j == 15) events_reg[2][15] = events_2_15;
                            else if (i == 3 && j == 0) events_reg[3][0] = events_3_0;
                            else if (i == 3 && j == 1) events_reg[3][1] = events_3_1;
                            else if (i == 3 && j == 2) events_reg[3][2] = events_3_2;
                            else if (i == 3 && j == 3) events_reg[3][3] = events_3_3;
                            else if (i == 3 && j == 4) events_reg[3][4] = events_3_4;
                            else if (i == 3 && j == 5) events_reg[3][5] = events_3_5;
                            else if (i == 3 && j == 6) events_reg[3][6] = events_3_6;
                            else if (i == 3 && j == 7) events_reg[3][7] = events_3_7;
                            else if (i == 3 && j == 8) events_reg[3][8] = events_3_8;
                            else if (i == 3 && j == 9) events_reg[3][9] = events_3_9;
                            else if (i == 3 && j == 10) events_reg[3][10] = events_3_10;
                            else if (i == 3 && j == 11) events_reg[3][11] = events_3_11;
                            else if (i == 3 && j == 12) events_reg[3][12] = events_3_12;
                            else if (i == 3 && j == 13) events_reg[3][13] = events_3_13;
                            else if (i == 3 && j == 14) events_reg[3][14] = events_3_14;
                            else if (i == 3 && j == 15) events_reg[3][15] = events_3_15;
                            else if (i == 4 && j == 0) events_reg[4][0] = events_4_0;
                            else if (i == 4 && j == 1) events_reg[4][1] = events_4_1;
                            else if (i == 4 && j == 2) events_reg[4][2] = events_4_2;
                            else if (i == 4 && j == 3) events_reg[4][3] = events_4_3;
                            else if (i == 4 && j == 4) events_reg[4][4] = events_4_4;
                            else if (i == 4 && j == 5) events_reg[4][5] = events_4_5;
                            else if (i == 4 && j == 6) events_reg[4][6] = events_4_6;
                            else if (i == 4 && j == 7) events_reg[4][7] = events_4_7;
                            else if (i == 4 && j == 8) events_reg[4][8] = events_4_8;
                            else if (i == 4 && j == 9) events_reg[4][9] = events_4_9;
                            else if (i == 4 && j == 10) events_reg[4][10] = events_4_10;
                            else if (i == 4 && j == 11) events_reg[4][11] = events_4_11;
                            else if (i == 4 && j == 12) events_reg[4][12] = events_4_12;
                            else if (i == 4 && j == 13) events_reg[4][13] = events_4_13;
                            else if (i == 4 && j == 14) events_reg[4][14] = events_4_14;
                            else if (i == 4 && j == 15) events_reg[4][15] = events_4_15;
                            else if (i == 5 && j == 0) events_reg[5][0] = events_5_0;
                            else if (i == 5 && j == 1) events_reg[5][1] = events_5_1;
                            else if (i == 5 && j == 2) events_reg[5][2] = events_5_2;
                            else if (i == 5 && j == 3) events_reg[5][3] = events_5_3;
                            else if (i == 5 && j == 4) events_reg[5][4] = events_5_4;
                            else if (i == 5 && j == 5) events_reg[5][5] = events_5_5;
                            else if (i == 5 && j == 6) events_reg[5][6] = events_5_6;
                            else if (i == 5 && j == 7) events_reg[5][7] = events_5_7;
                            else if (i == 5 && j == 8) events_reg[5][8] = events_5_8;
                            else if (i == 5 && j == 9) events_reg[5][9] = events_5_9;
                            else if (i == 5 && j == 10) events_reg[5][10] = events_5_10;
                            else if (i == 5 && j == 11) events_reg[5][11] = events_5_11;
                            else if (i == 5 && j == 12) events_reg[5][12] = events_5_12;
                            else if (i == 5 && j == 13) events_reg[5][13] = events_5_13;
                            else if (i == 5 && j == 14) events_reg[5][14] = events_5_14;
                            else if (i == 5 && j == 15) events_reg[5][15] = events_5_15;
                            else if (i == 6 && j == 0) events_reg[6][0] = events_6_0;
                            else if (i == 6 && j == 1) events_reg[6][1] = events_6_1;
                            else if (i == 6 && j == 2) events_reg[6][2] = events_6_2;
                            else if (i == 6 && j == 3) events_reg[6][3] = events_6_3;
                            else if (i == 6 && j == 4) events_reg[6][4] = events_6_4;
                            else if (i == 6 && j == 5) events_reg[6][5] = events_6_5;
                            else if (i == 6 && j == 6) events_reg[6][6] = events_6_6;
                            else if (i == 6 && j == 7) events_reg[6][7] = events_6_7;
                            else if (i == 6 && j == 8) events_reg[6][8] = events_6_8;
                            else if (i == 6 && j == 9) events_reg[6][9] = events_6_9;
                            else if (i == 6 && j == 10) events_reg[6][10] = events_6_10;
                            else if (i == 6 && j == 11) events_reg[6][11] = events_6_11;
                            else if (i == 6 && j == 12) events_reg[6][12] = events_6_12;
                            else if (i == 6 && j == 13) events_reg[6][13] = events_6_13;
                            else if (i == 6 && j == 14) events_reg[6][14] = events_6_14;
                            else if (i == 6 && j == 15) events_reg[6][15] = events_6_15;
                            else if (i == 7 && j == 0) events_reg[7][0] = events_7_0;
                            else if (i == 7 && j == 1) events_reg[7][1] = events_7_1;
                            else if (i == 7 && j == 2) events_reg[7][2] = events_7_2;
                            else if (i == 7 && j == 3) events_reg[7][3] = events_7_3;
                            else if (i == 7 && j == 4) events_reg[7][4] = events_7_4;
                            else if (i == 7 && j == 5) events_reg[7][5] = events_7_5;
                            else if (i == 7 && j == 6) events_reg[7][6] = events_7_6;
                            else if (i == 7 && j == 7) events_reg[7][7] = events_7_7;
                            else if (i == 7 && j == 8) events_reg[7][8] = events_7_8;
                            else if (i == 7 && j == 9) events_reg[7][9] = events_7_9;
                            else if (i == 7 && j == 10) events_reg[7][10] = events_7_10;
                            else if (i == 7 && j == 11) events_reg[7][11] = events_7_11;
                            else if (i == 7 && j == 12) events_reg[7][12] = events_7_12;
                            else if (i == 7 && j == 13) events_reg[7][13] = events_7_13;
                            else if (i == 7 && j == 14) events_reg[7][14] = events_7_14;
                            else if (i == 7 && j == 15) events_reg[7][15] = events_7_15;
                            else if (i == 8 && j == 0) events_reg[8][0] = events_8_0;
                            else if (i == 8 && j == 1) events_reg[8][1] = events_8_1;
                            else if (i == 8 && j == 2) events_reg[8][2] = events_8_2;
                            else if (i == 8 && j == 3) events_reg[8][3] = events_8_3;
                            else if (i == 8 && j == 4) events_reg[8][4] = events_8_4;
                            else if (i == 8 && j == 5) events_reg[8][5] = events_8_5;
                            else if (i == 8 && j == 6) events_reg[8][6] = events_8_6;
                            else if (i == 8 && j == 7) events_reg[8][7] = events_8_7;
                            else if (i == 8 && j == 8) events_reg[8][8] = events_8_8;
                            else if (i == 8 && j == 9) events_reg[8][9] = events_8_9;
                            else if (i == 8 && j == 10) events_reg[8][10] = events_8_10;
                            else if (i == 8 && j == 11) events_reg[8][11] = events_8_11;
                            else if (i == 8 && j == 12) events_reg[8][12] = events_8_12;
                            else if (i == 8 && j == 13) events_reg[8][13] = events_8_13;
                            else if (i == 8 && j == 14) events_reg[8][14] = events_8_14;
                            else if (i == 8 && j == 15) events_reg[8][15] = events_8_15;
                            else if (i == 9 && j == 0) events_reg[9][0] = events_9_0;
                            else if (i == 9 && j == 1) events_reg[9][1] = events_9_1;
                            else if (i == 9 && j == 2) events_reg[9][2] = events_9_2;
                            else if (i == 9 && j == 3) events_reg[9][3] = events_9_3;
                            else if (i == 9 && j == 4) events_reg[9][4] = events_9_4;
                            else if (i == 9 && j == 5) events_reg[9][5] = events_9_5;
                            else if (i == 9 && j == 6) events_reg[9][6] = events_9_6;
                            else if (i == 9 && j == 7) events_reg[9][7] = events_9_7;
                            else if (i == 9 && j == 8) events_reg[9][8] = events_9_8;
                            else if (i == 9 && j == 9) events_reg[9][9] = events_9_9;
                            else if (i == 9 && j == 10) events_reg[9][10] = events_9_10;
                            else if (i == 9 && j == 11) events_reg[9][11] = events_9_11;
                            else if (i == 9 && j == 12) events_reg[9][12] = events_9_12;
                            else if (i == 9 && j == 13) events_reg[9][13] = events_9_13;
                            else if (i == 9 && j == 14) events_reg[9][14] = events_9_14;
                            else if (i == 9 && j == 15) events_reg[9][15] = events_9_15;
                            else if (i == 10 && j == 0) events_reg[10][0] = events_10_0;
                            else if (i == 10 && j == 1) events_reg[10][1] = events_10_1;
                            else if (i == 10 && j == 2) events_reg[10][2] = events_10_2;
                            else if (i == 10 && j == 3) events_reg[10][3] = events_10_3;
                            else if (i == 10 && j == 4) events_reg[10][4] = events_10_4;
                            else if (i == 10 && j == 5) events_reg[10][5] = events_10_5;
                            else if (i == 10 && j == 6) events_reg[10][6] = events_10_6;
                            else if (i == 10 && j == 7) events_reg[10][7] = events_10_7;
                            else if (i == 10 && j == 8) events_reg[10][8] = events_10_8;
                            else if (i == 10 && j == 9) events_reg[10][9] = events_10_9;
                            else if (i == 10 && j == 10) events_reg[10][10] = events_10_10;
                            else if (i == 10 && j == 11) events_reg[10][11] = events_10_11;
                            else if (i == 10 && j == 12) events_reg[10][12] = events_10_12;
                            else if (i == 10 && j == 13) events_reg[10][13] = events_10_13;
                            else if (i == 10 && j == 14) events_reg[10][14] = events_10_14;
                            else if (i == 10 && j == 15) events_reg[10][15] = events_10_15;
                            else if (i == 11 && j == 0) events_reg[11][0] = events_11_0;
                            else if (i == 11 && j == 1) events_reg[11][1] = events_11_1;
                            else if (i == 11 && j == 2) events_reg[11][2] = events_11_2;
                            else if (i == 11 && j == 3) events_reg[11][3] = events_11_3;
                            else if (i == 11 && j == 4) events_reg[11][4] = events_11_4;
                            else if (i == 11 && j == 5) events_reg[11][5] = events_11_5;
                            else if (i == 11 && j == 6) events_reg[11][6] = events_11_6;
                            else if (i == 11 && j == 7) events_reg[11][7] = events_11_7;
                            else if (i == 11 && j == 8) events_reg[11][8] = events_11_8;
                            else if (i == 11 && j == 9) events_reg[11][9] = events_11_9;
                            else if (i == 11 && j == 10) events_reg[11][10] = events_11_10;
                            else if (i == 11 && j == 11) events_reg[11][11] = events_11_11;
                            else if (i == 11 && j == 12) events_reg[11][12] = events_11_12;
                            else if (i == 11 && j == 13) events_reg[11][13] = events_11_13;
                            else if (i == 11 && j == 14) events_reg[11][14] = events_11_14;
                            else if (i == 11 && j == 15) events_reg[11][15] = events_11_15;
                            else if (i == 12 && j == 0) events_reg[12][0] = events_12_0;
                            else if (i == 12 && j == 1) events_reg[12][1] = events_12_1;
                            else if (i == 12 && j == 2) events_reg[12][2] = events_12_2;
                            else if (i == 12 && j == 3) events_reg[12][3] = events_12_3;
                            else if (i == 12 && j == 4) events_reg[12][4] = events_12_4;
                            else if (i == 12 && j == 5) events_reg[12][5] = events_12_5;
                            else if (i == 12 && j == 6) events_reg[12][6] = events_12_6;
                            else if (i == 12 && j == 7) events_reg[12][7] = events_12_7;
                            else if (i == 12 && j == 8) events_reg[12][8] = events_12_8;
                            else if (i == 12 && j == 9) events_reg[12][9] = events_12_9;
                            else if (i == 12 && j == 10) events_reg[12][10] = events_12_10;
                            else if (i == 12 && j == 11) events_reg[12][11] = events_12_11;
                            else if (i == 12 && j == 12) events_reg[12][12] = events_12_12;
                            else if (i == 12 && j == 13) events_reg[12][13] = events_12_13;
                            else if (i == 12 && j == 14) events_reg[12][14] = events_12_14;
                            else if (i == 12 && j == 15) events_reg[12][15] = events_12_15;
                            else if (i == 13 && j == 0) events_reg[13][0] = events_13_0;
                            else if (i == 13 && j == 1) events_reg[13][1] = events_13_1;
                            else if (i == 13 && j == 2) events_reg[13][2] = events_13_2;
                            else if (i == 13 && j == 3) events_reg[13][3] = events_13_3;
                            else if (i == 13 && j == 4) events_reg[13][4] = events_13_4;
                            else if (i == 13 && j == 5) events_reg[13][5] = events_13_5;
                            else if (i == 13 && j == 6) events_reg[13][6] = events_13_6;
                            else if (i == 13 && j == 7) events_reg[13][7] = events_13_7;
                            else if (i == 13 && j == 8) events_reg[13][8] = events_13_8;
                            else if (i == 13 && j == 9) events_reg[13][9] = events_13_9;
                            else if (i == 13 && j == 10) events_reg[13][10] = events_13_10;
                            else if (i == 13 && j == 11) events_reg[13][11] = events_13_11;
                            else if (i == 13 && j == 12) events_reg[13][12] = events_13_12;
                            else if (i == 13 && j == 13) events_reg[13][13] = events_13_13;
                            else if (i == 13 && j == 14) events_reg[13][14] = events_13_14;
                            else if (i == 13 && j == 15) events_reg[13][15] = events_13_15;
                            else if (i == 14 && j == 0) events_reg[14][0] = events_14_0;
                            else if (i == 14 && j == 1) events_reg[14][1] = events_14_1;
                            else if (i == 14 && j == 2) events_reg[14][2] = events_14_2;
                            else if (i == 14 && j == 3) events_reg[14][3] = events_14_3;
                            else if (i == 14 && j == 4) events_reg[14][4] = events_14_4;
                            else if (i == 14 && j == 5) events_reg[14][5] = events_14_5;
                            else if (i == 14 && j == 6) events_reg[14][6] = events_14_6;
                            else if (i == 14 && j == 7) events_reg[14][7] = events_14_7;
                            else if (i == 14 && j == 8) events_reg[14][8] = events_14_8;
                            else if (i == 14 && j == 9) events_reg[14][9] = events_14_9;
                            else if (i == 14 && j == 10) events_reg[14][10] = events_14_10;
                            else if (i == 14 && j == 11) events_reg[14][11] = events_14_11;
                            else if (i == 14 && j == 12) events_reg[14][12] = events_14_12;
                            else if (i == 14 && j == 13) events_reg[14][13] = events_14_13;
                            else if (i == 14 && j == 14) events_reg[14][14] = events_14_14;
                            else if (i == 14 && j == 15) events_reg[14][15] = events_14_15;
                            else if (i == 15 && j == 0) events_reg[15][0] = events_15_0;
                            else if (i == 15 && j == 1) events_reg[15][1] = events_15_1;
                            else if (i == 15 && j == 2) events_reg[15][2] = events_15_2;
                            else if (i == 15 && j == 3) events_reg[15][3] = events_15_3;
                            else if (i == 15 && j == 4) events_reg[15][4] = events_15_4;
                            else if (i == 15 && j == 5) events_reg[15][5] = events_15_5;
                            else if (i == 15 && j == 6) events_reg[15][6] = events_15_6;
                            else if (i == 15 && j == 7) events_reg[15][7] = events_15_7;
                            else if (i == 15 && j == 8) events_reg[15][8] = events_15_8;
                            else if (i == 15 && j == 9) events_reg[15][9] = events_15_9;
                            else if (i == 15 && j == 10) events_reg[15][10] = events_15_10;
                            else if (i == 15 && j == 11) events_reg[15][11] = events_15_11;
                            else if (i == 15 && j == 12) events_reg[15][12] = events_15_12;
                            else if (i == 15 && j == 13) events_reg[15][13] = events_15_13;
                            else if (i == 15 && j == 14) events_reg[15][14] = events_15_14;
                            else if (i == 15 && j == 15) events_reg[15][15] = events_15_15;
                        end
                    end
                end else begin
                    next_state = IDLE;
                end
            end

            SEARCH: begin
                if (current_event_type < m_types) begin
                    if (current_telescope < n_telem) begin
                        if (len_reg[current_telescope] % current_duration == events_reg[current_telescope][current_event_type] % current_duration) begin
                            current_telescope = current_telescope + 4'd1;
                        end else begin
                            current_telescope = 4'd0;
                            current_duration = current_duration + 8'd1;
                            cycle_count = cycle_count + 8'd1;
                        end
                    end else begin
                        if (current_event_type == 4'd0) result_0 = current_duration;
                        else if (current_event_type == 4'd1) result_1 = current_duration;
                        else if (current_event_type == 4'd2) result_2 = current_duration;
                        else if (current_event_type == 4'd3) result_3 = current_duration;
                        else if (current_event_type == 4'd4) result_4 = current_duration;
                        else if (current_event_type == 4'd5) result_5 = current_duration;
                        else if (current_event_type == 4'd6) result_6 = current_duration;
                        else if (current_event_type == 4'd7) result_7 = current_duration;
                        else if (current_event_type == 4'd8) result_8 = current_duration;
                        else if (current_event_type == 4'd9) result_9 = current_duration;
                        else if (current_event_type == 4'd10) result_10 = current_duration;
                        else if (current_event_type == 4'd11) result_11 = current_duration;
                        else if (current_event_type == 4'd12) result_12 = current_duration;
                        else if (current_event_type == 4'd13) result_13 = current_duration;
                        else if (current_event_type == 4'd14) result_14 = current_duration;
                        else if (current_event_type == 4'd15) result_15 = current_duration;

                        current_event_type = current_event_type + 4'd1;
                        current_telescope = 4'd0;
                        current_duration = 8'd1;
                        cycle_count = 8'd0;
                    end
                end else begin
                    next_state = COMPLETE;
                end
            end

            VALIDATE: begin
                next_state = COMPLETE;
            end

            COMPLETE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
                done = 1'b0;
                valid = 1'b0;
            end
        endcase
    end

    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            valid = 1'b0;
            done = 1'b1;
            next_state = IDLE;
        end
    end

endmodule