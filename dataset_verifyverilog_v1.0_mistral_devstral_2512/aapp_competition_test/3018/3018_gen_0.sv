module dice_optimal_reroll(
    input clk,
    input rst_n,
    input start,
    input [3:0] K,
    input [7:0] T,
    input [23:0] dice_in,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_S = 3'd1;
    localparam [2:0] ITERATE = 3'd2;
    localparam [2:0] UPDATE_BEST = 3'd3;
    localparam [2:0] FIND_RESULT = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] current_K;
    reg [7:0] current_T;
    reg [23:0] current_dice;
    reg [7:0] S;
    reg [7:0] delta;
    reg [7:0] subset_counter;
    reg [3:0] best_R;
    reg [21:0] best_ways;
    reg [21:0] current_ways;
    reg [3:0] current_R;
    reg [7:0] X;
    reg [7:0] Y;
    reg [7:0] dice_sum;
    reg [2:0] die_idx;

    // Precomputed ways table (simplified for synthesis)
    reg [21:0] ways_table [0:8][0:48];

    // Initialize ways table (combinational)
    integer r, y;
    always @(*) begin
        // R=0
        for (y = 0; y <= 48; y = y + 1) ways_table[0][y] = (y == 0) ? 22'd1 : 22'd0;
        // R=1
        for (y = 0; y <= 48; y = y + 1) ways_table[1][y] = (y >= 1 && y <= 6) ? 22'd1 : 22'd0;
        // R=2
        ways_table[2][2] = 22'd1; ways_table[2][3] = 22'd2; ways_table[2][4] = 22'd3;
        ways_table[2][5] = 22'd4; ways_table[2][6] = 22'd5; ways_table[2][7] = 22'd6;
        ways_table[2][8] = 22'd5; ways_table[2][9] = 22'd4; ways_table[2][10] = 22'd3;
        ways_table[2][11] = 22'd2; ways_table[2][12] = 22'd1;
        // R=3
        ways_table[3][3] = 22'd1; ways_table[3][4] = 22'd3; ways_table[3][5] = 22'd6;
        ways_table[3][6] = 22'd10; ways_table[3][7] = 22'd15; ways_table[3][8] = 22'd21;
        ways_table[3][9] = 22'd25; ways_table[3][10] = 22'd27; ways_table[3][11] = 22'd27;
        ways_table[3][12] = 22'd25; ways_table[3][13] = 22'd21; ways_table[3][14] = 22'd15;
        ways_table[3][15] = 22'd10; ways_table[3][16] = 22'd6; ways_table[3][17] = 22'd3;
        ways_table[3][18] = 22'd1;
        // R=4
        ways_table[4][4] = 22'd1; ways_table[4][5] = 22'd4; ways_table[4][6] = 22'd10;
        ways_table[4][7] = 22'd20; ways_table[4][8] = 22'd35; ways_table[4][9] = 22'd56;
        ways_table[4][10] = 22'd80; ways_table[4][11] = 22'd104; ways_table[4][12] = 22'd125;
        ways_table[4][13] = 22'd140; ways_table[4][14] = 22'd146; ways_table[4][15] = 22'd140;
        ways_table[4][16] = 22'd125; ways_table[4][17] = 22'd104; ways_table[4][18] = 22'd80;
        ways_table[4][19] = 22'd56; ways_table[4][20] = 22'd35; ways_table[4][21] = 22'd20;
        ways_table[4][22] = 22'd10; ways_table[4][23] = 22'd4; ways_table[4][24] = 22'd1;
        // R=5 (partial)
        ways_table[5][15] = 22'd651; ways_table[5][16] = 22'd771; ways_table[5][17] = 22'd901;
        ways_table[5][18] = 22'd1041; ways_table[5][19] = 22'd1191; ways_table[5][20] = 22'd1351;
        // R=6 (partial)
        ways_table[6][21] = 22'd4332; ways_table[6][22] = 22'd4896; ways_table[6][23] = 22'd5456;
        ways_table[6][24] = 22'd6001; ways_table[6][25] = 22'd6526; ways_table[6][26] = 22'd7021;
        // R=7 (partial)
        ways_table[7][24] = 22'd14520; ways_table[7][25] = 22'd16275; ways_table[7][26] = 22'd18060;
        ways_table[7][27] = 22'd19835; ways_table[7][28] = 22'd21575; ways_table[7][29] = 22'd23260;
        // R=8 (partial)
        ways_table[8][27] = 22'd57960; ways_table[8][28] = 22'd63880; ways_table[8][29] = 22'd69760;
        ways_table[8][30] = 22'd75520; ways_table[8][31] = 22'd81080; ways_table[8][32] = 22'd86360;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            best_R <= 4'd0;
            best_ways <= 22'd0;
            subset_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_K <= K;
                        current_T <= T;
                        current_dice <= dice_in;
                        state <= COMPUTE_S;
                        S <= 8'd0;
                        die_idx <= 3'd0;
                    end
                end

                COMPUTE_S: begin
                    if (die_idx < current_K) begin
                        S <= S + current_dice[die_idx*3 +: 3];
                        die_idx <= die_idx + 1'b1;
                    end else begin
                        delta <= current_T - S;
                        subset_counter <= 8'd0;
                        best_R <= 4'd0;
                        best_ways <= 22'd0;
                        state <= ITERATE;
                    end
                end

                ITERATE: begin
                    if (subset_counter < (1 << current_K)) begin
                        X <= 8'd0;
                        current_R <= 4'd0;
                        die_idx <= 3'd0;
                        state <= UPDATE_BEST;
                    end else begin
                        state <= FIND_RESULT;
                    end
                end

                UPDATE_BEST: begin
                    if (die_idx < current_K) begin
                        if (subset_counter[die_idx]) begin
                            X <= X + current_dice[die_idx*3 +: 3];
                            current_R <= current_R + 1'b1;
                        end
                        die_idx <= die_idx + 1'b1;
                    end else begin
                        Y <= delta + X;
                        if (Y >= current_R && Y <= (6 * current_R) && current_R <= current_K) begin
                            current_ways <= ways_table[current_R][Y];
                        end else begin
                            current_ways <= 22'd0;
                        end
                        subset_counter <= subset_counter + 1'b1;
                        state <= ITERATE;

                        if (current_ways > best_ways || (current_ways == best_ways && current_R < best_R && current_ways != 0)) begin
                            best_ways <= current_ways;
                            best_R <= current_R;
                        end
                    end
                end

                FIND_RESULT: begin
                    result <= best_R;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule