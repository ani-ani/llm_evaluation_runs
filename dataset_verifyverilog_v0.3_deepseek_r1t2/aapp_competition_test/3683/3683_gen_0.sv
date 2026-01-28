module MiniGolfMinRank(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] score_0_0, score_0_1, score_0_2, score_0_3, score_0_4, score_0_5, score_0_6, score_0_7,
    input wire [7:0] score_1_0, score_1_1, score_1_2, score_1_3, score_1_4, score_1_5, score_1_6, score_1_7,
    input wire [7:0] score_2_0, score_2_1, score_2_2, score_2_3, score_2_4, score_2_5, score_2_6, score_2_7,
    input wire [7:0] score_3_0, score_3_1, score_3_2, score_3_3, score_3_4, score_3_5, score_3_6, score_3_7,
    input wire [7:0] score_4_0, score_4_1, score_4_2, score_4_3, score_4_4, score_4_5, score_4_6, score_4_7,
    input wire [7:0] score_5_0, score_5_1, score_5_2, score_5_3, score_5_4, score_5_5, score_5_6, score_5_7,
    input wire [7:0] score_6_0, score_6_1, score_6_2, score_6_3, score_6_4, score_6_5, score_6_6, score_6_7,
    input wire [7:0] score_7_0, score_7_1, score_7_2, score_7_3, score_7_4, score_7_5, score_7_6, score_7_7,
    output reg [3:0] min_rank_0, min_rank_1, min_rank_2, min_rank_3, min_rank_4, min_rank_5, min_rank_6, min_rank_7,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE              = 3'd0;
    localparam [2:0] COMPUTE_ADJUSTED  = 3'd1;
    localparam [2:0] COMPUTE_RANKS     = 3'd2;
    localparam [2:0] UPDATE_MIN_RANK   = 3'd3;
    localparam [2:0] INCREMENT_LL      = 3'd4;
    localparam [2:0] FINISHED          = 3'd5;
    reg [2:0] state, next_state;

    // Internal data storage
    reg [7:0] ll;  // ℓ counter (1-255)
    reg [7:0] adjusted_total [0:7];
    reg [3:0] current_rank [0:7];
    
    // Loop counters
    reg [2:0] player_idx;
    reg [2:0] hole_idx;
    reg [2:0] compare_player;

    // Internal score array
    reg [7:0] score [0:7][0:7];

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all outputs and internal regs
            state <= IDLE;
            done <= 1'b0;
            ll <= 8'd0;
            player_idx <= 3'd0;
            hole_idx <= 3'd0;
            compare_player <= 3'd0;
            
            // Initialize min_rank outputs
            min_rank_0 <= 4'd15;
            min_rank_1 <= 4'd15;
            min_rank_2 <= 4'd15;
            min_rank_3 <= 4'd15;
            min_rank_4 <= 4'd15;
            min_rank_5 <= 4'd15;
            min_rank_6 <= 4'd15;
            min_rank_7 <= 4'd15;
            
            // Initialize arrays for scores
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    score[i][j] <= 8'd0;
                end
                adjusted_total[i] <= 8'd0;
                current_rank[i] <= 4'd0;
            end
        end else begin
            // Store input scores in internal array
            // Player 0
            score[0][0] <= score_0_0;
            score[0][1] <= score_0_1;
            score[0][2] <= score_0_2;
            score[0][3] <= score_0_3;
            score[0][4] <= score_0_4;
            score[0][5] <= score_0_5;
            score[0][6] <= score_0_6;
            score[0][7] <= score_0_7;
            
            // Player 1
            score[1][0] <= score_1_0;
            score[1][1] <= score_1_1;
            score[1][2] <= score_1_2;
            score[1][3] <= score_1_3;
            score[1][4] <= score_1_4;
            score[1][5] <= score_1_5;
            score[1][6] <= score_1_6;
            score[1][7] <= score_1_7;
            
            // Player 2
            score[2][0] <= score_2_0;
            score[2][1] <= score_2_1;
            score[2][2] <= score_2_2;
            score[2][3] <= score_2_3;
            score[2][4] <= score_2_4;
            score[2][5] <= score_2_5;
            score[2][6] <= score_2_6;
            score[2][7] <= score_2_7;
            
            // Player 3
            score[3][0] <= score_3_0;
            score[3][1] <= score_3_1;
            score[3][2] <= score_3_2;
            score[3][3] <= score_3_3;
            score[3][4] <= score_3_4;
            score[3][5] <= score_3_5;
            score[3][6] <= score_3_6;
            score[3][7] <= score_3_7;
            
            // Player 4
            score[4][0] <= score_4_0;
            score[4][1] <= score_4_1;
            score[4][2] <= score_4_2;
            score[4][3] <= score_4_3;
            score[4][4] <= score_4_4;
            score[4][5] <= score_4_5;
            score[4][6] <= score_4_6;
            score[4][7] <= score_4_7;
            
            // Player 5
            score[5][0] <= score_5_0;
            score[5][1] <= score_5_1;
            score[5][2] <= score_5_2;
            score[5][3] <= score_5_3;
            score[5][4] <= score_5_4;
            score[5][5] <= score_5_5;
            score[5][6] <= score_5_6;
            score[5][7] <= score_5_7;
            
            // Player 6
            score[6][0] <= score_6_0;
            score[6][1] <= score_6_1;
            score[6][2] <= score_6_2;
            score[6][3] <= score_6_3;
            score[6][4] <= score_6_4;
            score[6][5] <= score_6_5;
            score[6][6] <= score_6_6;
            score[6][7] <= score_6_7;
            
            // Player 7
            score[7][0] <= score_7_0;
            score[7][1] <= score_7_1;
            score[7][2] <= score_7_2;
            score[7][3] <= score_7_3;
            score[7][4] <= score_7_4;
            score[7][5] <= score_7_5;
            score[7][6] <= score_7_6;
            score[7][7] <= score_7_7;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        ll <= 8'd1;
                        player_idx <= 3'd0;
                        hole_idx <= 3'd0;
                        compare_player <= 3'd0;
                        state <= COMPUTE_ADJUSTED;
                        
                        // Initialize min_ranks to max possible rank (7+1=8, but 4'b1111 is 15, safe)
                        min_rank_0 <= 4'd15;
                        min_rank_1 <= 4'd15;
                        min_rank_2 <= 4'd15;
                        min_rank_3 <= 4'd15;
                        min_rank_4 <= 4'd15;
                        min_rank_5 <= 4'd15;
                        min_rank_6 <= 4'd15;
                        min_rank_7 <= 4'd15;
                    end
                end
                
                COMPUTE_ADJUSTED: begin
                    // Compute min(score[player_idx][hole_idx], ll) and accumulate
                    if (hole_idx == 3'd7) begin
                        // Last hole for this player
                        if (score[player_idx][hole_idx] <= ll)
                            adjusted_total[player_idx] <= adjusted_total[player_idx] + score[player_idx][hole_idx];
                        else
                            adjusted_total[player_idx] <= adjusted_total[player_idx] + ll;
                        
                        hole_idx <= 3'd0;
                        if (player_idx == 3'd7) begin
                            // Processed all players
                            player_idx <= 3'd0;
                            state <= COMPUTE_RANKS;
                        end else begin
                            player_idx <= player_idx + 3'd1;
                        end
                    end else begin
                        if (score[player_idx][hole_idx] <= ll)
                            adjusted_total[player_idx] <= adjusted_total[player_idx] + score[player_idx][hole_idx];
                        else
                            adjusted_total[player_idx] <= adjusted_total[player_idx] + ll;
                        
                        hole_idx <= hole_idx + 3'd1;
                    end
                end
                
                COMPUTE_RANKS: begin
                    // Reset current_rank registers each time we start a new comparison
                    if (player_idx == 3'd0 && compare_player == 3'd0) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            current_rank[i] <= 4'd0;
                        end
                    end
                    
                    if (player_idx == 3'd7 && compare_player == 3'd7) begin
                        state <= UPDATE_MIN_RANK;
                    end else begin
                        // Compare player_idx's adjusted total with compare_player's
                        if (adjusted_total[player_idx] <= adjusted_total[compare_player]) begin
                            current_rank[player_idx] <= current_rank[player_idx] + 4'd1;
                        end
                        
                        if (compare_player == 3'd7) begin
                            compare_player <= 3'd0;
                            player_idx <= player_idx + 3'd1;
                        end else begin
                            compare_player <= compare_player + 3'd1;
                        end
                    end
                end
                
                UPDATE_MIN_RANK: begin
                    // Update min_rank for each player if current_rank is smaller
                    min_rank_0 <= (current_rank[0] < min_rank_0) ? current_rank[0] : min_rank_0;
                    min_rank_1 <= (current_rank[1] < min_rank_1) ? current_rank[1] : min_rank_1;
                    min_rank_2 <= (current_rank[2] < min_rank_2) ? current_rank[2] : min_rank_2;
                    min_rank_3 <= (current_rank[3] < min_rank_3) ? current_rank[3] : min_rank_3;
                    min_rank_4 <= (current_rank[4] < min_rank_4) ? current_rank[4] : min_rank_4;
                    min_rank_5 <= (current_rank[5] < min_rank_5) ? current_rank[5] : min_rank_5;
                    min_rank_6 <= (current_rank[6] < min_rank_6) ? current_rank[6] : min_rank_6;
                    min_rank_7 <= (current_rank[7] < min_rank_7) ? current_rank[7] : min_rank_7;
                    
                    state <= INCREMENT_LL;
                end
                
                INCREMENT_LL: begin
                    if (ll == 8'd255) begin
                        state <= FINISHED;
                    end else begin
                        ll <= ll + 8'd1;
                        player_idx <= 3'd0;
                        hole_idx <= 3'd0;
                        compare_player <= 3'd0;
                        state <= COMPUTE_ADJUSTED;
                        
                        // Reset adjusted totals for next ℓ
                        for (i = 0; i < 8; i = i + 1) begin
                            adjusted_total[i] <= 8'd0;
                        end
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule