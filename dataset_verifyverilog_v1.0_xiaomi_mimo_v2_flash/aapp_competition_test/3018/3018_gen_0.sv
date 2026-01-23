module dice_optimal_reroll (
    input clk, rst_n, start,
    input [3:0] K,           // Number of dice (2-8)
    input [7:0] T,           // Target sum (K to 6K)
    input [23:0] dice_in,    // 8 dice packed: [2:0]=die0, [5:3]=die1, ..., [23:21]=die7
    output reg [3:0] result, // Optimal dice count to reroll
    output reg done
);

// Internal state parameters
localparam STATE_IDLE = 4'd0;
localparam STATE_COMPUTE_S = 4'd1;
localparam STATE_ITERATE = 4'd2;
localparam STATE_UPDATE_BEST = 4'd3;
localparam STATE_FIND_RESULT = 4'd4;

// Precomputed dice distribution ROM (for R dice, sum Y)
// ways_table[R][Y] = number of ways to get sum Y with R dice
reg [21:0] ways_table [0:8][0:48];  // 22 bits for 6^8 = 1,679,616

// Initialize ROM (combinational)
integer r, y, i, j;
initial begin
    // R=0: only sum 0 has 1 way
    for (y = 0; y <= 48; y = y + 1) ways_table[0][y] = (y == 0) ? 1 : 0;
    // R=1: sums 1-6 each have 1 way
    for (y = 0; y <= 48; y = y + 1) ways_table[1][y] = (y >= 1 && y <= 6) ? 1 : 0;
    // R=2: sums 2-12
    ways_table[2][2] = 1; ways_table[2][3] = 2; ways_table[2][4] = 3;
    ways_table[2][5] = 4; ways_table[2][6] = 5; ways_table[2][7] = 6;
    ways_table[2][8] = 5; ways_table[2][9] = 4; ways_table[2][10] = 3;
    ways_table[2][11] = 2; ways_table[2][12] = 1;
    // R=3: sums 3-18
    ways_table[3][3] = 1; ways_table[3][4] = 3; ways_table[3][5] = 6;
    ways_table[3][6] = 10; ways_table[3][7] = 15; ways_table[3][8] = 21;
    ways_table[3][9] = 25; ways_table[3][10] = 27; ways_table[3][11] = 27;
    ways_table[3][12] = 25; ways_table[3][13] = 21; ways_table[3][14] = 15;
    ways_table[3][15] = 10; ways_table[3][16] = 6; ways_table[3][17] = 3;
    ways_table[3][18] = 1;
    // R=4: sums 4-24
    ways_table[4][4] = 1; ways_table[4][5] = 4; ways_table[4][6] = 10;
    ways_table[4][7] = 20; ways_table[4][8] = 35; ways_table[4][9] = 56;
    ways_table[4][10] = 80; ways_table[4][11] = 104; ways_table[4][12] = 125;
    ways_table[4][13] = 140; ways_table[4][14] = 146; ways_table[4][15] = 140;
    ways_table[4][16] = 125; ways_table[4][17] = 104; ways_table[4][18] = 80;
    ways_table[4][19] = 56; ways_table[4][20] = 35; ways_table[4][21] = 20;
    ways_table[4][22] = 10; ways_table[4][23] = 4; ways_table[4][24] = 1;
    // R=5: sums 5-30 (partial)
    ways_table[5][15] = 651; ways_table[5][16] = 771; ways_table[5][17] = 901;
    ways_table[5][18] = 1041; ways_table[5][19] = 1191; ways_table[5][20] = 1351;
    // R=6: sums 6-36 (partial)
    ways_table[6][21] = 4332; ways_table[6][22] = 4896; ways_table[6][23] = 5456;
    ways_table[6][24] = 6001; ways_table[6][25] = 6526; ways_table[6][26] = 7021;
    // R=7: sums 7-42 (partial)
    ways_table[7][24] = 14520; ways_table[7][25] = 16275; ways_table[7][26] = 18060;
    ways_table[7][27] = 19835; ways_table[7][28] = 21575; ways_table[7][29] = 23260;
    // R=8: sums 8-48 (partial)
    ways_table[8][27] = 57960; ways_table[8][28] = 63880; ways_table[8][29] = 69760;
    ways_table[8][30] = 75520; ways_table[8][31] = 81080; ways_table[8][32] = 86360;
    // Fill remaining with 0
    for (r = 0; r <= 8; r = r + 1) begin
        for (y = 0; y <= 48; y = y + 1) begin
            if (ways_table[r][y] === 24'bx) ways_table[r][y] = 22'd0;
        end
    end
end

// Internal registers
reg [3:0] state;
reg [3:0] current_K;
reg [7:0] current_T;
reg [23:0] current_dice;
reg [7:0] S;  // Current sum of dice (max 48)
reg [7:0] delta; // T - S
reg [7:0] subset_counter;  // 0 to 2^8 - 1 = 255
reg [3:0] best_R;
reg [21:0] best_ways;
reg [21:0] current_ways;
reg [3:0] current_R;
reg [7:0] X;  // Sum of dice in current subset
reg [7:0] Y;  // delta + X
reg [2:0] die_idx;  // Index for dice iteration (0-7)

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        done <= 1'b0;
        result <= 4'd0;
        best_R <= 4'd0;
        best_ways <= 22'd0;
        subset_counter <= 8'd0;
        S <= 8'd0;
        delta <= 8'd0;
        X <= 8'd0;
        current_R <= 4'd0;
        current_ways <= 22'd0;
        Y <= 8'd0;
        die_idx <= 3'd0;
        current_K <= 4'd0;
        current_T <= 8'd0;
        current_dice <= 24'd0;
    end else begin
        case (state)
            STATE_IDLE: begin
                done <= 1'b0;
                subset_counter <= 8'd0;
                best_R <= 4'd0;
                best_ways <= 22'd0;
                if (start) begin
                    current_K <= K;
                    current_T <= T;
                    current_dice <= dice_in;
                    state <= STATE_COMPUTE_S;
                    S <= 8'd0;
                    die_idx <= 3'd0;
                end
            end
            
            STATE_COMPUTE_S: begin
                if (die_idx < current_K) begin
                    S <= S + current_dice[die_idx*3 +: 3];
                    die_idx <= die_idx + 3'd1;
                end else begin
                    delta <= current_T - S;
                    state <= STATE_ITERATE;
                end
            end
            
            STATE_ITERATE: begin
                if (subset_counter < (8'd1 << current_K)) begin
                    X <= 8'd0;
                    current_R <= 4'd0;
                    die_idx <= 3'd0;
                    state <= STATE_UPDATE_BEST;
                end else begin
                    state <= STATE_FIND_RESULT;
                end
            end
            
            STATE_UPDATE_BEST: begin
                if (die_idx < current_K) begin
                    if (subset_counter[die_idx]) begin
                        X <= X + current_dice[die_idx*3 +: 3];
                        current_R <= current_R + 4'd1;
                    end
                    die_idx <= die_idx + 3'd1;
                end else begin
                    Y <= delta + X;
                    // Check if Y is valid [current_R, 6*current_R]
                    if (Y >= current_R && Y <= (current_R * 4'd6) && current_R <= current_K) begin
                        current_ways <= ways_table[current_R][Y];
                    end else begin
                        current_ways <= 22'd0;
                    end
                    // Update best
                    if (current_ways > best_ways || (current_ways == best_ways && current_R < best_R && current_ways != 22'd0)) begin
                        best_ways <= current_ways;
                        best_R <= current_R;
                    end
                    subset_counter <= subset_counter + 8'd1;
                    state <= STATE_ITERATE;
                end
            end
            
            STATE_FIND_RESULT: begin
                result <= best_R;
                done <= 1'b1;
                state <= STATE_IDLE;
            end
            
            default: state <= STATE_IDLE;
        endcase
    end
end

endmodule