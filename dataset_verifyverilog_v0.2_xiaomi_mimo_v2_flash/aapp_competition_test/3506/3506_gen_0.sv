module cheerleader_optimizer(
    input clk,
    input rst_n,
    input start,
    input [1:0] num_cheerleaders,
    input [7:0] cheer_time,
    input [7:0] opponent_pattern,
    output reg [3:0] sportify_goals,
    output reg [3:0] spoilify_goals,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam EVALUATE_SCHEDULES = 3'b001;
    localparam COMPUTE_GOALS = 3'b010;
    localparam UPDATE_BEST = 3'b011;
    localparam DONE_STATE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Iteration registers
    reg [7:0] iter_s1; // S1 mask generator
    reg [7:0] iter_s2; // S2 mask generator
    reg [2:0] phase; // 0: find S1, 1: find S2 (for N=2)

    // Current candidates
    reg [7:0] s1_mask;
    reg [7:0] s2_mask;

    // Computation registers
    reg [2:0] sport_streak;
    reg [2:0] spoil_streak;
    reg [3:0] temp_sport;
    reg [3:0] temp_spoil;
    reg [3:0] min_idx;

    // Best result registers
    reg signed [4:0] best_diff;
    reg [3:0] best_sport;
    reg [3:0] best_spoil;

    // Cycle counter for timeout
    reg [11:0] cycle_count;

    function [3:0] popcount;
        input [7:0] val;
        begin
            popcount = val[0] + val[1] + val[2] + val[3] + val[4] + val[5] + val[6] + val[7];
        end
    endfunction

    // State Transition Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = EVALUATE_SCHEDULES;
                else next_state = IDLE;
            end
            EVALUATE_SCHEDULES: begin
                // Logic depends on phase and inputs
                // If phase 0 (Find S1): 
                //   If popcount(iter_s1) == cheer_time, we have S1.
                //   If N=2, go to phase 1 (Find S2).
                //   If N=1, go to COMPUTE_GOALS.
                //   Else increment iter_s1.
                // If phase 1 (Find S2):
                //   If popcount(iter_s2) == cheer_time, we have S2, go to COMPUTE_GOALS.
                //   Else increment iter_s2.
                
                if (phase == 0) begin
                    if (popcount(iter_s1) == cheer_time) begin
                        if (num_cheerleaders == 2'b01) next_state = COMPUTE_GOALS;
                        else next_state = EVALUATE_SCHEDULES; // Stay, but switch phase to 1
                    end else begin
                        next_state = EVALUATE_SCHEDULES; // Stay, increment
                    end
                end else begin // phase 1
                    if (popcount(iter_s2) == cheer_time) begin
                        next_state = COMPUTE_GOALS;
                    end else begin
                        next_state = EVALUATE_SCHEDULES; // Stay, increment
                    end
                end
                
                // Timeout check
                if (cycle_count > 12'd498) next_state = DONE_STATE;
            end
            COMPUTE_GOALS: begin
                if (min_idx < 8) next_state = COMPUTE_GOALS;
                else next_state = UPDATE_BEST;
            end
            UPDATE_BEST: begin
                // Determine next action based on iterators
                if (num_cheerleaders == 2'd2) begin
                    // Need to find next S2 candidate
                    if (iter_s2 == 8'd255) next_state = EVALUATE_SCHEDULES; // Will increment S1 in sequential
                    else next_state = EVALUATE_SCHEDULES;
                end else begin
                    next_state = EVALUATE_SCHEDULES; // Next S1
                end
            end
            DONE_STATE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sportify_goals <= 0;
            spoilify_goals <= 0;
            done <= 0;
            iter_s1 <= 0;
            iter_s2 <= 0;
            phase <= 0;
            cycle_count <= 0;
            best_diff <= -9; // Initialize low
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        iter_s1 <= 0;
                        iter_s2 <= 0;
                        phase <= 0;
                        cycle_count <= 0;
                        best_diff <= -9;
                        best_sport <= 0;
                        best_spoil <= 0;
                        done <= 0;
                    end
                end

                EVALUATE_SCHEDULES: begin
                    // Increment cycle count
                    cycle_count <= cycle_count + 1;

                    if (phase == 0) begin
                        if (popcount(iter_s1) == cheer_time) begin
                            s1_mask <= iter_s1;
                            if (num_cheerleaders == 2'b01) begin
                                // Single cheerleader, fixed S2=0
                                s2_mask <= 0;
                            end else begin
                                // Switch to finding S2
                                phase <= 1;
                                iter_s2 <= 0;
                            end
                        end else begin
                            iter_s1 <= iter_s1 + 1;
                        end
                    end else begin // phase 1
                        if (popcount(iter_s2) == cheer_time) begin
                            s2_mask <= iter_s2;
                            // S2 found, will go to compute next cycle
                        end else begin
                            iter_s2 <= iter_s2 + 1;
                        end
                    end
                end

                COMPUTE_GOALS: begin
                    if (min_idx < 8) begin
                        // Process minute min_idx
                        // Calculate cheers: s1_mask[min_idx] + s2_mask[min_idx]
                        // Compare with opponent_pattern[min_idx]
                        
                        reg my_c;
                        reg opp_c;
                        my_c = s1_mask[min_idx] + s2_mask[min_idx];
                        opp_c = opponent_pattern[min_idx];

                        if (my_c > opp_c) begin
                            sport_streak <= sport_streak + 1;
                            spoil_streak <= 0;
                        end else if (opp_c > my_c) begin
                            sport_streak <= 0;
                            spoil_streak <= spoil_streak + 1;
                        end else begin
                            sport_streak <= 0;
                            spoil_streak <= 0;
                        end

                        // Check goals (Threshold 3)
                        // We must check the NEXT value of streaks to see if they hit 3
                        // But we updated registers. We need to check current or next.
                        // Let's use next values.
                        reg [2:0] next_s, next_p;
                        next_s = (my_c > opp_c) ? sport_streak + 1 : 0;
                        next_p = (opp_c > my_c) ? spoil_streak + 1 : 0;
                        if (my_c == opp_c) begin next_s = 0; next_p = 0; end

                        if (next_s == 3) begin
                            temp_sport <= temp_sport + 1;
                            sport_streak <= 0; // Reset for next minute
                        end else begin
                            sport_streak <= next_s;
                        end

                        if (next_p == 3) begin
                            temp_spoil <= temp_spoil + 1;
                            spoil_streak <= 0;
                        end else begin
                            spoil_streak <= next_p;
                        end

                        min_idx <= min_idx + 1;
                    end
                end

                UPDATE_BEST: begin
                    // Compare results
                    // Objective 1: Maximize (Sport - Spoil)
                    // Objective 2: Maximize Sport
                    
                    reg signed [4:0] cur_diff;
                    reg signed [4:0] cur_best;
                    cur_diff = temp_sport - temp_spoil;
                    cur_best = best_sport - best_spoil;
                    
                    if (cur_diff > cur_best) begin
                        best_sport <= temp_sport;
                        best_spoil <= temp_spoil;
                        best_diff <= cur_diff;
                    end else if (cur_diff == cur_best) begin
                        if (temp_sport > best_sport) begin
                            best_sport <= temp_sport;
                            best_spoil <= temp_spoil;
                            best_diff <= cur_diff;
                        end
                    end

                    // Reset computation registers
                    temp_sport <= 0;
                    temp_spoil <= 0;
                    sport_streak <= 0;
                    spoil_streak <= 0;
                    min_idx <= 0;

                    // Advance Search
                    if (num_cheerleaders == 2'd2) begin
                        // Advance S2 iterator
                        iter_s2 <= iter_s2 + 1;
                        // If iter_s2 overflows to 0, we must advance S1 in the next cycle (EVAL state)
                        // But EVAL state handles phase. 
                        // We need to handle the rollover logic for S1.
                        // If iter_s2 was 255, it becomes 0. In next cycle (EVAL), it checks popcount(0).
                        // We need to increment iter_s1 as well.
                        // We can detect rollover here.
                        if (iter_s2 == 8'd255) begin
                            phase <= 0; // Switch to S1 mode
                            iter_s1 <= iter_s1 + 1; // Increment S1 iterator
                        end
                    end else begin
                        // N=1, advance S1
                        iter_s1 <= iter_s1 + 1;
                        phase <= 0;
                    end
                end

                DONE_STATE: begin
                    sportify_goals <= best_sport;
                    spoilify_goals <= best_spoil;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule