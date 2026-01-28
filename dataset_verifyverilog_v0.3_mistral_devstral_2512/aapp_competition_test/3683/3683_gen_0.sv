module MiniGolfMinRank(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    start,
    
    // Scores: for each player i (0 to 7) and hole j (0 to 7)
    input  wire [7:0]  score_0_0, score_0_1, score_0_2, score_0_3, score_0_4, score_0_5, score_0_6, score_0_7,
                     score_1_0, score_1_1, score_1_2, score_1_3, score_1_4, score_1_5, score_1_6, score_1_7,
                     score_2_0, score_2_1, score_2_2, score_2_3, score_2_4, score_2_5, score_2_6, score_2_7,
                     score_3_0, score_3_1, score_3_2, score_3_3, score_3_4, score_3_5, score_3_6, score_3_7,
                     score_4_0, score_4_1, score_4_2, score_4_3, score_4_4, score_4_5, score_4_6, score_4_7,
                     score_5_0, score_5_1, score_5_2, score_5_3, score_5_4, score_5_5, score_5_6, score_5_7,
                     score_6_0, score_6_1, score_6_2, score_6_3, score_6_4, score_6_5, score_6_6, score_6_7,
                     score_7_0, score_7_1, score_7_2, score_7_3, score_7_4, score_7_5, score_7_6, score_7_7,
    
    output reg  [3:0]   min_rank_0, min_rank_1, min_rank_2, min_rank_3, min_rank_4, min_rank_5, min_rank_6, min_rank_7,
    output reg          done
);

    // State declarations
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] COMPUTE_ADJUSTED = 4'd1;
    localparam [3:0] COMPUTE_RANKS   = 4'd2;
    localparam [3:0] UPDATE_MIN_RANK = 4'd3;
    localparam [3:0] INCREMENT_LL    = 4'd4;
    localparam [3:0] FINISHED        = 4'd5;
    
    reg [3:0] state;
    
    // Counters
    reg [7:0] ll_counter;           // ℓ counter (1 to 255)
    reg [2:0] player_counter;       // Player index (0 to 7)
    reg [2:0] hole_counter;         // Hole index (0 to 7)
    reg [2:0] compare_counter;      // Comparison index (0 to 7)
    
    // Adjusted totals and ranks
    reg [15:0] adjusted_total [0:7]; // Adjusted total for each player
    reg [3:0] current_rank [0:7];   // Current rank for each player
    reg [3:0] temp_rank;            // Temporary rank counter
    
    // Internal signals
    reg [7:0] current_score;        // Current score being processed
    reg [7:0] min_score;            // min(score, ℓ)
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            ll_counter <= 8'd0;
            player_counter <= 3'd0;
            hole_counter <= 3'd0;
            compare_counter <= 3'd0;
            
            // Reset outputs
            min_rank_0 <= 4'd0;
            min_rank_1 <= 4'd0;
            min_rank_2 <= 4'd0;
            min_rank_3 <= 4'd0;
            min_rank_4 <= 4'd0;
            min_rank_5 <= 4'd0;
            min_rank_6 <= 4'd0;
            min_rank_7 <= 4'd0;
            done <= 1'b0;
            
            // Reset internal arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                adjusted_total[i] <= 16'd0;
                current_rank[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for new computation
                        ll_counter <= 8'd1;
                        player_counter <= 3'd0;
                        hole_counter <= 3'd0;
                        compare_counter <= 3'd0;
                        
                        // Reset min_rank outputs
                        min_rank_0 <= 4'd15;
                        min_rank_1 <= 4'd15;
                        min_rank_2 <= 4'd15;
                        min_rank_3 <= 4'd15;
                        min_rank_4 <= 4'd15;
                        min_rank_5 <= 4'd15;
                        min_rank_6 <= 4'd15;
                        min_rank_7 <= 4'd15;
                        
                        state <= COMPUTE_ADJUSTED;
                    end
                end
                
                COMPUTE_ADJUSTED: begin
                    // Compute adjusted_total[player_counter] = sum(min(score, ll_counter))
                    case (player_counter)
                        3'd0: current_score = (hole_counter == 3'd0) ? score_0_0 :
                                              (hole_counter == 3'd1) ? score_0_1 :
                                              (hole_counter == 3'd2) ? score_0_2 :
                                              (hole_counter == 3'd3) ? score_0_3 :
                                              (hole_counter == 3'd4) ? score_0_4 :
                                              (hole_counter == 3'd5) ? score_0_5 :
                                              (hole_counter == 3'd6) ? score_0_6 : score_0_7;
                        3'd1: current_score = (hole_counter == 3'd0) ? score_1_0 :
                                              (hole_counter == 3'd1) ? score_1_1 :
                                              (hole_counter == 3'd2) ? score_1_2 :
                                              (hole_counter == 3'd3) ? score_1_3 :
                                              (hole_counter == 3'd4) ? score_1_4 :
                                              (hole_counter == 3'd5) ? score_1_5 :
                                              (hole_counter == 3'd6) ? score_1_6 : score_1_7;
                        3'd2: current_score = (hole_counter == 3'd0) ? score_2_0 :
                                              (hole_counter == 3'd1) ? score_2_1 :
                                              (hole_counter == 3'd2) ? score_2_2 :
                                              (hole_counter == 3'd3) ? score_2_3 :
                                              (hole_counter == 3'd4) ? score_2_4 :
                                              (hole_counter == 3'd5) ? score_2_5 :
                                              (hole_counter == 3'd6) ? score_2_6 : score_2_7;
                        3'd3: current_score = (hole_counter == 3'd0) ? score_3_0 :
                                              (hole_counter == 3'd1) ? score_3_1 :
                                              (hole_counter == 3'd2) ? score_3_2 :
                                              (hole_counter == 3'd3) ? score_3_3 :
                                              (hole_counter == 3'd4) ? score_3_4 :
                                              (hole_counter == 3'd5) ? score_3_5 :
                                              (hole_counter == 3'd6) ? score_3_6 : score_3_7;
                        3'd4: current_score = (hole_counter == 3'd0) ? score_4_0 :
                                              (hole_counter == 3'd1) ? score_4_1 :
                                              (hole_counter == 3'd2) ? score_4_2 :
                                              (hole_counter == 3'd3) ? score_4_3 :
                                              (hole_counter == 3'd4) ? score_4_4 :
                                              (hole_counter == 3'd5) ? score_4_5 :
                                              (hole_counter == 3'd6) ? score_4_6 : score_4_7;
                        3'd5: current_score = (hole_counter == 3'd0) ? score_5_0 :
                                              (hole_counter == 3'd1) ? score_5_1 :
                                              (hole_counter == 3'd2) ? score_5_2 :
                                              (hole_counter == 3'd3) ? score_5_3 :
                                              (hole_counter == 3'd4) ? score_5_4 :
                                              (hole_counter == 3'd5) ? score_5_5 :
                                              (hole_counter == 3'd6) ? score_5_6 : score_5_7;
                        3'd6: current_score = (hole_counter == 3'd0) ? score_6_0 :
                                              (hole_counter == 3'd1) ? score_6_1 :
                                              (hole_counter == 3'd2) ? score_6_2 :
                                              (hole_counter == 3'd3) ? score_6_3 :
                                              (hole_counter == 3'd4) ? score_6_4 :
                                              (hole_counter == 3'd5) ? score_6_5 :
                                              (hole_counter == 3'd6) ? score_6_6 : score_6_7;
                        3'd7: current_score = (hole_counter == 3'd0) ? score_7_0 :
                                              (hole_counter == 3'd1) ? score_7_1 :
                                              (hole_counter == 3'd2) ? score_7_2 :
                                              (hole_counter == 3'd3) ? score_7_3 :
                                              (hole_counter == 3'd4) ? score_7_4 :
                                              (hole_counter == 3'd5) ? score_7_5 :
                                              (hole_counter == 3'd6) ? score_7_6 : score_7_7;
                    endcase
                    
                    // Compute min(score, ll_counter)
                    min_score = (current_score < ll_counter) ? current_score : ll_counter;
                    
                    // Accumulate adjusted total
                    if (hole_counter == 3'd0)
                        adjusted_total[player_counter] <= min_score;
                    else
                        adjusted_total[player_counter] <= adjusted_total[player_counter] + min_score;
                    
                    // Move to next hole or next state
                    if (hole_counter == 3'd7) begin
                        hole_counter <= 3'd0;
                        if (player_counter == 3'd7) begin
                            player_counter <= 3'd0;
                            state <= COMPUTE_RANKS;
                        end else begin
                            player_counter <= player_counter + 3'd1;
                        end
                    end else begin
                        hole_counter <= hole_counter + 3'd1;
                    end
                end
                
                COMPUTE_RANKS: begin
                    // Compute rank for current player: count players with adjusted_total <= current
                    if (compare_counter == 3'd0) begin
                        temp_rank <= 4'd0;
                        current_rank[player_counter] <= 4'd0;
                    end
                    
                    // Compare with other players
                    if (adjusted_total[compare_counter] <= adjusted_total[player_counter])
                        temp_rank <= temp_rank + 4'd1;
                    
                    // Move to next comparison or next state
                    if (compare_counter == 3'd7) begin
                        current_rank[player_counter] <= temp_rank;
                        compare_counter <= 3'd0;
                        
                        if (player_counter == 3'd7) begin
                            player_counter <= 3'd0;
                            state <= UPDATE_MIN_RANK;
                        end else begin
                            player_counter <= player_counter + 3'd1;
                        end
                    end else begin
                        compare_counter <= compare_counter + 3'd1;
                    end
                end
                
                UPDATE_MIN_RANK: begin
                    // Update min_rank if current_rank is smaller
                    case (player_counter)
                        3'd0: begin
                            if (current_rank[0] < min_rank_0)
                                min_rank_0 <= current_rank[0];
                        end
                        3'd1: begin
                            if (current_rank[1] < min_rank_1)
                                min_rank_1 <= current_rank[1];
                        end
                        3'd2: begin
                            if (current_rank[2] < min_rank_2)
                                min_rank_2 <= current_rank[2];
                        end
                        3'd3: begin
                            if (current_rank[3] < min_rank_3)
                                min_rank_3 <= current_rank[3];
                        end
                        3'd4: begin
                            if (current_rank[4] < min_rank_4)
                                min_rank_4 <= current_rank[4];
                        end
                        3'd5: begin
                            if (current_rank[5] < min_rank_5)
                                min_rank_5 <= current_rank[5];
                        end
                        3'd6: begin
                            if (current_rank[6] < min_rank_6)
                                min_rank_6 <= current_rank[6];
                        end
                        3'd7: begin
                            if (current_rank[7] < min_rank_7)
                                min_rank_7 <= current_rank[7];
                        end
                    endcase
                    
                    // Move to next player or next state
                    if (player_counter == 3'd7) begin
                        player_counter <= 3'd0;
                        state <= INCREMENT_LL;
                    end else begin
                        player_counter <= player_counter + 3'd1;
                    end
                end
                
                INCREMENT_LL: begin
                    // Increment ll_counter and check if done
                    ll_counter <= ll_counter + 8'd1;
                    
                    if (ll_counter == 8'd255) begin
                        state <= FINISHED;
                    end else begin
                        state <= COMPUTE_ADJUSTED;
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