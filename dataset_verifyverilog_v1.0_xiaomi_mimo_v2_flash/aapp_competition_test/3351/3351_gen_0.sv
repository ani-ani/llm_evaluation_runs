module yahtzee(
    input clk,
    input rst_n,
    input start,
    input [194:0] rolls,
    output reg [15:0] total_score,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] ROUND0    = 4'd1;  // 1's
    localparam [3:0] ROUND1    = 4'd2;  // 2's
    localparam [3:0] ROUND2    = 4'd3;  // 3's
    localparam [3:0] ROUND3    = 4'd4;  // 4's
    localparam [3:0] ROUND4    = 4'd5;  // 5's
    localparam [3:0] ROUND5    = 4'd6;  // 6's
    localparam [3:0] ROUND6    = 4'd7;  // 3-of-a-kind
    localparam [3:0] ROUND7    = 4'd8;  // 4-of-a-kind
    localparam [3:0] ROUND8    = 4'd9;  // Full house
    localparam [3:0] ROUND9    = 4'd10; // Small straight
    localparam [3:0] ROUND10   = 4'd11; // Long straight
    localparam [3:0] ROUND11   = 4'd12; // Chance
    localparam [3:0] ROUND12   = 4'd13; // Yahtzee
    localparam [3:0] DONE_STATE = 4'd14;

    reg [3:0] state, next_state;
    reg [3:0] round_count;
    reg [15:0] score_sum;
    reg processing_done;
    
    // Local parameters
    localparam [2:0] ONE   = 3'd1;
    localparam [2:0] TWO   = 3'd2;
    localparam [2:0] THREE = 3'd3;
    localparam [2:0] FOUR  = 3'd4;
    localparam [2:0] FIVE  = 3'd5;
    localparam [2:0] SIX   = 3'd6;

    // Combinational score calculation
    reg [15:0] current_round_score;
    
    always @(*) begin
        // Extract 5 dice for current round
        reg [2:0] dice [0:4];
        reg [2:0] i;
        reg [2:0] sorted_dice [0:4];
        reg [4:0] freq [0:6];
        reg [2:0] max_freq;
        reg has_full_house;
        reg has_small_straight;
        reg has_large_straight;
        reg is_yahtzee;
        reg [2:0] j, k, temp;
        reg [15:0] temp_score;
        
        // Extract dice
        for (i = 0; i < 5; i = i + 1) begin
            dice[i] = rolls[(round_count * 5 + i) * 3 +: 3];
        end
        
        // Bubble sort
        for (i = 0; i < 5; i = i + 1) begin
            sorted_dice[i] = dice[i];
        end
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4 - i; j = j + 1) begin
                if (sorted_dice[j] > sorted_dice[j + 1]) begin
                    temp = sorted_dice[j];
                    sorted_dice[j] = sorted_dice[j + 1];
                    sorted_dice[j + 1] = temp;
                end
            end
        end
        
        // Count frequencies
        for (i = 0; i < 7; i = i + 1) begin
            freq[i] = 5'd0;
        end
        for (i = 0; i < 5; i = i + 1) begin
            freq[dice[i]] = freq[dice[i]] + 5'd1;
        end
        max_freq = 3'd0;
        for (i = 1; i < 7; i = i + 1) begin
            if (freq[i] > max_freq) begin
                max_freq = freq[i];
            end
        end
        
        // Check for full house (3 of one, 2 of another)
        has_full_house = 1'b0;
        for (i = 1; i < 7; i = i + 1) begin
            for (j = 1; j < 7; j = j + 1) begin
                if ((i != j) && (freq[i] == 3'd3) && (freq[j] == 3'd2)) begin
                    has_full_house = 1'b1;
                end
            end
        end
        
        // Check for straights
        has_small_straight = 1'b0;
        has_large_straight = 1'b0;
        is_yahtzee = 1'b0;
        
        // Small straight: 4 consecutive numbers
        // Check 1-2-3-4, 2-3-4-5, 3-4-5-6
        if ((freq[1] > 0) && (freq[2] > 0) && (freq[3] > 0) && (freq[4] > 0))
            has_small_straight = 1'b1;
        if ((freq[2] > 0) && (freq[3] > 0) && (freq[4] > 0) && (freq[5] > 0))
            has_small_straight = 1'b1;
        if ((freq[3] > 0) && (freq[4] > 0) && (freq[5] > 0) && (freq[6] > 0))
            has_small_straight = 1'b1;
            
        // Large straight: 5 consecutive numbers
        if ((freq[1] == 5'd1) && (freq[2] == 5'd1) && (freq[3] == 5'd1) && (freq[4] == 5'd1) && (freq[5] == 5'd1))
            has_large_straight = 1'b1;
        if ((freq[2] == 5'd1) && (freq[3] == 5'd1) && (freq[4] == 5'd1) && (freq[5] == 5'd1) && (freq[6] == 5'd1))
            has_large_straight = 1'b1;
            
        // Yahtzee: 5 of a kind
        if (max_freq == 3'd5)
            is_yahtzee = 1'b1;
            
        // Calculate score based on round
        temp_score = 16'd0;
        case (state)
            ROUND0: begin // 1's
                for (i = 0; i < 5; i = i + 1) begin
                    if (dice[i] == ONE)
                        temp_score = temp_score + 16'd1;
                end
            end
            ROUND1: begin // 2's
                for (i = 0; i < 5; i = i + 1) begin
                    if (dice[i] == TWO)
                        temp_score = temp_score + 16'd2;
                end
            end
            ROUND2: begin // 3's
                for (i = 0; i < 5; i = i + 1) begin
                    if (dice[i] == THREE)
                        temp_score = temp_score + 16'd3;
                end
            end
            ROUND3: begin // 4's
                for (i = 0; i < 5; i = i + 1) begin
                    if (dice[i] == FOUR)
                        temp_score = temp_score + 16'd4;
                end
            end
            ROUND4: begin // 5's
                for (i = 0; i < 5; i = i + 1) begin
                    if (dice[i] == FIVE)
                        temp_score = temp_score + 16'd5;
                end
            end
            ROUND5: begin // 6's
                for (i = 0; i < 5; i = i + 1) begin
                    if (dice[i] == SIX)
                        temp_score = temp_score + 16'd6;
                end
            end
            ROUND6: begin // 3-of-a-kind
                if (max_freq >= 3'd3) begin
                    for (i = 0; i < 5; i = i + 1) begin
                        temp_score = temp_score + {13'd0, dice[i]};
                    end
                end
            end
            ROUND7: begin // 4-of-a-kind
                if (max_freq >= 3'd4) begin
                    for (i = 0; i < 5; i = i + 1) begin
                        temp_score = temp_score + {13'd0, dice[i]};
                    end
                end
            end
            ROUND8: begin // Full house
                if (has_full_house)
                    temp_score = 16'd25;
            end
            ROUND9: begin // Small straight
                if (has_small_straight)
                    temp_score = 16'd30;
            end
            ROUND10: begin // Long straight
                if (has_large_straight)
                    temp_score = 16'd40;
            end
            ROUND11: begin // Chance
                for (i = 0; i < 5; i = i + 1) begin
                    temp_score = temp_score + {13'd0, dice[i]};
                end
            end
            ROUND12: begin // Yahtzee
                if (is_yahtzee)
                    temp_score = 16'd50;
            end
            default: temp_score = 16'd0;
        endcase
        
        current_round_score = temp_score;
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            round_count <= 4'd0;
            total_score <= 16'd0;
            score_sum <= 16'd0;
            processing_done <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    round_count <= 4'd0;
                    score_sum <= 16'd0;
                    processing_done <= 1'b0;
                    if (start) begin
                        state <= ROUND0;
                    end
                end
                
                ROUND0, ROUND1, ROUND2, ROUND3, ROUND4, ROUND5,
                ROUND6, ROUND7, ROUND8, ROUND9, ROUND10, ROUND11, ROUND12: begin
                    // Add current round score to sum
                    score_sum <= score_sum + current_round_score;
                    
                    // Move to next state
                    if (state == ROUND12) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= state + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    total_score <= score_sum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule