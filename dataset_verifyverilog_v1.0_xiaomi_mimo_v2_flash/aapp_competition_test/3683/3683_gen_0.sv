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

    // State definitions
    localparam [3:0] IDLE             = 4'd0;
    localparam [3:0] COMPUTE_ADJ      = 4'd1;
    localparam [3:0] COMPUTE_RANK     = 4'd2;
    localparam [3:0] UPDATE_RANK      = 4'd3;
    localparam [3:0] UPDATE_MIN_RANK  = 4'd4;
    localparam [3:0] INCREMENT_LL     = 4'd5;
    localparam [3:0] FINISHED         = 4'd6;

    // Constants
    localparam [7:0] LL_MAX = 8'd255;
    localparam [7:0] NUM_PLAYERS = 8'd8;
    localparam [7:0] NUM_HOLES = 8'd8;
    localparam [7:0] MAX_RANK = 8'd8;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] ll_counter, next_ll_counter;
    reg [2:0] player_idx, next_player_idx;
    reg [2:0] hole_idx, next_hole_idx;
    reg [2:0] other_idx, next_other_idx;
    reg [7:0] adj_total [0:7]; // 8 players, each 8 bits
    reg [3:0] rank [0:7];       // 8 players, each 4 bits
    reg [2:0] adj_total_ptr, next_adj_total_ptr;
    reg [3:0] rank_ptr, next_rank_ptr;
    reg [7:0] temp_adj, next_temp_adj;
    reg [7:0] temp_rank, next_temp_rank;
    reg [3:0] loop_counter, next_loop_counter; // Generic loop counter
    reg [7:0] cycle_count, next_cycle_count;

    // Wires for score lookups
    reg [7:0] current_score;
    reg [7:0] current_player_total;
    reg [7:0] other_player_total;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ll_counter <= 8'd0;
            player_idx <= 3'd0;
            hole_idx <= 3'd0;
            other_idx <= 3'd0;
            adj_total_ptr <= 3'd0;
            rank_ptr <= 3'd0;
            temp_adj <= 8'd0;
            temp_rank <= 8'd0;
            loop_counter <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize adj_total and rank
            adj_total[0] <= 8'd0; adj_total[1] <= 8'd0; adj_total[2] <= 8'd0; adj_total[3] <= 8'd0;
            adj_total[4] <= 8'd0; adj_total[5] <= 8'd0; adj_total[6] <= 8'd0; adj_total[7] <= 8'd0;
            rank[0] <= 4'd0; rank[1] <= 4'd0; rank[2] <= 4'd0; rank[3] <= 4'd0;
            rank[4] <= 4'd0; rank[5] <= 4'd0; rank[6] <= 4'd0; rank[7] <= 4'd0;
            min_rank_0 <= 4'd0; min_rank_1 <= 4'd0; min_rank_2 <= 4'd0; min_rank_3 <= 4'd0;
            min_rank_4 <= 4'd0; min_rank_5 <= 4'd0; min_rank_6 <= 4'd0; min_rank_7 <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            ll_counter <= next_ll_counter;
            player_idx <= next_player_idx;
            hole_idx <= next_hole_idx;
            other_idx <= next_other_idx;
            adj_total_ptr <= next_adj_total_ptr;
            rank_ptr <= next_rank_ptr;
            temp_adj <= next_temp_adj;
            temp_rank <= next_temp_rank;
            loop_counter <= next_loop_counter;
            cycle_count <= next_cycle_count;
            // No assignment to adj_total or rank arrays here, handled in combinational logic
        end
    end

    // Combinational logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_ll_counter = ll_counter;
        next_player_idx = player_idx;
        next_hole_idx = hole_idx;
        next_other_idx = other_idx;
        next_adj_total_ptr = adj_total_ptr;
        next_rank_ptr = rank_ptr;
        next_temp_adj = temp_adj;
        next_temp_rank = temp_rank;
        next_loop_counter = loop_counter;
        next_cycle_count = cycle_count + 8'd1;
        done = 1'b0;

        // Default score lookup (safe default)
        current_score = 8'd255;
        current_player_total = 8'd0;
        other_player_total = 8'd0;

        // Signal assignments
        // Scores from inputs
        case ({player_idx, hole_idx})
            6'h00: current_score = score_0_0; 6'h01: current_score = score_0_1;
            6'h02: current_score = score_0_2; 6'h03: current_score = score_0_3;
            6'h04: current_score = score_0_4; 6'h05: current_score = score_0_5;
            6'h06: current_score = score_0_6; 6'h07: current_score = score_0_7;
            6'h08: current_score = score_1_0; 6'h09: current_score = score_1_1;
            6'h0A: current_score = score_1_2; 6'h0B: current_score = score_1_3;
            6'h0C: current_score = score_1_4; 6'h0D: current_score = score_1_5;
            6'h0E: current_score = score_1_6; 6'h0F: current_score = score_1_7;
            6'h10: current_score = score_2_0; 6'h11: current_score = score_2_1;
            6'h12: current_score = score_2_2; 6'h13: current_score = score_2_3;
            6'h14: current_score = score_2_4; 6'h15: current_score = score_2_5;
            6'h16: current_score = score_2_6; 6'h17: current_score = score_2_7;
            6'h18: current_score = score_3_0; 6'h19: current_score = score_3_1;
            6'h1A: current_score = score_3_2; 6'h1B: current_score = score_3_3;
            6'h1C: current_score = score_3_4; 6'h1D: current_score = score_3_5;
            6'h1E: current_score = score_3_6; 6'h1F: current_score = score_3_7;
            6'h20: current_score = score_4_0; 6'h21: current_score = score_4_1;
            6'h22: current_score = score_4_2; 6'h23: current_score = score_4_3;
            6'h24: current_score = score_4_4; 6'h25: current_score = score_4_5;
            6'h26: current_score = score_4_6; 6'h27: current_score = score_4_7;
            6'h28: current_score = score_5_0; 6'h29: current_score = score_5_1;
            6'h2A: current_score = score_5_2; 6'h2B: current_score = score_5_3;
            6'h2C: current_score = score_5_4; 6'h2D: current_score = score_5_5;
            6'h2E: current_score = score_5_6; 6'h2F: current_score = score_5_7;
            6'h30: current_score = score_6_0; 6'h31: current_score = score_6_1;
            6'h32: current_score = score_6_2; 6'h33: current_score = score_6_3;
            6'h34: current_score = score_6_4; 6'h35: current_score = score_6_5;
            6'h36: current_score = score_6_6; 6'h37: current_score = score_6_7;
            6'h38: current_score = score_7_0; 6'h39: current_score = score_7_1;
            6'h3A: current_score = score_7_2; 6'h3B: current_score = score_7_3;
            6'h3C: current_score = score_7_4; 6'h3D: current_score = score_7_5;
            6'h3E: current_score = score_7_6; 6'h3F: current_score = score_7_7;
            default: current_score = 8'd255;
        endcase

        // Adj total lookup
        case (player_idx)
            3'd0: current_player_total = adj_total[0];
            3'd1: current_player_total = adj_total[1];
            3'd2: current_player_total = adj_total[2];
            3'd3: current_player_total = adj_total[3];
            3'd4: current_player_total = adj_total[4];
            3'd5: current_player_total = adj_total[5];
            3'd6: current_player_total = adj_total[6];
            3'd7: current_player_total = adj_total[7];
            default: current_player_total = 8'd0;
        endcase

        // Other player adj total lookup
        case (other_idx)
            3'd0: other_player_total = adj_total[0];
            3'd1: other_player_total = adj_total[1];
            3'd2: other_player_total = adj_total[2];
            3'd3: other_player_total = adj_total[3];
            3'd4: other_player_total = adj_total[4];
            3'd5: other_player_total = adj_total[5];
            3'd6: other_player_total = adj_total[6];
            3'd7: other_player_total = adj_total[7];
            default: other_player_total = 8'd0;
        endcase

        case (state)
            IDLE: begin
                next_cycle_count = 8'd0;
                done = 1'b0;
                if (start) begin
                    next_ll_counter = 8'd0;
                    next_player_idx = 3'd0;
                    next_hole_idx = 3'd0;
                    next_loop_counter = 4'd0;
                    next_state = COMPUTE_ADJ;
                    // Initialize min ranks to max (8)
                    // Cannot do in procedural assignment here, done in sequential logic
                    // Need to signal update? No, sequential logic handles reset.
                    // But for start, we need to reset internal state?
                    // The logic needs to clear adj_total and rank arrays for this run
                    // To keep it simple, we assume arrays are 0 on first run after reset
                    // and we overwrite them correctly.
                end
            end

            COMPUTE_ADJ: begin
                // Compute adj_total for current player based on current ll_counter
                // Need to sum over all holes
                // We can do this in one cycle if we unroll or use sequential loops
                // Sequential approach: iterate holes 0-7
                if (hole_idx < NUM_HOLES) begin
                    // Update temp_adj with min(score, ll)
                    if (current_score > ll_counter)
                        next_temp_adj = ll_counter;
                    else
                        next_temp_adj = current_score;
                    
                    // Accumulate to adj_total[player_idx] (in temp, write at end of loop)
                    // Actually, let's use a dedicated accumulator in the loop
                    // Since we can't update array element during iteration easily,
                    // we'll compute the full sum and update at the end.
                    // But we need a way to keep the running sum.
                    // Use temp_adj as the accumulator for the current player's sum.
                    // Initialize temp_adj to 0 when entering COMPUTE_ADJ for a new player.
                    // Wait, we enter COMPUTE_ADJ each cycle.
                    // Let's just compute the value for one hole and add to a running register.
                    // Let's use adj_total_ptr as the accumulator index? No.
                    // Let's use temp_adj as the accumulator.
                    // But we need to reset it when starting a new player.
                    // Reset logic: if hole_idx == 0, temp_adj = 0.
                    if (hole_idx == 3'd0) begin
                        next_temp_adj = 8'd0;
                    end
                    
                    // Add min(current_score, ll_counter) to next_temp_adj
                    if (current_score < ll_counter)
                        next_temp_adj = temp_adj + current_score;
                    else
                        next_temp_adj = temp_adj + ll_counter;

                    next_hole_idx = hole_idx + 3'd1;
                    next_state = COMPUTE_ADJ;
                end else begin
                    // Done holes for this player
                    // Store result in adj_total[player_idx]
                    next_temp_adj = temp_adj; // Keep the value
                    next_state = INCREMENT_LL; // Transition to update min rank logic or next player?
                    // Actually, we need to compute adj_total for ALL players for current ll
                    // THEN compute ranks.
                    // So, after finishing one player, go to next player.
                    if (player_idx < NUM_PLAYERS - 1) begin
                        next_player_idx = player_idx + 3'd1;
                        next_hole_idx = 3'd0;
                        next_temp_adj = 8'd0; // Reset for next player
                        next_state = COMPUTE_ADJ;
                    end else begin
                        // Done computing adj_total for all players for this ll
                        // Save last player's result
                        // (Handled by temp_adj update above)
                        next_player_idx = 3'd0;
                        next_hole_idx = 3'd0;
                        next_temp_rank = 8'd0; // Initialize rank accumulator
                        next_loop_counter = 4'd0; // Reset other loop counter
                        next_state = COMPUTE_RANK;
                    end
                end
            end

            COMPUTE_RANK: begin
                // Compute rank for player_idx
                // Rank = 1 + count(other players where other_adj < current_adj)
                // Initialize rank count to 1
                if (other_idx == 3'd0) begin
                    next_temp_rank = 8'd1;
                end

                // Compare with other_idx
                // Check if other_idx != player_idx
                if (other_idx != player_idx) begin
                    // Use current_player_total (fetched from adj_total)
                    // Use other_player_total (fetched from adj_total)
                    if (other_player_total < current_player_total) begin
                        next_temp_rank = temp_rank + 8'd1;
                    end
                end

                next_other_idx = other_idx + 3'd1;
                
                if (other_idx < NUM_PLAYERS - 1) begin
                    next_state = COMPUTE_RANK;
                end else begin
                    // Done ranking this player
                    next_state = UPDATE_RANK;
                end
            end

            UPDATE_RANK: begin
                // Store rank in rank array
                // next_rank_ptr used as state var? No, just update array.
                // We cannot update procedural array here directly in comb block.
                // We need to propagate the update to sequential block.
                // Since rank is an array, we can't just say rank[player_idx] <= temp_rank
                // in comb block. We need a way to signal the write.
                // This is a limitation of Verilog with Icarus.
                // Solution: Compute ranks first, then update min_ranks.
                // Actually, we can't update the rank array in a simple way without a separate write cycle.
                // Let's skip storing rank array explicitly if possible.
                // We can directly update min_rank if we compute rank on the fly and compare.
                // But we need rank for all players to compute min_rank correctly?
                // No, we need the rank of player_idx to compare with min_rank[player_idx].
                // So we compute rank for player_idx -> temp_rank.
                // Then update min_rank[player_idx] = min(min_rank[player_idx], temp_rank).
                // We can do that here.

                // Update min_rank for player_idx
                case (player_idx)
                    3'd0: begin if (temp_rank < min_rank_0) min_rank_0 <= temp_rank; end
                    3'd1: begin if (temp_rank < min_rank_1) min_rank_1 <= temp_rank; end
                    3'd2: begin if (temp_rank < min_rank_2) min_rank_2 <= temp_rank; end
                    3'd3: begin if (temp_rank < min_rank_3) min_rank_3 <= temp_rank; end
                    3'd4: begin if (temp_rank < min_rank_4) min_rank_4 <= temp_rank; end
                    3'd5: begin if (temp_rank < min_rank_5) min_rank_5 <= temp_rank; end
                    3'd6: begin if (temp_rank < min_rank_6) min_rank_6 <= temp_rank; end
                    3'd7: begin if (temp_rank < min_rank_7) min_rank_7 <= temp_rank; end
                endcase

                next_other_idx = 3'd0;
                
                if (player_idx < NUM_PLAYERS - 1) begin
                    next_player_idx = player_idx + 3'd1;
                    next_state = COMPUTE_RANK;
                end else begin
                    next_player_idx = 3'd0;
                    next_state = INCREMENT_LL;
                end
            end

            INCREMENT_LL: begin
                next_ll_counter = ll_counter + 8'd1;
                next_hole_idx = 3'd0;
                next_player_idx = 3'd0;
                next_temp_adj = 8'd0; // Prepare for next compute cycle
                
                if (ll_counter < LL_MAX - 1) begin
                    next_state = COMPUTE_ADJ;
                end else begin
                    next_state = FINISHED;
                end
            end

            FINISHED: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase

        // Infinite loop protection
        if (cycle_count > 8'd200) begin
            next_state = IDLE;
        end
    end

    // Update adj_total array logic
    // We need a block to update adj_total[...] based on temp_adj when transitioning out of COMPUTE_ADJ for a player
    // This is tricky. We will move the write logic to the sequential block or use a write_enable signal.
    // Let's add a write signal.
    reg write_adj;
    reg [2:0] write_idx;
    reg [7:0] write_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // init
        end else begin
            if (write_adj) begin
                case (write_idx)
                    3'd0: adj_total[0] <= write_data;
                    3'd1: adj_total[1] <= write_data;
                    3'd2: adj_total[2] <= write_data;
                    3'd3: adj_total[3] <= write_data;
                    3'd4: adj_total[4] <= write_data;
                    3'd5: adj_total[5] <= write_data;
                    3'd6: adj_total[6] <= write_data;
                    3'd7: adj_total[7] <= write_data;
                endcase
            end
        end
    end

    // Re-evaluate comb logic for write signals (or integrate into main always block)
    // To avoid circular logic, let's put write logic inside the comb block logic above
    // using non-blocking assignments in a separate sequential block is cleaner but adds state.
    // Given the complexity, we'll calculate `write_adj` in the comb block.

    always @(*) begin
        write_adj = 1'b0;
        write_idx = 3'd0;
        write_data = 8'd0;

        // Logic to detect when we finished a player in COMPUTE_ADJ
        // We need to catch the transition. 
        // This is hard with pure comb logic if state changes simultaneously.
        // Let's rely on the state machine structure.
        // When we are in COMPUTE_ADJ and hole_idx wraps around (== NUM_HOLES), we are done.
        // At that cycle, we have temp_adj ready.
        // We should write it.
        // But in the comb block above, next_hole_idx wraps to 0 and state changes.
        // We can check if we are exiting COMPUTE_ADJ for a player.
        // Condition: state == COMPUTE_ADJ && hole_idx == NUM_HOLES && next_state != COMPUTE_ADJ
        // This requires lookahead which is valid in comb logic.
        
        // Actually, let's simplify the adj_total update.
        // We can update adj_total in the sequential block triggered by a flag.
        // Or, we can use the INCREMENT_LL state to update the last player's data?
        // No, we need it for rank calculation.
        
        // Let's modify the state machine to have an explicit WRITE_ADJ state.
        // IDLE -> COMPUTE_ADJ (per player) -> WRITE_ADJ -> ... -> INCREMENT_LL
        // Or COMPUTE_ADJ (per hole) -> COMPUTE_ADJ ...
        // If hole_idx == 0, we reset temp_adj.
        // If hole_idx == 7 (last), we add the last value and write.
        
        // New logic for updating adj_total:
        // We can write to adj_total when we finish the last hole (hole_idx == 7).
        // Because the loop goes 0 to 7, and at 7 we update temp_adj.
        // Next cycle, we would go to hole_idx == 8 (which is NUM_HOLES).
        // So we write when hole_idx == 7.
        // Wait, the loop is 0 to 7 (8 holes).
        // If hole_idx < 8, process.
        // At hole_idx == 7, we add score[7] to temp.
        // This temp value IS the total.
        // We should write it to adj_total[player_idx] NOW.
        // Then hole_idx becomes 8, and we move to next player.
        
        if (state == COMPUTE_ADJ && hole_idx < NUM_HOLES && hole_idx == 3'd7) begin
            write_adj = 1'b1;
            write_idx = player_idx;
            // Calculate value to write (same logic as next_temp_adj)
            if (current_score < ll_counter)
                write_data = temp_adj + current_score;
            else
                write_data = temp_adj + ll_counter;
        end
    end

endmodule
