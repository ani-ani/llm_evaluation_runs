module football_cheer_top (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,          // Number of cheerleaders (0-20)
    input wire [6:0] t,          // Minutes per cheerleader (0-90)
    input wire [31:0] opponent_low,   // Minutes 0-31
    input wire [31:0] opponent_mid,   // Minutes 32-63
    input wire [25:0] opponent_high,  // Minutes 64-89
    output reg [4:0] sportify_score,
    output reg [4:0] spoilify_score,
    output reg done
);

    // State Declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SETUP      = 3'd1;
    localparam [2:0] CALCULATE  = 3'd2;
    localparam [2:0] EVALUATE   = 3'd3;
    localparam [2:0] FINISHED   = 3'd4;
    
    // Internal Registers
    reg [2:0] state, next_state;
    reg [6:0] minute; // 0 to 89
    reg [13:0] budget; // n * t (max 20*90=1800 -> 11 bits, 14 for safety)
    reg [13:0] remaining_budget;
    
    // Score Tracking
    reg signed [15:0] current_cnt; // Accumulated advantage (Sportify - Spoilify)
    reg [2:0] streak_len; // Consecutive minutes with same sign of cnt
    reg [1:0] streak_owner; // 0: none, 1: Sportify, 2: Spoilify
    
    // Pre-calculated per-minute opponent status (1 bit)
    reg opp_active;
    
    // DP State Storage (Simplified: We track max score achievable for given budget)
    // Since we iterate linearly, we just simulate the "cheat" strategy: 
    // We want to maximize Score A - Score B.
    // We allocate cheers to maximize the difference.
    // At each minute, if we have budget, we decide to cheer (add 1 to cnt) or not.
    // However, checking all budget possibilities is too slow.
    // Heuristic: We will simulate the "Optimal" greedy distribution.
    // We allocate cheers to minutes where they have the highest impact on score.
    // Impact function: 
    //   - If current cnt < 0, cheering helps prevent Spoilify goal.
    //   - If current cnt > 0, cheering helps create Sportify goal.
    
    // We need a buffer to store the "cheer decision" for each minute.
    // Since we process sequentially, we can just compute the best path.
    // We will use a "Best Effort" algorithm:
    // 1. Calculate total budget = n * t.
    // 2. Iterate minutes 0-89.
    // 3. Maintain cnt, streak.
    // 4. If we have budget, decide to cheer or not to maximize final score.
    //    Decision logic: 
    //    - Check next 4 minutes. If cheering now helps avoid a Spoilify point or gain a Sportify point, do it.
    //    - This is complex for HDL without external RAM.
    
    // Hardware Implementation Choice: Sequential Greedy with Lookahead Buffer
    // We store the opponent schedule in a local array for easy access (requires memory).
    // 90 bits = 3x32 + 26 bits. We can store in 3 registers.
    
    // To solve exact optimization in HDL without huge state space:
    // We treat it as: We have 'budget' tokens to place on the timeline.
    // Value of token at minute i depends on the state (cnt) at minute i.
    // Since the state depends on previous tokens, it's interdependent.
    // 
    // Simplified Algorithm implemented here:
    // Iterate through minutes. Maintain current streak and count.
    // At each minute, calculate the "Score Delta" if we cheer vs if we don't.
    // Pick the option that leads to higher final score, assuming we have enough budget.
    // Since we don't know future perfectly, we use a greedy approach:
    // - Maximize current (Score A - Score B).
    // - Tie-break: Maximize Score A.
    
    // Since the problem is small (90 steps), we can unroll the logic or use a loop.
    // We will use a loop with a lookahead of 0 (pure greedy).
    // 
    // Note: The constraints are tight on registers. 
    // We will process 1 minute per cycle.
    // 
    // Logic:
    // 1. Calculate Budget = n * t. (Cap at 90 for sanity if needed, but logic handles it).
    // 2. Loop 0 to 89.
    //    - Read opponent bit.
    //    - Determine if cheering helps.
    //    - If Budget > 0:
    //       If cheering increases Score A - Score B, cheer.
    //       Else, don't cheer.
    //    - Update cnt, streak, score.
    
    // Signal buffers for input concatenation
    wire [89:0] opp_schedule;
    assign opp_schedule = {opponent_high[25:0], opponent_mid[31:0], opponent_low[31:0]};
    
    // Combinational logic for decision making
    reg cheer_decision;
    reg signed [15:0] next_cnt_no_cheer;
    reg signed [15:0] next_cnt_cheer;
    reg [2:0] next_streak_len_no_cheer;
    reg [2:0] next_streak_len_cheer;
    reg [1:0] next_streak_owner_no_cheer;
    reg [1:0] next_streak_owner_cheer;
    reg [4:0] next_sport_score_no_cheer;
    reg [4:0] next_sport_score_cheer;
    reg [4:0] next_spoil_score_no_cheer;
    reg [4:0] next_spoil_score_cheer;
    
    // Helper function to calculate next state given inputs
    // This is comb logic, called inside sequential block
    always @(*) begin
        // Calculate potential next states
        // 1. No Cheer
        next_cnt_no_cheer = current_cnt + (opp_active ? -16'sd1 : 16'sd0);
        
        // 2. Cheer
        next_cnt_cheer = current_cnt + (opp_active ? 16'sd0 : 16'sd1);
        
        // Calculate Scores and Streaks
        // We need to abstract the streak/score update logic.
        
        // Function to update streak logic
        update_state(next_cnt_no_cheer, streak_len, streak_owner, next_streak_len_no_cheer, next_streak_owner_no_cheer, next_sport_score_no_cheer, next_spoil_score_no_cheer);
        update_state(next_cnt_cheer, streak_len, streak_owner, next_streak_len_cheer, next_streak_owner_cheer, next_sport_score_cheer, next_spoil_score_cheer);
        
        // Decision Logic
        // Goal: Maximize (Score A - Score B)
        // Tie-break: Maximize Score A
        
        reg [4:0] diff_no_cheer;
        reg [4:0] diff_cheer;
        diff_no_cheer = next_sport_score_no_cheer - next_spoil_score_no_cheer;
        diff_cheer = next_sport_score_cheer - next_spoil_score_cheer;
        
        if (remaining_budget > 0) begin
            if (diff_cheer > diff_no_cheer) begin
                cheer_decision = 1'b1;
            end else if (diff_cheer < diff_no_cheer) begin
                cheer_decision = 1'b0;
            end else begin
                // Tie on difference, prefer higher Sportify score
                if (next_sport_score_cheer > next_sport_score_no_cheer)
                    cheer_decision = 1'b1;
                else
                    cheer_decision = 1'b0;
            end
        end else begin
            cheer_decision = 1'b0;
        end
    end
    
    // Sequential Logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sportify_score <= 5'd0;
            spoilify_score <= 5'd0;
            done <= 1'b0;
            minute <= 7'd0;
            current_cnt <= 16'sd0;
            streak_len <= 3'd0;
            streak_owner <= 2'd0;
            remaining_budget <= 14'd0;
            opp_active <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SETUP;
                    end
                end
                
                SETUP: begin
                    // Calculate Budget: n * t
                    // n is 5 bits, t is 7 bits -> 12 bits result
                    remaining_budget <= n * t;
                    minute <= 7'd0;
                    current_cnt <= 16'sd0;
                    streak_len <= 3'd0;
                    streak_owner <= 2'd0;
                    sportify_score <= 5'd0;
                    spoilify_score <= 5'd0;
                    state <= CALCULATE;
                end
                
                CALCULATE: begin
                    if (minute < 89) begin
                        // Extract opponent status for current minute
                        opp_active <= opp_schedule[minute];
                        
                        // Make decision (comb logic uses current state/inputs)
                        // Apply decision
                        if (cheer_decision) begin
                            remaining_budget <= remaining_budget - 14'd1;
                            current_cnt <= next_cnt_cheer;
                            streak_len <= next_streak_len_cheer;
                            streak_owner <= next_streak_owner_cheer;
                            sportify_score <= next_sport_score_cheer;
                            spoilify_score <= next_spoil_score_cheer;
                        end else begin
                            current_cnt <= next_cnt_no_cheer;
                            streak_len <= next_streak_len_no_cheer;
                            streak_owner <= next_streak_owner_no_cheer;
                            sportify_score <= next_sport_score_no_cheer;
                            spoilify_score <= next_spoil_score_no_cheer;
                        end
                        
                        minute <= minute + 7'd1;
                    end else begin
                        // Last minute processing (minute 89)
                        // opp_active is already set from previous cycle (or setup if 0)
                        // Actually, we need to process minute 89.
                        // Minute 89 logic:
                        opp_active <= opp_schedule[89];
                         // Update state for 89
                        if (cheer_decision) begin
                            remaining_budget <= remaining_budget - 14'd1;
                            sportify_score <= next_sport_score_cheer;
                            spoilify_score <= next_spoil_score_cheer;
                        end else begin
                            sportify_score <= next_sport_score_no_cheer;
                            spoilify_score <= next_spoil_score_no_cheer;
                        end
                        state <= FINISHED;
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

    // Helper task to update state (streaks and scores)
    task update_state;
        input signed [15:0] in_cnt;
        input [2:0] in_streak_len;
        input [1:0] in_streak_owner;
        output [2:0] out_streak_len;
        output [1:0] out_streak_owner;
        output [4:0] out_sport_score;
        output [4:0] out_spoil_score;
        
        reg current_owner;
        reg signed [15:0] abs_cnt;
        begin
            // Determine owner of this minute
            if (in_cnt > 0) current_owner = 1; // Sportify
            else if (in_cnt < 0) current_owner = 2; // Spoilify
            else current_owner = 0; // Tie
            
            // Update Streak
            if (current_owner == 0) begin
                out_streak_len = 3'd0;
                out_streak_owner = 2'd0;
            end else if (current_owner == in_streak_owner) begin
                out_streak_len = in_streak_len + 3'd1;
                out_streak_owner = in_streak_owner;
            end else begin
                out_streak_len = 3'd1;
                out_streak_owner = current_owner;
            end
            
            // Check for score update
            out_sport_score = sportify_score;
            out_spoil_score = spoilify_score;
            
            if (out_streak_len >= 3'd5) begin
                if (out_streak_owner == 1) begin
                    out_sport_score = sportify_score + 5'd1;
                    out_streak_len = 3'd0; // Reset streak after scoring (or keep rolling? Problem says "per 5 minutes consecutive", implies overlapping windows or sliding window. Usually sliding window. But for simple accumulation, we treat it as count of points. If sliding window, it's complex. We'll assume we count points. If we maintain > 5, we count extra. Standard interpretation: A point is awarded for every block of 5. If we have 6 in a row, that's 1 point. If we have 10, that's 2 points. 
                    // Correction: Problem says "if they cheer for 5 consecutive minutes... 1 point". It implies cumulative. 
                    // We will reset the streak to 0 to prevent double counting the same block, or count modulo 5. 
                    // To be safe: We just accumulate points. If streak hits 5, we award point and continue. 
                    // If we have 6 consecutive, we have 1 point (from 1-5) and 1 point (from 2-6). 
                    // To implement sliding window efficiently in HDL is hard. 
                    // We will stick to "Counter accumulates, if streak hits 5, increment score, reset streak to 0". 
                    // This counts blocks of 5 exactly. 
                    out_streak_len = 3'd0; // Reset to count next block
                end else if (out_streak_owner == 2) begin
                    out_spoil_score = spoilify_score + 5'd1;
                    out_streak_len = 3'd0;
                end
            end
        end
    endtask

endmodule