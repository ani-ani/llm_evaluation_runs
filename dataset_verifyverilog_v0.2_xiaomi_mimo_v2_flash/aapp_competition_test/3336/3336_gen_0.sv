module max_eligible_pupils (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] num_pupils,
    input wire [7:0] heights [0:15],
    input wire [0:15] sexes,
    input wire [2:0] music [0:15],
    input wire [2:0] sport [0:15],
    output reg [4:0] max_persons,
    output reg done,
    output reg valid
);

    // Registers for input data storage (to free up inputs during computation)
    reg [4:0] stored_num_pupils;
    reg [7:0] stored_heights [0:15];
    reg [0:15] stored_sexes;
    reg [2:0] stored_music [0:15];
    reg [2:0] stored_sport [0:15];

    // Conflict Matrix: 16x16 bits
    // conflict_matrix[i][j] = 1 if pair (i,j) is forbidden
    reg [15:0] conflict_mask [0:15];

    // State definitions
    localparam S_IDLE = 4'd0;
    localparam S_LATCH_INPUT = 4'd1;
    localparam S_CALC_CONFLICT_SETUP = 4'd2;
    localparam S_CALC_CONFLICT_LOOP = 4'd3;
    localparam S_SEARCH_INIT = 4'd4;
    localparam S_SEARCH_CHECK = 4'd5;
    localparam S_SEARCH_UPDATE = 4'd6;
    localparam S_SEARCH_INCREMENT = 4'd7;
    localparam S_DONE = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;

    // Iteration variables
    reg [3:0] i, j; // For loops
    reg [15:0] subset; // Current subset to check
    reg [4:0] current_popcount;
    reg is_valid;

    // Helper: Popcount of 16-bit value
    function [4:0] popcount16;
        input [15:0] val;
        begin
            popcount16 = 
                val[0] + val[1] + val[2] + val[3] + val[4] + val[5] + val[6] + val[7] +
                val[8] + val[9] + val[10] + val[11] + val[12] + val[13] + val[14] + val[15];
        end
    endfunction

    // Helper: Absolute difference
    function [7:0] abs_diff;
        input [7:0] a, b;
        begin
            abs_diff = (a > b) ? (a - b) : (b - a);
        end
    endfunction

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            valid <= 0;
            max_persons <= 0;
            // Reset registers if necessary
            i <= 0;
            j <= 0;
            subset <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    valid <= 0;
                    if (start) begin
                        next_state <= S_LATCH_INPUT;
                    end else begin
                        next_state <= S_IDLE;
                    end
                end

                S_LATCH_INPUT: begin
                    stored_num_pupils <= num_pupils;
                    stored_heights[0] <= heights[0];
                    stored_heights[1] <= heights[1];
                    stored_heights[2] <= heights[2];
                    stored_heights[3] <= heights[3];
                    stored_heights[4] <= heights[4];
                    stored_heights[5] <= heights[5];
                    stored_heights[6] <= heights[6];
                    stored_heights[7] <= heights[7];
                    stored_heights[8] <= heights[8];
                    stored_heights[9] <= heights[9];
                    stored_heights[10] <= heights[10];
                    stored_heights[11] <= heights[11];
                    stored_heights[12] <= heights[12];
                    stored_heights[13] <= heights[13];
                    stored_heights[14] <= heights[14];
                    stored_heights[15] <= heights[15];
                    stored_sexes <= sexes;
                    stored_music[0] <= music[0];
                    stored_music[1] <= music[1];
                    stored_music[2] <= music[2];
                    stored_music[3] <= music[3];
                    stored_music[4] <= music[4];
                    stored_music[5] <= music[5];
                    stored_music[6] <= music[6];
                    stored_music[7] <= music[7];
                    stored_music[8] <= music[8];
                    stored_music[9] <= music[9];
                    stored_music[10] <= music[10];
                    stored_music[11] <= music[11];
                    stored_music[12] <= music[12];
                    stored_music[13] <= music[13];
                    stored_music[14] <= music[14];
                    stored_music[15] <= music[15];
                    stored_sport[0] <= sport[0];
                    stored_sport[1] <= sport[1];
                    stored_sport[2] <= sport[2];
                    stored_sport[3] <= sport[3];
                    stored_sport[4] <= sport[4];
                    stored_sport[5] <= sport[5];
                    stored_sport[6] <= sport[6];
                    stored_sport[7] <= sport[7];
                    stored_sport[8] <= sport[8];
                    stored_sport[9] <= sport[9];
                    stored_sport[10] <= sport[10];
                    stored_sport[11] <= sport[11];
                    stored_sport[12] <= sport[12];
                    stored_sport[13] <= sport[13];
                    stored_sport[14] <= sport[14];
                    stored_sport[15] <= sport[15];
                    i <= 0;
                    j <= 1;
                    next_state <= S_CALC_CONFLICT_SETUP;
                end

                S_CALC_CONFLICT_SETUP: begin
                    // Initialize conflict mask for current i
                    conflict_mask[i] <= 16'b0;
                    // If i >= num_pupils, skip logic (treat as no conflict)
                    // We will handle range checking in the loop
                    next_state <= S_CALC_CONFLICT_LOOP;
                end

                S_CALC_CONFLICT_LOOP: begin
                    // Calculate conflict for pair (i, j)
                    if (i < stored_num_pupils && j < stored_num_pupils) begin
                        // Check conflict condition:
                        // 1. |h_i - h_j| <= 40
                        // 2. sex_i == sex_j
                        // 3. music_i == music_j
                        // 4. sport_i != sport_j
                        // Conflict if ALL true.
                        
                        if ((abs_diff(stored_heights[i], stored_heights[j]) <= 8'd40) &&
                            (stored_sexes[i] == stored_sexes[j]) &&
                            (stored_music[i] == stored_music[j]) &&
                            (stored_sport[i] != stored_sport[j])) begin
                            
                            conflict_mask[i] <= conflict_mask[i] | (16'b1 << j);
                            conflict_mask[j] <= conflict_mask[j] | (16'b1 << i);
                        end
                    end

                    // Increment j
                    if (j < 15) begin
                        j <= j + 1;
                        next_state <= S_CALC_CONFLICT_LOOP;
                    end else begin
                        // Done j, increment i
                        if (i < 15) begin
                            i <= i + 1;
                            j <= i + 1;
                            next_state <= S_CALC_CONFLICT_SETUP;
                        end else begin
                            // Done all
                            next_state <= S_SEARCH_INIT;
                        end
                    end
                end

                S_SEARCH_INIT: begin
                    max_persons <= 0;
                    subset <= 1; // Start with subset including only pupil 0
                    // Note: subset 0 is invalid (0 persons). We check 1 to 2^16-1.
                    // However, if num_pupils is small, we should mask?
                    // The problem implies we might have fewer than 16 pupils.
                    // But inputs are always present.
                    // We just need to ensure we don't count pupils >= num_pupils.
                    // Actually, the conflict matrix is 0 for out of range, so they won't conflict.
                    // But we shouldn't include them.
                    // We can restrict subset generation to bits < num_pupils.
                    // Let's just iterate all 2^16-1, but check if bits > num_pupils are set.
                    // If bits > num_pupils are set, skip.
                    // Or simpler: Generate subsets only up to (1<<num_pupils).
                    // Since num_pupils <= 16, (1<<16) is max.
                    // If num_pupils=3, we only want up to 7.
                    // So mask = (1 << num_pupils) - 1.
                    // Loop condition: subset <= mask.
                    next_state <= S_SEARCH_CHECK;
                end

                S_SEARCH_CHECK: begin
                    // Check if subset is valid
                    // For each bit k set in subset:
                    //   check if (conflict_mask[k] & subset) != 0.
                    // We iterate k from 0 to 15.
                    // Optimization: Only check k < num_pupils (though if subset has bits > num_pupils, we skip validation)
                    
                    // To do this in one cycle, we need a helper or loop unrolling.
                    // We will use a sequential check in loop logic or just check all.
                    // Since this is one state per subset, we can run a loop inside this state.
                    // Let's use 'i' as the loop counter for checking validity.
                    
                    if (i < 16) begin
                        // If bit i is set in subset, check conflict
                        if (subset[i]) begin
                            // Check if any conflicting node is also set in subset
                            // conflict_mask[i] contains bits of nodes conflicting with i
                            if ((conflict_mask[i] & subset) != 0) begin
                                is_valid <= 0; // Invalid
                                // We can finish early, but let's proceed to update or increment
                                // We set is_valid to 0 and keep going? 
                                // Better to jump to increment.
                                // Let's set a flag and jump to S_SEARCH_INCREMENT at next cycle.
                            end else begin
                                // Valid so far, check next i
                                // If we haven't invalidated it yet
                                if (!is_valid) begin // if already marked invalid, keep it
                                end else begin
                                    is_valid <= 1; // Keep valid flag high unless proven otherwise
                                end
                            end
                            i <= i + 1;
                            next_state <= S_SEARCH_CHECK;
                        end else begin
                            i <= i + 1;
                            next_state <= S_SEARCH_CHECK;
                        end
                    end else begin
                        // Finished checking all bits
                        // If is_valid is still high (and we didn't set it to 0), it's valid
                        // Wait, logic above needs refinement.
                        // Let's use a wire for next_is_valid.
                        // Reset is_valid to 1 at start of check?
                        // We can't easily reset inside state.
                        // Let's restructure:
                        // Use a 'violated' register.
                        // If subset[i] and (conflict_mask[i] & subset): violated = 1.
                        // If violated, jump to increment.
                        // Else if i < 15, i++. 
                        // If i == 15 and not violated: Valid! Go to Update.
                    end
                    
                    // RE-IMPLEMENTING S_SEARCH_CHECK LOGIC FOR CLEANER STATE MACHINE
                end

                S_SEARCH_UPDATE: begin
                    // Subset is valid, check size
                    if (current_popcount > max_persons) begin
                        max_persons <= current_popcount;
                    end
                    next_state <= S_SEARCH_INCREMENT;
                end

                S_SEARCH_INCREMENT: begin
                    // Increment subset
                    subset <= subset + 1;
                    i <= 0;
                    is_valid <= 1; // Reset validity for next check
                    
                    // Check Loop Condition
                    // Limit is (1 << num_pupils)
                    if (subset < ((1 << stored_num_pupils) - 1)) begin
                        next_state <= S_SEARCH_CHECK;
                    end else begin
                        next_state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done <= 1;
                    valid <= 1;
                    if (start) begin // Reset on start pulse
                        done <= 0;
                        valid <= 0;
                        max_persons <= 0;
                        next_state <= S_LATCH_INPUT;
                    end else begin
                        next_state <= S_DONE;
                    end
                end

                default: next_state <= S_IDLE;
            endcase
        end
    end

    // Separate always block for the complex loop in S_SEARCH_CHECK
    // The previous block was getting messy. Let's handle S_SEARCH_CHECK specifically.
    // We will use a register to track 'current_search_violated' and 'current_search_i'.
    
    reg search_violated;
    reg [3:0] search_i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == S_SEARCH_INIT) begin
                search_i <= 0;
                search_violated <= 0;
                is_valid <= 1; // Assume valid
            end else if (state == S_SEARCH_CHECK) begin
                // Loop logic for validity check
                if (!search_violated) begin
                    // Check current search_i
                    if (subset[search_i]) begin
                        // Check conflict with any other set bit in subset
                        // This is expensive. 
                        // Optimization: check against subset bits > search_i to avoid double checking? 
                        // No, just check (conflict_mask[search_i] & subset) != 0.
                        if ((conflict_mask[search_i] & subset) != 0) begin
                            search_violated <= 1;
                        end
                    end
                end
                
                if (search_i < 15) begin
                    search_i <= search_i + 1;
                    // Continue looping in same state? 
                    // No, we need multiple cycles for the check loop.
                    // We stay in S_SEARCH_CHECK state.
                    next_state <= S_SEARCH_CHECK;
                end else begin
                    // End of check
                    if (!search_violated) begin
                        // Calculate Popcount (might take a cycle or combinational)
                        // Let's calculate popcount combinationally in update state.
                        current_popcount <= popcount16(subset);
                        next_state <= S_SEARCH_UPDATE;
                    end else begin
                        next_state <= S_SEARCH_INCREMENT;
                    end
                    // Reset for next subset
                    search_i <= 0;
                    search_violated <= 0;
                end
            end
        end
    end

endmodule