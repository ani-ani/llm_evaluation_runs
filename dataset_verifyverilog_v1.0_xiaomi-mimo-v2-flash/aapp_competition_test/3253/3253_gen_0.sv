module ElectionSolver(
    input clk,
    input rst_n,
    input start,
    input state_valid,
    input [4:0] delegate_in,
    input [31:0] c_in,
    input [31:0] f_in,
    input [31:0] u_in,
    input [2:0] state_index,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // Constants
    localparam [3:0] MAX_STATES = 4'd4;
    localparam [11:0] MAX_DELEGATES = 12'd4096;
    localparam [3:0] MAX_STATE_DELEGATES = 4'd32;
    localparam [15:0] MAX_VOTES = 16'd65535;
    localparam [15:0] SCALE_SHIFT = 16'd16;
    localparam [31:0] MAX_VOTES_SCALED = 32'd4294901760; // 65535 << 16

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] INIT_DP = 3'd2;
    localparam [2:0] DP_CALC = 3'd3;
    localparam [2:0] BINARY_SEARCH = 3'd4;
    localparam [2:0] CHECK_RESULT = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // State storage
    reg [4:0] delegates_reg [0:3];
    reg [31:0] c_reg [0:3];
    reg [31:0] f_reg [0:3];
    reg [31:0] u_reg [0:3];
    reg [2:0] loaded_states;

    // DP table: dp[delegates][states] = max constituent votes
    reg [15:0] dp [0:4095] [0:3]; // Packed as dp[delegates][state]
    
    // Binary search state
    reg [31:0] low, high, mid;
    reg [31:0] search_result;
    reg search_possible;

    // DP iteration state
    reg [2:0] dp_state_idx;
    reg [11:0] dp_delegates;
    reg [11:0] dp_prev_delegates;
    reg [15:0] dp_new_c;
    reg [15:0] dp_old_c;
    reg [15:0] dp_temp_c;

    // Main state
    reg [2:0] state, next_state;
    reg [12:0] cycle_count; // To prevent infinite loops
    localparam [12:0] MAX_CYCLES = 13'd10000;

    // Temporary variables
    reg [31:0] total_delegates;
    reg [31:0] majority_delegates;
    reg [31:0] current_c_total;
    reg [31:0] current_f_total;
    reg [31:0] current_u_total;
    reg [31:0] needed_u;
    reg [31:0] current_guess;
    integer i, j;

    // Control signal for DP reset
    reg dp_reset;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 13'd0;
            loaded_states <= 3'd0;
            dp_reset <= 1'b0;
            
            // Initialize storage
            for (i = 0; i < 4; i = i + 1) begin
                delegates_reg[i] <= 5'd0;
                c_reg[i] <= 32'd0;
                f_reg[i] <= 32'd0;
                u_reg[i] <= 32'd0;
            end
            
            // Initialize DP table (use loop for array handling)
            for (dp_delegates = 0; dp_delegates < MAX_DELEGATES; dp_delegates = dp_delegates + 1) begin
                for (dp_state_idx = 0; dp_state_idx < 4; dp_state_idx = dp_state_idx + 1) begin
                    dp[dp_delegates][dp_state_idx] <= 16'd0;
                end
            end
            
            low <= 32'd0;
            high <= MAX_VOTES_SCALED;
            mid <= 32'd0;
            search_result <= 32'd0;
            search_possible <= 1'b0;
            
        end else begin
            cycle_count <= cycle_count + 13'd1;
            done <= 1'b0; // Clear done pulse
            dp_reset <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    cycle_count <= 13'd0;
                    if (start) begin
                        // Check if already loaded or need to load
                        if (loaded_states >= MAX_STATES) begin
                            state <= INIT_DP;
                        end else begin
                            state <= LOAD;
                        end
                    end
                end

                LOAD: begin
                    busy <= 1'b1;
                    if (state_valid && state_index < MAX_STATES) begin
                        delegates_reg[state_index] <= delegate_in;
                        c_reg[state_index] <= c_in;
                        f_reg[state_index] <= f_in;
                        u_reg[state_index] <= u_in;
                        if (state_index >= loaded_states) begin
                            loaded_states <= state_index + 1;
                        end
                    end
                    // Transition when all states loaded or timeout
                    if (loaded_states >= MAX_STATES || cycle_count > 500) begin
                        state <= INIT_DP;
                    end
                end

                INIT_DP: begin
                    busy <= 1'b1;
                    // Initialize DP table
                    // First, reset the table
                    for (dp_delegates = 0; dp_delegates < MAX_DELEGATES; dp_delegates = dp_delegates + 1) begin
                        dp[dp_delegates][0] <= 16'd0;
                    end
                    
                    // Initialize base case for DP (0 delegates, 0 states processed)
                    // Already 0
                    dp_state_idx <= 3'd1;
                    dp_delegates <= 12'd0;
                    
                    // Calculate total delegates
                    total_delegates <= {27'd0, delegates_reg[0]} + {27'd0, delegates_reg[1]} + 
                                      {27'd0, delegates_reg[2]} + {27'd0, delegates_reg[3]};
                    
                    state <= DP_CALC;
                end

                DP_CALC: begin
                    busy <= 1'b1;
                    // DP Algorithm: knapsack style
                    // dp[delegates][state_idx] = max constituent votes to achieve delegates with first state_idx states
                    // Transition: dp[d][i] = max(dp[d][i-1], dp[d - delegates[i-1]][i-1] + c[i-1])
                    
                    if (dp_state_idx <= MAX_STATES) begin
                        // Process states 1 to MAX_STATES (index 0 is base)
                        // dp_state_idx corresponds to number of states processed
                        
                        // Iterate delegate sums from 0 to total_delegates
                        if (dp_delegates <= total_delegates[11:0]) begin
                            
                            // Calculate previous index
                            reg [11:0] prev_delegates;
                            prev_delegates = dp_delegates;
                            
                            // Option 1: Don't include current state
                            dp_old_c <= dp[dp_delegates][dp_state_idx - 1];
                            
                            // Option 2: Include current state
                            if (dp_delegates >= {7'd0, delegates_reg[dp_state_idx - 1]}) begin
                                prev_delegates = dp_delegates - {7'd0, delegates_reg[dp_state_idx - 1]};
                                dp_new_c <= dp[prev_delegates][dp_state_idx - 1] + c_reg[dp_state_idx - 1][15:0];
                            end else begin
                                dp_new_c <= 16'd0;
                            end
                            
                            // Maximize
                            if (dp_new_c > dp_old_c) begin
                                dp_temp_c <= dp_new_c;
                            end else begin
                                dp_temp_c <= dp_old_c;
                            end
                            
                            dp_delegates <= dp_delegates + 12'd1;
                        end else begin
                            // Finished this state_idx
                            // Update DP table with computed values
                            if (dp_delegates > 0 && dp_delegates <= total_delegates[11:0] + 12'd1) begin
                                // In the loop we computed the value, need to store it
                                // We are in the cycle after computing max, store it
                                dp[dp_delegates - 12'd1][dp_state_idx] <= dp_temp_c;
                                dp_delegates <= 12'd0;
                                dp_state_idx <= dp_state_idx + 3'd1;
                            end else begin
                                dp_delegates <= 12'd0;
                                dp_state_idx <= dp_state_idx + 3'd1;
                            end
                        end
                    end else begin
                        // DP finished, start binary search
                        low <= 32'd0;
                        high <= MAX_VOTES_SCALED;
                        search_result <= 32'd0;
                        search_possible <= 1'b0;
                        state <= BINARY_SEARCH;
                    end
                end

                BINARY_SEARCH: begin
                    busy <= 1'b1;
                    // Binary search for minimum votes
                    if (low <= high && cycle_count < MAX_CYCLES) begin
                        mid <= (low + high) >> 1;
                        current_guess <= (low + high) >> 1;
                        state <= CHECK_RESULT;
                    end else begin
                        // Done searching
                        if (search_possible) begin
                            result <= search_result;
                        end else begin
                            result <= 32'hFFFFFFFF; // -1
                        end
                        state <= FINISH;
                    end
                end

                CHECK_RESULT: begin
                    busy <= 1'b1;
                    // Check if 'mid' votes are enough
                    // We need to find if there's a delegate sum >= majority
                    // where Constituents >= Federals + Undecided (where undecided is limited by 'mid')
                    
                    // For this check, we use the precomputed DP table
                    // But we need to verify if 'mid' is sufficient
                    
                    // Condition: C + U_needed >= F + U_needed (impossible)
                    // We need: C + min(u_in, mid) >= F + (u_in - min(u_in, mid))
                    // Actually: C + u >= F + u -> C >= F is impossible if u is split evenly
                    // We control the undecided voters.
                    // We want to maximize C - F in any partition of undecided.
                    // Max C - F = (C + u) - F if we take all u for C.
                    // Wait, we win if C_total >= F_total + 1 (if majority > 50%)
                    // Or C_total > F_total (if strict majority)
                    // If total delegates is even, majority is total/2 + 1.
                    // If odd, (total+1)/2.
                    // Usually (total/2) + 1.
                    
                    // Let's assume strict majority (> total_delegates/2)
                    // Majority delegates = total_delegates / 2 + 1
                    reg [31:0] maj;
                    maj = (total_delegates >> 1) + 32'd1;
                    
                    // We need to check if there exists a delegate sum >= maj
                    // such that C_total >= F_total + 1 (for majority)
                    // But since we control U, we can shift votes.
                    // We want to win a subset of states.
                    // For a subset S_won, we need:
                    // Sum(C in S_won) + Sum(U in S_won) >= Sum(F in S_won) + Sum(U in S_won) + 1
                    // This simplifies to Sum(C in S_won) >= Sum(F in S_won) + 1 ?
                    // No, that's only if we take ALL U in won states.
                    // We have a constraint: Total U <= mid (scaled).
                    // We want to select U allocation to maximize wins.
                    // This is complex. Let's simplify.
                    // Can we win?
                    // Let U_total = sum(u_in).
                    // If mid >= U_total, we take all U. Check if there's a state set with C >= F.
                    // If mid < U_total, we need to select which U to take.
                    // We want to maximize (C + U - F) = (C - F) + U.
                    // This looks like a knapsack again.
                    // Value = (C - F), Cost = U.
                    // We want Value > 0 (strict majority in that subset).
                    // Actually, we just need Sum(C) + allocated_U >= Sum(F) + (remaining_U_in_subset).
                    // Wait, undecideds are distributed within the subset.
                    // If we win a subset S, we take X U from S.
                    // C_S + X >= F_S + (U_S - X) + 1
                    // 2X >= F_S - C_S + U_S + 1
                    // X >= (F_S - C_S + U_S + 1) / 2
                    // X must be <= U_S.
                    // So we need (F_S - C_S + U_S + 1) / 2 <= min(U_S, mid)
                    // Rearranged: 2 * min(U_S, mid) >= F_S - C_S + U_S + 1
                    
                    // Let's simplify the logic for implementation:
                    // We iterate over all possible delegate sums >= majority.
                    // For each sum (which implies a subset of states via DP reachability),
                    // we check the condition:
                    // If F_total > C_total + U_total -> Impossible for this subset.
                    // Else if F_total <= C_total -> Win (0 U needed).
                    // Else we need U_needed = (F_total - C_total + 1).
                    // Wait, U_needed is how much U must be added to C.
                    // C_final = C + U_added
                    // F_final = F + (U_S - U_added)
                    // C_final >= F_final + 1 ?
                    // C + u >= F + (U_S - u) + 1
                    // 2u >= F - C + U_S + 1
                    // u >= (F - C + U_S + 1) / 2
                    // We need total u <= mid.
                    
                    // We need to iterate through states to find a valid subset.
                    // Since we precomputed DP for C, we can't easily iterate subsets.
                    // BUT, we can use DP to find if any valid subset exists.
                    // Let's re-scope: We check if a valid allocation exists.
                    // We can run another DP tailored to the check.
                    // However, cycle limit is tight.
                    // Let's assume the condition simplifies:
                    // Is there a subset of states with Delegates >= Majority
                    // such that (Sum(F) - Sum(C) - Sum(U)) < 0 ?
                    // Or Sum(C + U) >= Sum(F) + 1 (if we take all U in subset)
                    // If Sum(C + U) < Sum(F) + 1, we lose even with all U.
                    // If Sum(C + U) >= Sum(F) + 1, we might win IF we can allocate U properly.
                    // The condition 2*U_available >= F - C + U_in_subset + 1 must hold for the subset.
                    // AND Sum(U_allocated) <= mid.
                    // 
                    // This is getting complicated for the cycle limit.
                    // Let's use a heuristic/approximation check or a simplified DP check.
                    // Given the prompt asks for DP, let's try to compute a score.
                    // We can iterate states and check combinations.
                    // Since MAX_STATES = 4, there are only 2^4 = 16 subsets.
                    // We can just iterate all subsets explicitly.
                    
                    reg [3:0] subset;
                    reg [31:0] sum_delegates;
                    reg [31:0] sum_c;
                    reg [31:0] sum_f;
                    reg [31:0] sum_u;
                    reg [31:0] u_needed;
                    reg found_valid;
                    
                    found_valid = 1'b0;
                    // Iterate subsets 1 to 15
                    for (subset = 1; subset < 16; subset = subset + 1) begin
                        sum_delegates = 0;
                        sum_c = 0;
                        sum_f = 0;
                        sum_u = 0;
                        
                        if (subset[0]) sum_delegates = sum_delegates + {27'd0, delegates_reg[0]};
                        if (subset[1]) sum_delegates = sum_delegates + {27'd0, delegates_reg[1]};
                        if (subset[2]) sum_delegates = sum_delegates + {27'd0, delegates_reg[2]};
                        if (subset[3]) sum_delegates = sum_delegates + {27'd0, delegates_reg[3]};
                        
                        if (sum_delegates >= ((total_delegates >> 1) + 1)) begin
                            // Majority check
                            if (subset[0]) begin sum_c = sum_c + c_reg[0]; sum_f = sum_f + f_reg[0]; sum_u = sum_u + u_reg[0]; end
                            if (subset[1]) begin sum_c = sum_c + c_reg[1]; sum_f = sum_f + f_reg[1]; sum_u = sum_u + u_reg[1]; end
                            if (subset[2]) begin sum_c = sum_c + c_reg[2]; sum_f = sum_f + f_reg[2]; sum_u = sum_u + u_reg[2]; end
                            if (subset[3]) begin sum_c = sum_c + c_reg[3]; sum_f = sum_f + f_reg[3]; sum_u = sum_u + u_reg[3]; end
                            
                            // Check if winnable with current mid
                            // We need C_final >= F_final + 1
                            // C + x >= F + (U - x) + 1  => 2x >= F - C + U + 1
                            // x >= (F - C + U + 1) / 2
                            // x is the U allocated to C.
                            // Total x over all won states must be <= mid.
                            
                            if (sum_f >= sum_c + sum_u + 1) begin
                                // Even with all U, F wins. Impossible for this subset.
                            end else begin
                                // We can win this subset.
                                // Calculate minimum U needed for this subset.
                                // x_needed = (F - C + U + 1) / 2
                                // Note: Division by 2 is shift right.
                                // We need to handle the +1 properly.
                                // If (F - C + U) is even, +1 makes it odd. /2 rounds up.
                                // If (F - C + U) is odd, +1 makes it even. /2 is exact.
                                // Formula: (F - C + U + 1) >> 1
                                
                                // However, we are comparing against 'mid' which is 0 to 65535 (scaled 16.16).
                                // Wait, the inputs C, F, U are scaled 16.16.
                                // sum_c, sum_f, sum_u are 32-bit scaled.
                                // The 'mid' in binary search is also scaled 16.16 (0 to 65535 << 16).
                                // So we compare scaled values.
                                
                                // u_needed = (sum_f - sum_c + sum_u + 1) >> 1
                                // But we can only use U available in the subset.
                                // Actually, the formula assumes we use U from the subset.
                                // Wait, x is the U added to C.
                                // We have U total in subset = sum_u.
                                // We need x.
                                // Constraint: x <= sum_u.
                                // Constraint: x <= mid (global budget).
                                
                                // If (sum_f - sum_c + sum_u + 1) / 2 <= sum_u, then it's valid locally.
                                // Let's calculate required u.
                                // Use temporary arithmetic
                                reg [33:0] temp_diff; // F - C + U + 1 (can be negative? No, if F < C+U+1)
                                reg [31:0] required_u;
                                
                                // F - C + U + 1. This should be positive if we are here.
                                // F - C can be negative.
                                // Let's just check: if F <= C + U, we can win.
                                // Minimal u to win: 
                                // C + x >= F + (U - x) + 1  => 2x >= F - C + U + 1
                                
                                // Since F <= C + U (checked above), F - C + U >= 0.
                                // required_u = (F - C + U + 1) >> 1.
                                // Need to handle carry.
                                temp_diff = {2'd0, sum_f} - {2'd0, sum_c} + {2'd0, sum_u} + 33'd1;
                                // Shift right 1
                                required_u = temp_diff[32:1];
                                
                                if (required_u <= sum_u && required_u <= mid) begin
                                    found_valid = 1'b1;
                                end
                            end
                        end
                    end
                    
                    if (found_valid) begin
                        search_possible <= 1'b1;
                        search_result <= mid;
                        high <= mid - 32'd1; // Try smaller
                    end else begin
                        low <= mid + 32'd1; // Need more votes
                    end
                    
                    state <= BINARY_SEARCH;
                end

                FINISH: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    if (start) begin
                        // Restart logic if needed, or stay in IDLE
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule