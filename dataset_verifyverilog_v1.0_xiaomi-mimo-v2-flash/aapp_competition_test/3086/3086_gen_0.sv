module TelescopeDurationCalculator (
    input clk,
    input rst_n,
    input start,
    input [4:0] n_telem,
    input [4:0] m_types,
    input [8:0] start_day_0, start_day_1, start_day_2, start_day_3,
    input [8:0] start_day_4, start_day_5, start_day_6, start_day_7,
    input [8:0] start_day_8, start_day_9, start_day_10, start_day_11,
    input [8:0] start_day_12, start_day_13, start_day_14, start_day_15,
    input [8:0] end_day_0, end_day_1, end_day_2, end_day_3,
    input [8:0] end_day_4, end_day_5, end_day_6, end_day_7,
    input [8:0] end_day_8, end_day_9, end_day_10, end_day_11,
    input [8:0] end_day_12, end_day_13, end_day_14, end_day_15,
    input [7:0] events_0_0, events_0_1, events_0_2, events_0_3,
    input [7:0] events_0_4, events_0_5, events_0_6, events_0_7,
    input [7:0] events_0_8, events_0_9, events_0_10, events_0_11,
    input [7:0] events_0_12, events_0_13, events_0_14, events_0_15,
    input [7:0] events_1_0, events_1_1, events_1_2, events_1_3,
    input [7:0] events_1_4, events_1_5, events_1_6, events_1_7,
    input [7:0] events_1_8, events_1_9, events_1_10, events_1_11,
    input [7:0] events_1_12, events_1_13, events_1_14, events_1_15,
    input [7:0] events_2_0, events_2_1, events_2_2, events_2_3,
    input [7:0] events_2_4, events_2_5, events_2_6, events_2_7,
    input [7:0] events_2_8, events_2_9, events_2_10, events_2_11,
    input [7:0] events_2_12, events_2_13, events_2_14, events_2_15,
    input [7:0] events_3_0, events_3_1, events_3_2, events_3_3,
    input [7:0] events_3_4, events_3_5, events_3_6, events_3_7,
    input [7:0] events_3_8, events_3_9, events_3_10, events_3_11,
    input [7:0] events_3_12, events_3_13, events_3_14, events_3_15,
    input [7:0] events_4_0, events_4_1, events_4_2, events_4_3,
    input [7:0] events_4_4, events_4_5, events_4_6, events_4_7,
    input [7:0] events_4_8, events_4_9, events_4_10, events_4_11,
    input [7:0] events_4_12, events_4_13, events_4_14, events_4_15,
    input [7:0] events_5_0, events_5_1, events_5_2, events_5_3,
    input [7:0] events_5_4, events_5_5, events_5_6, events_5_7,
    input [7:0] events_5_8, events_5_9, events_5_10, events_5_11,
    input [7:0] events_5_12, events_5_13, events_5_14, events_5_15,
    input [7:0] events_6_0, events_6_1, events_6_2, events_6_3,
    input [7:0] events_6_4, events_6_5, events_6_6, events_6_7,
    input [7:0] events_6_8, events_6_9, events_6_10, events_6_11,
    input [7:0] events_6_12, events_6_13, events_6_14, events_6_15,
    input [7:0] events_7_0, events_7_1, events_7_2, events_7_3,
    input [7:0] events_7_4, events_7_5, events_7_6, events_7_7,
    input [7:0] events_7_8, events_7_9, events_7_10, events_7_11,
    input [7:0] events_7_12, events_7_13, events_7_14, events_7_15,
    input [7:0] events_8_0, events_8_1, events_8_2, events_8_3,
    input [7:0] events_8_4, events_8_5, events_8_6, events_8_7,
    input [7:0] events_8_8, events_8_9, events_8_10, events_8_11,
    input [7:0] events_8_12, events_8_13, events_8_14, events_8_15,
    input [7:0] events_9_0, events_9_1, events_9_2, events_9_3,
    input [7:0] events_9_4, events_9_5, events_9_6, events_9_7,
    input [7:0] events_9_8, events_9_9, events_9_10, events_9_11,
    input [7:0] events_9_12, events_9_13, events_9_14, events_9_15,
    input [7:0] events_10_0, events_10_1, events_10_2, events_10_3,
    input [7:0] events_10_4, events_10_5, events_10_6, events_10_7,
    input [7:0] events_10_8, events_10_9, events_10_10, events_10_11,
    input [7:0] events_10_12, events_10_13, events_10_14, events_10_15,
    input [7:0] events_11_0, events_11_1, events_11_2, events_11_3,
    input [7:0] events_11_4, events_11_5, events_11_6, events_11_7,
    input [7:0] events_11_8, events_11_9, events_11_10, events_11_11,
    input [7:0] events_11_12, events_11_13, events_11_14, events_11_15,
    input [7:0] events_12_0, events_12_1, events_12_2, events_12_3,
    input [7:0] events_12_4, events_12_5, events_12_6, events_12_7,
    input [7:0] events_12_8, events_12_9, events_12_10, events_12_11,
    input [7:0] events_12_12, events_12_13, events_12_14, events_12_15,
    input [7:0] events_13_0, events_13_1, events_13_2, events_13_3,
    input [7:0] events_13_4, events_13_5, events_13_6, events_13_7,
    input [7:0] events_13_8, events_13_9, events_13_10, events_13_11,
    input [7:0] events_13_12, events_13_13, events_13_14, events_13_15,
    input [7:0] events_14_0, events_14_1, events_14_2, events_14_3,
    input [7:0] events_14_4, events_14_5, events_14_6, events_14_7,
    input [7:0] events_14_8, events_14_9, events_14_10, events_14_11,
    input [7:0] events_14_12, events_14_13, events_14_14, events_14_15,
    input [7:0] events_15_0, events_15_1, events_15_2, events_15_3,
    input [7:0] events_15_4, events_15_5, events_15_6, events_15_7,
    input [7:0] events_15_8, events_15_9, events_15_10, events_15_11,
    input [7:0] events_15_12, events_15_13, events_15_14, events_15_15,
    output reg [7:0] result_0, result_1, result_2, result_3,
    output reg [7:0] result_4, result_5, result_6, result_7,
    output reg [7:0] result_8, result_9, result_10, result_11,
    output reg [7:0] result_12, result_13, result_14, result_15,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] VALIDATE = 3'd2;
    localparam [2:0] COMPLETE = 3'd3;

    reg [2:0] state;
    reg [4:0] type_idx;
    reg [7:0] duration;
    reg [4:0] telescope_idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    reg valid_duration_found;
    
    // Internal registers for telescope data
    reg [8:0] start_days [0:15];
    reg [8:0] end_days [0:15];
    reg [7:0] events [0:15][0:15];
    
    // Calculation registers
    reg [8:0] obs_len;
    reg [7:0] event_count;
    reg modulo_fail;
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
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
            type_idx <= 5'd0;
            duration <= 8'd0;
            telescope_idx <= 5'd0;
            cycle_count <= 8'd0;
            valid_duration_found <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                start_days[i] <= 9'd0;
                end_days[i] <= 9'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    events[i][j] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    type_idx <= 5'd0;
                    duration <= 8'd0;
                    telescope_idx <= 5'd0;
                    cycle_count <= 8'd0;
                    valid_duration_found <= 1'b0;
                    if (start) begin
                        // Load all telescope data
                        start_days[0] <= start_day_0;
                        start_days[1] <= start_day_1;
                        start_days[2] <= start_day_2;
                        start_days[3] <= start_day_3;
                        start_days[4] <= start_day_4;
                        start_days[5] <= start_day_5;
                        start_days[6] <= start_day_6;
                        start_days[7] <= start_day_7;
                        start_days[8] <= start_day_8;
                        start_days[9] <= start_day_9;
                        start_days[10] <= start_day_10;
                        start_days[11] <= start_day_11;
                        start_days[12] <= start_day_12;
                        start_days[13] <= start_day_13;
                        start_days[14] <= start_day_14;
                        start_days[15] <= start_day_15;
                        end_days[0] <= end_day_0;
                        end_days[1] <= end_day_1;
                        end_days[2] <= end_day_2;
                        end_days[3] <= end_day_3;
                        end_days[4] <= end_day_4;
                        end_days[5] <= end_day_5;
                        end_days[6] <= end_day_6;
                        end_days[7] <= end_day_7;
                        end_days[8] <= end_day_8;
                        end_days[9] <= end_day_9;
                        end_days[10] <= end_day_10;
                        end_days[11] <= end_day_11;
                        end_days[12] <= end_day_12;
                        end_days[13] <= end_day_13;
                        end_days[14] <= end_day_14;
                        end_days[15] <= end_day_15;
                        events[0][0] <= events_0_0; events[0][1] <= events_0_1; events[0][2] <= events_0_2; events[0][3] <= events_0_3;
                        events[0][4] <= events_0_4; events[0][5] <= events_0_5; events[0][6] <= events_0_6; events[0][7] <= events_0_7;
                        events[0][8] <= events_0_8; events[0][9] <= events_0_9; events[0][10] <= events_0_10; events[0][11] <= events_0_11;
                        events[0][12] <= events_0_12; events[0][13] <= events_0_13; events[0][14] <= events_0_14; events[0][15] <= events_0_15;
                        events[1][0] <= events_1_0; events[1][1] <= events_1_1; events[1][2] <= events_1_2; events[1][3] <= events_1_3;
                        events[1][4] <= events_1_4; events[1][5] <= events_1_5; events[1][6] <= events_1_6; events[1][7] <= events_1_7;
                        events[1][8] <= events_1_8; events[1][9] <= events_1_9; events[1][10] <= events_1_10; events[1][11] <= events_1_11;
                        events[1][12] <= events_1_12; events[1][13] <= events_1_13; events[1][14] <= events_1_14; events[1][15] <= events_1_15;
                        events[2][0] <= events_2_0; events[2][1] <= events_2_1; events[2][2] <= events_2_2; events[2][3] <= events_2_3;
                        events[2][4] <= events_2_4; events[2][5] <= events_2_5; events[2][6] <= events_2_6; events[2][7] <= events_2_7;
                        events[2][8] <= events_2_8; events[2][9] <= events_2_9; events[2][10] <= events_2_10; events[2][11] <= events_2_11;
                        events[2][12] <= events_2_12; events[2][13] <= events_2_13; events[2][14] <= events_2_14; events[2][15] <= events_2_15;
                        events[3][0] <= events_3_0; events[3][1] <= events_3_1; events[3][2] <= events_3_2; events[3][3] <= events_3_3;
                        events[3][4] <= events_3_4; events[3][5] <= events_3_5; events[3][6] <= events_3_6; events[3][7] <= events_3_7;
                        events[3][8] <= events_3_8; events[3][9] <= events_3_9; events[3][10] <= events_3_10; events[3][11] <= events_3_11;
                        events[3][12] <= events_3_12; events[3][13] <= events_3_13; events[3][14] <= events_3_14; events[3][15] <= events_3_15;
                        events[4][0] <= events_4_0; events[4][1] <= events_4_1; events[4][2] <= events_4_2; events[4][3] <= events_4_3;
                        events[4][4] <= events_4_4; events[4][5] <= events_4_5; events[4][6] <= events_4_6; events[4][7] <= events_4_7;
                        events[4][8] <= events_4_8; events[4][9] <= events_4_9; events[4][10] <= events_4_10; events[4][11] <= events_4_11;
                        events[4][12] <= events_4_12; events[4][13] <= events_4_13; events[4][14] <= events_4_14; events[4][15] <= events_4_15;
                        events[5][0] <= events_5_0; events[5][1] <= events_5_1; events[5][2] <= events_5_2; events[5][3] <= events_5_3;
                        events[5][4] <= events_5_4; events[5][5] <= events_5_5; events[5][6] <= events_5_6; events[5][7] <= events_5_7;
                        events[5][8] <= events_5_8; events[5][9] <= events_5_9; events[5][10] <= events_5_10; events[5][11] <= events_5_11;
                        events[5][12] <= events_5_12; events[5][13] <= events_5_13; events[5][14] <= events_5_14; events[5][15] <= events_5_15;
                        events[6][0] <= events_6_0; events[6][1] <= events_6_1; events[6][2] <= events_6_2; events[6][3] <= events_6_3;
                        events[6][4] <= events_6_4; events[6][5] <= events_6_5; events[6][6] <= events_6_6; events[6][7] <= events_6_7;
                        events[6][8] <= events_6_8; events[6][9] <= events_6_9; events[6][10] <= events_6_10; events[6][11] <= events_6_11;
                        events[6][12] <= events_6_12; events[6][13] <= events_6_13; events[6][14] <= events_6_14; events[6][15] <= events_6_15;
                        events[7][0] <= events_7_0; events[7][1] <= events_7_1; events[7][2] <= events_7_2; events[7][3] <= events_7_3;
                        events[7][4] <= events_7_4; events[7][5] <= events_7_5; events[7][6] <= events_7_6; events[7][7] <= events_7_7;
                        events[7][8] <= events_7_8; events[7][9] <= events_7_9; events[7][10] <= events_7_10; events[7][11] <= events_7_11;
                        events[7][12] <= events_7_12; events[7][13] <= events_7_13; events[7][14] <= events_7_14; events[7][15] <= events_7_15;
                        events[8][0] <= events_8_0; events[8][1] <= events_8_1; events[8][2] <= events_8_2; events[8][3] <= events_8_3;
                        events[8][4] <= events_8_4; events[8][5] <= events_8_5; events[8][6] <= events_8_6; events[8][7] <= events_8_7;
                        events[8][8] <= events_8_8; events[8][9] <= events_8_9; events[8][10] <= events_8_10; events[8][11] <= events_8_11;
                        events[8][12] <= events_8_12; events[8][13] <= events_8_13; events[8][14] <= events_8_14; events[8][15] <= events_8_15;
                        events[9][0] <= events_9_0; events[9][1] <= events_9_1; events[9][2] <= events_9_2; events[9][3] <= events_9_3;
                        events[9][4] <= events_9_4; events[9][5] <= events_9_5; events[9][6] <= events_9_6; events[9][7] <= events_9_7;
                        events[9][8] <= events_9_8; events[9][9] <= events_9_9; events[9][10] <= events_9_10; events[9][11] <= events_9_11;
                        events[9][12] <= events_9_12; events[9][13] <= events_9_13; events[9][14] <= events_9_14; events[9][15] <= events_9_15;
                        events[10][0] <= events_10_0; events[10][1] <= events_10_1; events[10][2] <= events_10_2; events[10][3] <= events_10_3;
                        events[10][4] <= events_10_4; events[10][5] <= events_10_5; events[10][6] <= events_10_6; events[10][7] <= events_10_7;
                        events[10][8] <= events_10_8; events[10][9] <= events_10_9; events[10][10] <= events_10_10; events[10][11] <= events_10_11;
                        events[10][12] <= events_10_12; events[10][13] <= events_10_13; events[10][14] <= events_10_14; events[10][15] <= events_10_15;
                        events[11][0] <= events_11_0; events[11][1] <= events_11_1; events[11][2] <= events_11_2; events[11][3] <= events_11_3;
                        events[11][4] <= events_11_4; events[11][5] <= events_11_5; events[11][6] <= events_11_6; events[11][7] <= events_11_7;
                        events[11][8] <= events_11_8; events[11][9] <= events_11_9; events[11][10] <= events_11_10; events[11][11] <= events_11_11;
                        events[11][12] <= events_11_12; events[11][13] <= events_11_13; events[11][14] <= events_11_14; events[11][15] <= events_11_15;
                        events[12][0] <= events_12_0; events[12][1] <= events_12_1; events[12][2] <= events_12_2; events[12][3] <= events_12_3;
                        events[12][4] <= events_12_4; events[12][5] <= events_12_5; events[12][6] <= events_12_6; events[12][7] <= events_12_7;
                        events[12][8] <= events_12_8; events[12][9] <= events_12_9; events[12][10] <= events_12_10; events[12][11] <= events_12_11;
                        events[12][12] <= events_12_12; events[12][13] <= events_12_13; events[12][14] <= events_12_14; events[12][15] <= events_12_15;
                        events[13][0] <= events_13_0; events[13][1] <= events_13_1; events[13][2] <= events_13_2; events[13][3] <= events_13_3;
                        events[13][4] <= events_13_4; events[13][5] <= events_13_5; events[13][6] <= events_13_6; events[13][7] <= events_13_7;
                        events[13][8] <= events_13_8; events[13][9] <= events_13_9; events[13][10] <= events_13_10; events[13][11] <= events_13_11;
                        events[13][12] <= events_13_12; events[13][13] <= events_13_13; events[13][14] <= events_13_14; events[13][15] <= events_13_15;
                        events[14][0] <= events_14_0; events[14][1] <= events_14_1; events[14][2] <= events_14_2; events[14][3] <= events_14_3;
                        events[14][4] <= events_14_4; events[14][5] <= events_14_5; events[14][6] <= events_14_6; events[14][7] <= events_14_7;
                        events[14][8] <= events_14_8; events[14][9] <= events_14_9; events[14][10] <= events_14_10; events[14][11] <= events_14_11;
                        events[14][12] <= events_14_12; events[14][13] <= events_14_13; events[14][14] <= events_14_14; events[14][15] <= events_14_15;
                        events[15][0] <= events_15_0; events[15][1] <= events_15_1; events[15][2] <= events_15_2; events[15][3] <= events_15_3;
                        events[15][4] <= events_15_4; events[15][5] <= events_15_5; events[15][6] <= events_15_6; events[15][7] <= events_15_7;
                        events[15][8] <= events_15_8; events[15][9] <= events_15_9; events[15][10] <= events_15_10; events[15][11] <= events_15_11;
                        events[15][12] <= events_15_12; events[15][13] <= events_15_13; events[15][14] <= events_15_14; events[15][15] <= events_15_15;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    duration <= duration + 8'd1;
                    cycle_count <= cycle_count + 8'd1;
                    telescope_idx <= 5'd0;
                    valid_duration_found <= 1'b0;
                    if ((duration >= 8'd255) || (cycle_count >= MAX_CYCLES)) begin
                        // No valid duration found
                        case (type_idx)
                            5'd0: result_0 <= 8'd0;
                            5'd1: result_1 <= 8'd0;
                            5'd2: result_2 <= 8'd0;
                            5'd3: result_3 <= 8'd0;
                            5'd4: result_4 <= 8'd0;
                            5'd5: result_5 <= 8'd0;
                            5'd6: result_6 <= 8'd0;
                            5'd7: result_7 <= 8'd0;
                            5'd8: result_8 <= 8'd0;
                            5'd9: result_9 <= 8'd0;
                            5'd10: result_10 <= 8'd0;
                            5'd11: result_11 <= 8'd0;
                            5'd12: result_12 <= 8'd0;
                            5'd13: result_13 <= 8'd0;
                            5'd14: result_14 <= 8'd0;
                            5'd15: result_15 <= 8'd0;
                            default: result_0 <= 8'd0;
                        endcase
                        state <= COMPLETE;
                    end else begin
                        state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    // Check all telescopes for current duration and type
                    if (telescope_idx < n_telem) begin
                        // Calculate observation length
                        if (end_days[telescope_idx] < start_days[telescope_idx]) begin
                            obs_len <= (end_days[telescope_idx] + 9'd365) - start_days[telescope_idx];
                        end else begin
                            obs_len <= end_days[telescope_idx] - start_days[telescope_idx];
                        end
                        event_count <= events[telescope_idx][type_idx];
                        
                        // Check congruence in next cycle
                        if (telescope_idx == 5'd0) begin
                            modulo_fail <= 1'b0;
                        end
                        state <= 3'd4; // Transition to modulo check state
                    end else begin
                        // All telescopes checked successfully
                        valid_duration_found <= 1'b1;
                        case (type_idx)
                            5'd0: result_0 <= duration;
                            5'd1: result_1 <= duration;
                            5'd2: result_2 <= duration;
                            5'd3: result_3 <= duration;
                            5'd4: result_4 <= duration;
                            5'd5: result_5 <= duration;
                            5'd6: result_6 <= duration;
                            5'd7: result_7 <= duration;
                            5'd8: result_8 <= duration;
                            5'd9: result_9 <= duration;
                            5'd10: result_10 <= duration;
                            5'd11: result_11 <= duration;
                            5'd12: result_12 <= duration;
                            5'd13: result_13 <= duration;
                            5'd14: result_14 <= duration;
                            5'd15: result_15 <= duration;
                            default: result_0 <= duration;
                        endcase
                        state <= 3'd5; // Transition to next type state
                    end
                end

                3'd4: begin // Modulo check state
                    // Check: (len % d == events_i_j % d)
                    // Since d <= 255 and events <= 255, both modulo results are same if len % d == events % d
                    // Actually need to compare modulo results: (obs_len % duration) == (event_count % duration)
                    // For simplicity, we check if (obs_len - event_count) % duration == 0
                    if (obs_len >= event_count) begin
                        if (((obs_len - event_count) % duration) != 8'd0) begin
                            modulo_fail <= 1'b1;
                        end
                    end else begin
                        if (((event_count - obs_len) % duration) != 8'd0) begin
                            modulo_fail <= 1'b1;
                        end
                    end
                    telescope_idx <= telescope_idx + 5'd1;
                    state <= VALIDATE;
                end

                3'd5: begin // Next type state
                    type_idx <= type_idx + 5'd1;
                    duration <= 8'd0;
                    cycle_count <= 8'd0;
                    if ((type_idx + 5'd1) >= m_types) begin
                        state <= COMPLETE;
                    end else begin
                        state <= SEARCH;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Additional combinational logic for modulo check
    // Since modulo operation isn't directly supported in combinational for all cases,
    // we use a separate always block for the modulo check
    reg [8:0] obs_len_reg;
    reg [7:0] event_count_reg;
    reg [7:0] duration_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            obs_len_reg <= 9'd0;
            event_count_reg <= 8'd0;
            duration_reg <= 8'd0;
        end else begin
            if (state == VALIDATE && telescope_idx < n_telem) begin
                obs_len_reg <= obs_len;
                event_count_reg <= event_count;
                duration_reg <= duration;
            end
        end
    end
endmodule