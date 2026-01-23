module minPath(
    input clk,
    input rst_n,
    input start,
    input [1:0][1:0][7:0] grid,
    input [3:0] k,
    output reg [9:0][7:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam PROCESS_STEP = 3'b010;
    localparam CHECK_COMPLETE = 3'b011;
    localparam DONE = 3'b100;

    // Registers for State Machine
    reg [2:0] current_state;
    reg [2:0] next_state;

    // Path Storage: path[i] holds value at position i (0-indexed)
    // path_pos[i] holds coordinates {row, col} for position i
    reg [7:0] path [0:9];
    reg [1:0] path_pos_row [0:9];
    reg [1:0] path_pos_col [0:9];

    // Path length counter (number of cells currently in path)
    reg [3:0] curr_len;

    // Loop variables
    reg [3:0] i;
    reg [1:0] j;

    // Candidate Path Registers for Evaluation
    // candidates stores up to 4 paths. Each path is 10x8 values (full length array)
    reg [9:0][7:0] candidates [0:3];
    // candidates_pos stores the coordinates of the next step for each candidate
    reg [1:0] candidates_row [0:3];
    reg [1:0] candidates_col [0:3];
    // valid_candidate indicates if the candidate is valid (neighbor exists and unique)
    reg [3:0] valid_candidate;
    reg [3:0] candidate_count;

    // Phase counter for PROCESS_STEP state
    reg [3:0] step_phase;

    // Registers for lexicographical comparison
    reg [9:0][7:0] best_cand;
    reg [9:0][7:0] temp_cand;
    reg is_better;

    // Neighbor generation registers
    reg [1:0] cand_idx;
    reg [1:0] nr, nc;
    reg is_duplicate;

    // Helper task to update state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Main Logic FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Logic
            done <= 1'b0;
            curr_len <= 4'd0;
            step_phase <= 4'd0;
            cand_idx <= 2'd0;
            candidate_count <= 4'd0;
            valid_candidate <= 4'd0;
            // Clear result
            for (i = 0; i < 10; i = i + 1) result[i] <= 8'h00;
            // Clear path
            for (i = 0; i < 10; i = i + 1) begin
                path[i] <= 8'h00;
                path_pos_row[i] <= 2'b00;
                path_pos_col[i] <= 2'b00;
            end
            // Clear candidates
            for (int idx = 0; idx < 4; idx++) begin
                valid_candidate[idx] <= 1'b0;
                for (int k = 0; k < 10; k++) candidates[idx][k] <= 8'h00;
                candidates_row[idx] <= 2'b00;
                candidates_col[idx] <= 2'b00;
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                        curr_len <= 4'd0;
                        step_phase <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Find global minimum and set as first element of path
                    // Assuming minimum is always 1, scanning to find it (or just take 1)
                    // If we must scan, do it here. But given constraints "Values are 1-4" and "global minimum (should be 1)",
                    // we can just find the first occurrence.

                    // Simple logic to put min value (1) at index 0
                    // We scan coordinates (0,0), (0,1), (1,0), (1,1)
                    if (grid[0][0] == 8'd1) begin
                        path[0] <= 8'd1;
                        path_pos_row[0] <= 2'd0;
                        path_pos_col[0] <= 2'd0;
                    end else if (grid[0][1] == 8'd1) begin
                        path[0] <= 8'd1;
                        path_pos_row[0] <= 2'd0;
                        path_pos_col[0] <= 2'd1;
                    end else if (grid[1][0] == 8'd1) begin
                        path[0] <= 8'd1;
                        path_pos_row[0] <= 2'd1;
                        path_pos_col[0] <= 2'd0;
                    end else begin
                        path[0] <= 8'd1;
                        path_pos_row[0] <= 2'd1;
                        path_pos_col[0] <= 2'd1;
                    end

                    curr_len <= 4'd1;

                    // Reset result
                    for (i = 0; i < 10; i = i + 1) result[i] <= 8'h00;
                    done <= 1'b0;

                    next_state <= CHECK_COMPLETE;
                end

                PROCESS_STEP: begin
                    // Generates candidates for the next step.
                    // Splits into phases to stay within cycle budget (~20 cycles)
                    // Phase 0: Reset candidate storage
                    // Phase 1: Check Right neighbor
                    // Phase 2: Check Left neighbor
                    // Phase 3: Check Down neighbor
                    // Phase 4: Check Up neighbor
                    // Phase 5: Selection Logic

                    case (step_phase)
                        4'd0: begin
                            // Initialize candidates
                            candidate_count <= 4'd0;
                            valid_candidate <= 4'b0000;
                            // Clear valid flags in array storage
                            // (Implicitly handled by checking valid_candidate bits)
                            step_phase <= 4'd1;
                        end

                        4'd1, 4'd2, 4'd3, 4'd4: begin
                            // Check a neighbor based on step_phase
                            // 1 -> Right, 2 -> Left, 3 -> Down, 4 -> Up
                            if (candidate_count < 4'd4) begin
                                // Determine neighbor coordinates
                                if (step_phase == 4'd1) begin // Right
                                    nr <= path_pos_row[curr_len-1];
                                    nc <= path_pos_col[curr_len-1] + 1;
                                end else if (step_phase == 4'd2) begin // Left
                                    nr <= path_pos_row[curr_len-1];
                                    nc <= path_pos_col[curr_len-1] - 1;
                                end else if (step_phase == 4'd3) begin // Down
                                    nr <= path_pos_row[curr_len-1] + 1;
                                    nc <= path_pos_col[curr_len-1];
                                end else if (step_phase == 4'd4) begin // Up
                                    nr <= path_pos_row[curr_len-1] - 1;
                                    nc <= path_pos_col[curr_len-1];
                                end

                                // Check bounds (0 to 1)
                                // Logic for bounds check and uniqueness
                                // We check uniqueness against current path
                                is_duplicate <= 1'b0;

                                // Defer validity check to next cycle or handle inline if comb is fast enough.
                                // To keep it simple and sequential:
                                step_phase <= step_phase + 1'b1; // Move to processing or next check
                            end else begin
                                step_phase <= 4'd5; // All candidates scanned or full
                            end
                        end

                        // Specific cycle for recording valid candidates (inserted between bounds check and next check)
                        // Actually, let's do the check and record in the same phase cycle, but split phase 1-4 into sub-cycles.
                        // Optimization: Combine check and record.
                        // Let's use step_phase 10, 11, 12, 13 for actual evaluation to ensure 20 cycle budget.

                        default: begin
                            step_phase <= 4'd5;
                        end
                    endcase

                    // To strictly meet "evaluate up to 4 neighbors" and "lexicographically smallest",
                    // we will use a separate state or sub-states.
                    // Let's implement a cleaner logic inside PROCESS_STEP using the step_phase counter.

                    // Re-evaluating PROCESS_STEP logic to be cleaner:
                    // Phase 0: Reset
                    // Phase 1: Check Right (0, +1)
                    // Phase 2: Check Left (0, -1)
                    // Phase 3: Check Down (+1, 0)
                    // Phase 4: Check Up (-1, 0)
                    // Phase 5-8: Selection (simple linear compare)
                    // Phase 9: Done

                    if (step_phase == 4'd0) begin
                        candidate_count <= 4'd0;
                        valid_candidate <= 4'b0000;
                        step_phase <= 4'd1;
                    end else if (step_phase >= 4'd1 && step_phase <= 4'd4) begin
                        // Identify neighbor
                        nr <= path_pos_row[curr_len-1];
                        nc <= path_pos_col[curr_len-1];

                        case (step_phase)
                            4'd1: nc <= path_pos_col[curr_len-1] + 1; // Right
                            4'd2: nc <= path_pos_col[curr_len-1] - 1; // Left
                            4'd3: nr <= path_pos_row[curr_len-1] + 1; // Down
                            4'd4: nr <= path_pos_row[curr_len-1] - 1; // Up
                        endcase

                        step_phase <= step_phase + 1'b1;
                    end else if (step_phase >= 4'd5 && step_phase <= 4'd8) begin
                        // Evaluate the neighbor proposed in the previous cycle (stored in nr, nc)
                        // Check bounds and duplicates
                        // Bounds: nr < 2 && nc < 2 (unsigned comparison for 2 bits usually implies 0-3, so check <2)
                        // Actually, inputs are 2-bit. 00, 01, 10, 11. We want 00, 01. 
                        // If we did subtraction (e.g., 0-1 -> 11), it wraps. So we must check if result is valid 0/1.

                        // Check Bounds: result must be 0 or 1. 
                        // Since we are in 2-bit, let's explicitly check.
                        // However, 'nc < 2' works for 00(0), 01(1), 10(2), 11(3).
                        // BUT subtraction wraps! (0-1=11=3). So 11 is invalid.

                        if ((nr < 2) && (nc < 2)) begin
                            // Check duplicate in path[0]...path[curr_len-1]
                            is_duplicate <= 1'b0;
                            for (int k = 0; k < 10; k++) begin // Check up to curr_len
                                if (k < curr_len && path_pos_row[k] == nr && path_pos_col[k] == nc) begin
                                    is_duplicate <= 1'b1;
                                end
                            end

                            if (!is_duplicate) begin
                                // Add to candidates
                                if (candidate_count < 4) begin
                                    // Copy current path to candidate
                                    for (int p = 0; p < 10; p++) begin
                                        if (p < curr_len) candidates[candidate_count][p] <= path[p];
                                        else candidates[candidate_count][p] <= 8'h00;
                                    end
                                    // Append new value
                                    candidates[candidate_count][curr_len] <= grid[nr][nc];
                                    // Store position
                                    candidates_row[candidate_count] <= nr;
                                    candidates_col[candidate_count] <= nc;
                                    // Mark valid
                                    valid_candidate[candidate_count] <= 1'b1;
                                    candidate_count <= candidate_count + 1'b1;
                                end
                            end
                        end

                        // Move to next evaluation phase or selection
                        if (step_phase == 4'd8) step_phase <= 4'd9; // All neighbors checked
                        else step_phase <= step_phase + 1'b1; // Check next neighbor
                    end else if (step_phase == 4'd9) begin
                        // Select Best Candidate (Lexicographically Smallest)
                        // Find first valid candidate and set as best
                        if (valid_candidate[0]) begin
                            best_cand <= candidates[0];
                        end else if (valid_candidate[1]) begin
                            best_cand <= candidates[1];
                        end else if (valid_candidate[2]) begin
                            best_cand <= candidates[2];
                        end else if (valid_candidate[3]) begin
                            best_cand <= candidates[3];
                        end
                        // If none valid, something is wrong, but we handle it by just waiting or staying done?
                        // In a valid grid (2x2), there should always be at least one neighbor if curr_len > 1.
                        // For len 1, start pos has neighbors.

                        step_phase <= 4'd10;
                    end else if (step_phase >= 4'd10 && step_phase <= 4'd12) begin
                        // Compare remaining candidates against best_cand
                        // If step_phase == 10: compare candidate 1 vs best
                        // If step_phase == 11: compare candidate 2 vs best
                        // If step_phase == 12: compare candidate 3 vs best

                        is_better <= 1'b0;
                        temp_cand <= best_cand;

                        // Determine which candidate to compare
                        if (step_phase == 4'd10 && valid_candidate[1]) begin
                            temp_cand <= candidates[1];
                        end else if (step_phase == 4'd11 && valid_candidate[2]) begin
                            temp_cand <= candidates[2];
                        end else if (step_phase == 4'd12 && valid_candidate[3]) begin
                            temp_cand <= candidates[3];
                        end else begin
                            // Skip if invalid, just increment phase
                            // We need a way to skip. Let's just check valid bit inside comparison logic next cycle?
                            // Or just handle comparison in 4 cycles total.
                        end
                        step_phase <= step_phase + 1'b1;
                    end else if (step_phase == 4'd13) begin
                        // Perform Comparison Logic (Comb from previous cycle registers)
                        // Compare temp_cand vs best_cand
                        // Lexicographical order: compare index 0, then 1, etc.

                        // Logic: if temp_cand < best_cand, update best_cand.
                        // Simple check:
                        for (int k = 0; k < 10; k++) begin
                            if (temp_cand[k] < best_cand[k]) begin
                                best_cand <= temp_cand;
                                break;
                            end else if (temp_cand[k] > best_cand[k]) begin
                                break;
                            end
                        end

                        // We did comparison for candidates 1, 2, 3 in previous steps?
                        // Wait, the previous phase stored temp_cand. 
                        // We need to check if the stored temp_cand (from phase 10, 11, 12) is better than best.
                        // Actually, we need a loop. Let's use a counter for the comparison loop to save states.

                        // Revised Comparison Logic: 
                        // Use a register 'comp_idx' to iterate through valid candidates 1,2,3.
                        // If comp_idx < candidate_count:
                        //    Load candidate[comp_idx] to temp_cand.
                        //    Compare with best_cand.
                        //    If better, update best_cand.
                        //    Increment comp_idx.
                        //    Stay in this phase.
                        // Else:
                        //    Move to UPDATE_PATH.

                        // Wait, I used step_phase for phases. Let's stick to step_phase.
                        // Actually, let's make step_phase handle the comparison loop.
                        // But step_phase is limited to 4 bits.
                        // Let's introduce a separate counter for comparison if needed, or re-use step_phase.

                        // Let's simply the PROCESS_STEP flow:
                        // Phase 0: Reset
                        // Phase 1-4: Generate Candidates (checked)
                        // Phase 5: Select Best (Initial)
                        // Phase 6: Compare C1 vs Best
                        // Phase 7: Compare C2 vs Best
                        // Phase 8: Compare C3 vs Best
                        // Phase 9: Update Path

                        // Let's rewrite the PROCESS_STEP block logic in the code below to be cleaner.
                        // For the purpose of this response, I will implement a robust version.

                        // Since the previous logic was getting complex, let's reset the logic in the code below
                        // to a clean sequential implementation.

                        // In this else-if chain, we are inside PROCESS_STEP.
                        // Let's handle Phase 5 (Select Best) specifically here, as my previous flow missed it.

                    end
                end

                CHECK_COMPLETE: begin
                    if (curr_len >= k) begin
                        // Path complete, copy to output
                        for (int p = 0; p < 10; p++) begin
                            if (p < curr_len) result[p] <= path[p];
                            else result[p] <= 8'h00;
                        end
                        next_state <= DONE;
                    end else begin
                        next_state <= PROCESS_STEP;
                        step_phase <= 4'd0; // Start PROCESS_STEP from beginning
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low before accepting new
                        next_state <= IDLE;
                    end else begin
                        next_state <= DONE;
                    end
                end
            endcase
        end
    end

    // ---------------------------------------------------------
    // Re-implementation of PROCESS_STEP state logic
    // To ensure correctness and meet the 20 cycle requirement,
    // we separate the FSM state logic (above) from the datapath logic (below).
    // However, since we are describing a sequential block, we need to 
    // carefully structure the always @(posedge clk) block.
    // 
    // Let's define the datapath behavior inside PROCESS_STEP clearly.
    // ---------------------------------------------------------

    // We will override the empty PROCESS_STEP logic above with a complete implementation
    // using a variable 'step_phase'.

    // The previous always block skeleton is hard to extend in text. 
    // I will rewrite the always block completely below to ensure it works.

    // RESET Logic is already defined. We need to integrate the logic.
    // To keep it clean, I will provide the final, consolidated always block.

endmodule

module minPath_FullLogic (
    input clk,
    input rst_n,
    input start,
    input [1:0][1:0][7:0] grid,
    input [3:0] k,
    output reg [9:0][7:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam PROCESS_STEP = 3'b010;
    localparam CHECK_COMPLETE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] current_state, next_state;

    // Registers
    reg [9:0][7:0] path;
    reg [1:0] path_row [0:9];
    reg [1:0] path_col [0:9];
    reg [3:0] curr_len;

    // Processing Registers
    reg [3:0] step_phase;
    reg [9:0][7:0] best_cand;
    reg [9:0][7:0] temp_cand;
    reg [1:0] temp_row, temp_col;
    reg [1:0] cand_idx;

    // Neighbors buffer (up to 4)
    reg [7:0] neigh_val [0:3];
    reg [1:0] neigh_row [0:3];
    reg [1:0] neigh_col [0:3];
    reg [3:0] neigh_valid;
    reg [1:0] neigh_count;

    // Helper vars
    integer i, j;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end

    // Main Datapath and Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            curr_len <= 4'd0;
            step_phase <= 4'd0;
            neigh_count <= 2'd0;
            neigh_valid <= 4'b0000;
            path <= 80'h0;
            for (i=0; i<10; i++) begin path_row[i] <= 2'b0; path_col[i] <= 2'b0; end
            result <= 80'h0;
            best_cand <= 80'h0;
            temp_cand <= 80'h0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) next_state <= INIT;
                    else next_state <= IDLE;
                end

                INIT: begin
                    // Find global min (1) and place at start
                    // Scan grid to find (0,0), (0,1), (1,0), (1,1)
                    if (grid[0][0] == 8'd1) begin
                        path[0] <= 8'd1; path_row[0] <= 2'd0; path_col[0] <= 2'd0;
                    end else if (grid[0][1] == 8'd1) begin
                        path[0] <= 8'd1; path_row[0] <= 2'd0; path_col[0] <= 2'd1;
                    end else if (grid[1][0] == 8'd1) begin
                        path[0] <= 8'd1; path_row[0] <= 2'd1; path_col[0] <= 2'd0;
                    end else begin
                        path[0] <= 8'd1; path_row[0] <= 2'd1; path_col[0] <= 2'd1;
                    end
                    curr_len <= 4'd1;
                    next_state <= CHECK_COMPLETE;
                end

                PROCESS_STEP: begin
                    // Logic split across phases to meet timing
                    case (step_phase)
                        // Phase 0: Reset Candidate Storage
                        4'd0: begin
                            neigh_count <= 2'd0;
                            neigh_valid <= 4'b0000;
                            step_phase <= 4'd1;
                        end

                        // Phase 1: Check Right Neighbor (Row+0, Col+1)
                        4'd1: begin
                            // Calculate coordinates
                            temp_row <= path_row[curr_len-1];
                            temp_col <= path_col[curr_len-1] + 1;
                            step_phase <= 4'd2;
                        end
                        4'd2: begin
                            // Validate and Store
                            if (temp_col < 2 && temp_row < 2) begin
                                // Check duplicate (not strictly needed for neighbors usually, but requirements say "valid move", typically implies no revisit)
                                // Actually, requirements say "valid move", "select lexicographically smallest candidate path". 
                                // Usually grid paths don't revisit. Let's assume no revisit (since values are small, revisiting 1-4 might lead to loops, BFS usually avoids cycle).
                                // However, the prompt doesn't explicitly say "no revisit", but "neighbours" in pathfinding usually implies visiting distinct nodes.
                                // Let's assume no revisit.
                                if (!is_in_path(temp_row, temp_col, path_row, path_col, curr_len)) begin
                                    if (neigh_count < 4) begin
                                        neigh_val[neigh_count] <= grid[temp_row][temp_col];
                                        neigh_row[neigh_count] <= temp_row;
                                        neigh_col[neigh_count] <= temp_col;
                                        neigh_count <= neigh_count + 1;
                                    end
                                end
                            end
                            step_phase <= 4'd3;
                        end

                        // Phase 3: Check Left Neighbor (Row+0, Col-1)
                        4'd3: begin
                            temp_row <= path_row[curr_len-1];
                            temp_col <= path_col[curr_len-1] - 1;
                            step_phase <= 4'd4;
                        end
                        4'd4: begin
                            if (temp_col < 2 && temp_row < 2 && temp_col != 2'b11) begin // Explicit wrap check for subtract
                                if (!is_in_path(temp_row, temp_col, path_row, path_col, curr_len)) begin
                                    if (neigh_count < 4) begin
                                        neigh_val[neigh_count] <= grid[temp_row][temp_col];
                                        neigh_row[neigh_count] <= temp_row;
                                        neigh_col[neigh_count] <= temp_col;
                                        neigh_count <= neigh_count + 1;
                                    end
                                end
                            end
                            step_phase <= 4'd5;
                        end

                        // Phase 5: Check Down Neighbor (Row+1, Col+0)
                        4'd5: begin
                            temp_row <= path_row[curr_len-1] + 1;
                            temp_col <= path_col[curr_len-1];
                            step_phase <= 4'd6;
                        end
                        4'd6: begin
                            if (temp_row < 2 && temp_col < 2) begin
                                if (!is_in_path(temp_row, temp_col, path_row, path_col, curr_len)) begin
                                    if (neigh_count < 4) begin
                                        neigh_val[neigh_count] <= grid[temp_row][temp_col];
                                        neigh_row[neigh_count] <= temp_row;
                                        neigh_col[neigh_count] <= temp_col;
                                        neigh_count <= neigh_count + 1;
                                    end
                                end
                            end
                            step_phase <= 4'd7;
                        end

                        // Phase 7: Check Up Neighbor (Row-1, Col+0)
                        4'd7: begin
                            temp_row <= path_row[curr_len-1] - 1;
                            temp_col <= path_col[curr_len-1];
                            step_phase <= 4'd8;
                        end
                        4'd8: begin
                            if (temp_row < 2 && temp_col < 2 && temp_row != 2'b11) begin
                                if (!is_in_path(temp_row, temp_col, path_row, path_col, curr_len)) begin
                                    if (neigh_count < 4) begin
                                        neigh_val[neigh_count] <= grid[temp_row][temp_col];
                                        neigh_row[neigh_count] <= temp_row;
                                        neigh_col[neigh_count] <= temp_col;
                                        neigh_count <= neigh_count + 1;
                                    end
                                end
                            end
                            step_phase <= 4'd9;
                        end

                        // Phase 9: Select Best Candidate (First valid one)
                        4'd9: begin
                            if (neigh_count > 0) begin
                                // Build candidate path for index 0
                                best_cand <= path; // Copy current path
                                best_cand[curr_len] <= neigh_val[0]; // Append new value
                                cand_idx <= 1; // Start comparing from index 1
                            end else begin
                                // Should not happen in valid 2x2 grid with curr_len < 10
                                // But if it does, we might be stuck. Just complete? 
                                // Let's go to CHECK_COMPLETE to see if len >= k.
                                next_state <= CHECK_COMPLETE;
                                step_phase <= 0;
                            end

                            if (neigh_count > 1) step_phase <= 4'd10;
                            else step_phase <= 4'd15; // Skip to update if only 1 candidate
                        end

                        // Phase 10-14: Compare Candidates
                        // We compare cand_idx against best_cand
                        4'd10, 4'd11, 4'd12, 4'd13: begin
                            if (cand_idx < neigh_count) begin
                                // Build temp candidate
                                temp_cand <= path;
                                temp_cand[curr_len] <= neigh_val[cand_idx];
                                step_phase <= 4'd14; // Go to compare exec
                            end else begin
                                step_phase <= 4'd15; // Done comparing
                            end
                        end
                        4'd14: begin
                            // Execute Comparison: temp_cand vs best_cand
                            // Lexicographical order: value at index 0 is same (path start), check index 1, etc.
                            // Actually, values before curr_len are identical. We only need to check index curr_len (which is the new value).
                            // AND subsequent values. But subsequent values are 0 or future expansions. 
                            // Since we append 1 value, the new value at index [curr_len] determines order, as future is 0.
                            // HOWEVER, if we compare paths of length > curr_len+1, we check deeper. 
                            // But we only append 1 value at a time. 
                            // So comparison boils down to: which value at index [curr_len] is smaller?
                            // If equal, we are in a tie. The prompt says "lexicographically smallest path". 
                            // If values at curr_len are equal, the one with smaller next value wins.
                            // But we don't know next value yet. 
                            // So if values at curr_len are equal, we pick the first one (or any), 
                            // because the subsequent steps will be determined by the *future* BFS which depends on the position.
                            // BUT the prompt says "always selecting the smallest next value".
                            // It implies strictly greedy per step? Or full lexicographical comparison of the generated candidate paths?
                            // "Form candidate path = current_path + new_cell_value. Select lexicographically smallest candidate path"
                            // If new_cell_values are equal, the paths are still same length. But the prompt might imply we just pick the smaller value.
                            // If values are equal, we should maybe pick based on position? Or just the first one?
                            // If we follow "Lexicographically smallest", and values are equal, we must compare the rest.
                            // Since the rest of the path is currently empty (0), they are equal.
                            // So tie-breaking is undefined. We can keep the first one.
                            // BUT: If two paths lead to same value, but different positions, the NEXT steps might differ.
                            // The prompt says "Select lexicographically smallest candidate path". 
                            // This implies comparing the *sequence* of values. 
                            // If we pick a path, we lock in the position. 
                            // If two options give value '2', we should pick the one that leads to a smaller value in the future?
                            // That is not "greedy", that is look-ahead. 
                            // The prompt "BFS-style... always selecting the smallest next value" suggests simple greedy (only look at current step). 
                            // Let's stick to: Compare value at curr_len. If smaller, update. If equal, keep current.

                            if (temp_cand[curr_len] < best_cand[curr_len]) begin
                                best_cand <= temp_cand;
                            end

                            // Move to next candidate
                            cand_idx <= cand_idx + 1;
                            step_phase <= 4'd10; // Loop back
                        end

                        4'd15: begin
                            // Update Path with Best Candidate
                            path <= best_cand;
                            // Update Position Arrays
                            // Find which neighbor corresponds to best_cand[curr_len]
                            // We can iterate through stored neighbors to find the matching value and update path_row/col
                            // Or, store the winning index.
                            // Let's just search neighbors for the value in best_cand[curr_len]
                            // Note: there could be ties. We pick the first matching neighbor.

                            // Search neighbors
                            // Use a flag to ensure we only update once per step
                            for (int n = 0; n < 4; n++) begin
                                if (n < neigh_count) begin
                                    if (neigh_val[n] == best_cand[curr_len]) begin
                                        // Check if this neighbor was the one used (in case of tie, we pick first)
                                        // To be precise with coordinates, we should really store the index of the winner in a temp reg.
                                        // But we can just update path_pos[curr_len] with the first matching neighbor.
                                        path_row[curr_len] <= neigh_row[n];
                                        path_col[curr_len] <= neigh_col[n];
                                        // Break not synthesizable in always block usually, but can be used if we ensure logic stops.
                                        // Better: overwrite if valid, but logic below will handle it if we just pick the first match.
                                        // To avoid overwriting multiple times, we can use a 'found' flag.
                                        // Since this is sequential logic, let's just use an iterative approach or helper task.
                                        // Simplification: The selection logic in phase 9-14 ensures best_cand is formed.
                                        // We need to map best_cand[curr_len] back to a coordinate.
                                        // Let's do this: Update path_row[curr_len] only if we haven't set it yet in this phase.
                                        // We can reset a 'pos_set' flag at phase 0.
                                    end
                                end
                            end

                            // Update Length
                            curr_len <= curr_len + 1;

                            // Proceed to check completion
                            next_state <= CHECK_COMPLETE;
                            step_phase <= 4'd0;
                        end
                    endcase
                end

                CHECK_COMPLETE: begin
                    if (curr_len >= k) begin
                        result <= path;
                        next_state <= DONE;
                    end else begin
                        next_state <= PROCESS_STEP;
                        step_phase <= 4'd0;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) next_state <= IDLE;
                    else next_state <= DONE;
                end
            endcase
        end
    end

    // Helper logic for duplicate check (combinational function for use in sequential block)
    function automatic logic is_in_path;
        input [1:0] r;
        input [1:0] c;
        input [1:0] p_r [0:9];
        input [1:0] p_c [0:9];
        input [3:0] len;
        logic found;
        begin
            found = 0;
            for (int i = 0; i < 10; i++) begin
                if (i < len) begin
                    if (p_r[i] == r && p_c[i] == c) found = 1;
                end
            end
            is_in_path = found;
        end
    endfunction

endmodule

module minPath (
    input clk,
    input rst_n,
    input start,
    input [1:0][1:0][7:0] grid,
    input [3:0] k,
    output reg [9:0][7:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam PROCESS = 3'b010;
    localparam CHECK = 3'b011;
    localparam FINISH = 3'b100;

    reg [2:0] state, n_state;

    // Path Storage
    reg [9:0][7:0] path;
    reg [1:0] path_r [0:9];
    reg [1:0] path_c [0:9];
    reg [3:0] length;

    // Processing Registers
    reg [3:0] phase;
    reg [1:0] nr, nc; // Temp neighbors
    reg [7:0] cand_vals [0:3];
    reg [1:0] cand_r [0:3];
    reg [1:0] cand_c [0:3];
    reg [3:0] valid_cands;
    reg [1:0] cand_count;

    reg [7:0] best_val;
    reg [1:0] best_r, best_c;

    integer i;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= n_state;
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: n_state = start ? INIT : IDLE;
            INIT: n_state = CHECK;
            PROCESS: begin
                // Step logic is split into phases. Wait for completion.
                if (phase == 4'd15) n_state = CHECK;
                else n_state = PROCESS;
            end
            CHECK: begin
                if (length >= k) n_state = FINISH;
                else n_state = PROCESS;
            end
            FINISH: n_state = start ? FINISH : IDLE; // Wait for start low to reset
            default: n_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            path <= 80'h0;
            length <= 0;
            phase <= 0;
            cand_count <= 0;
            valid_cands <= 0;
            result <= 80'h0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                end

                INIT: begin
                    // Find global minimum (1)
                    // Scan grid (0,0), (0,1), (1,0), (1,1)
                    if (grid[0][0] == 8'd1) begin path[0] <= 8'd1; path_r[0] <= 0; path_c[0] <= 0; end
                    else if (grid[0][1] == 8'd1) begin path[0] <= 8'd1; path_r[0] <= 0; path_c[0] <= 1; end
                    else if (grid[1][0] == 8'd1) begin path[0] <= 8'd1; path_r[0] <= 1; path_c[0] <= 0; end
                    else begin path[0] <= 8'd1; path_r[0] <= 1; path_c[0] <= 1; end
                    length <= 1;
                    phase <= 0;
                end

                PROCESS: begin
                    case (phase)
                        // Phase 0: Reset
                        0: begin
                            cand_count <= 0;
                            valid_cands <= 0;
                            phase <= 1;
                        end

                        // Phase 1-4: Evaluate Neighbors (Right, Left, Down, Up)
                        // We use sub-phases to ensure timing budget (approx 1 cycle per check)
                        // Actually, we need to check bounds, check uniqueness, and store.

                        // Right (Row, Col+1)
                        1: begin nr <= path_r[length-1]; nc <= path_c[length-1] + 1; phase <= 2;
                        2: if (nc < 2 && !is_dup(nr, nc)) add_cand(); phase <= 3;

                        // Left (Row, Col-1)
                        3: begin nr <= path_r[length-1]; nc <= path_c[length-1] - 1; phase <= 4;
                        4: if (nc < 2 && path_c[length-1] != 0 && !is_dup(nr, nc)) add_cand(); phase <= 5;

                        // Down (Row+1, Col)
                        5: begin nr <= path_r[length-1] + 1; nc <= path_c[length-1]; phase <= 6;
                        6: if (nr < 2 && !is_dup(nr, nc)) add_cand(); phase <= 7;

                        // Up (Row-1, Col)
                        7: begin nr <= path_r[length-1] - 1; nc <= path_c[length-1]; phase <= 8;
                        8: if (nr < 2 && path_r[length-1] != 0 && !is_dup(nr, nc)) add_cand(); phase <= 9;

                        // Phase 9: Start Selection
                        9: begin
                            if (cand_count > 0) begin
                                best_val <= cand_vals[0];
                                best_r <= cand_r[0];
                                best_c <= cand_c[0];
                                i <= 1; // index for loop
                                phase <= 10;
                            end else begin
                                // No moves? Should not happen in 2x2, but fail safe
                                phase <= 15;
                            end
                        end

                        // Phase 10-13: Compare
                        10, 11, 12, 13: begin
                            if (i < cand_count) begin
                                if (cand_vals[i] < best_val) begin
                                    best_val <= cand_vals[i];
                                    best_r <= cand_r[i];
                                    best_c <= cand_c[i];
                                end else if (cand_vals[i] == best_val) begin
                                    // Tie: Pick first one (keep current best)
                                    // Or implement position tie-breaker if required, but spec says "smallest value"
                                    // Assuming strict value comparison.
                                end
                                i <= i + 1;
                            end else begin
                                phase <= 14;
                            end
                        end

                        // Phase 14: Update Path
                        14: begin
                            path[length] <= best_val;
                            path_r[length] <= best_r;
                            path_c[length] <= best_c;
                            length <= length + 1;
                            phase <= 15;
                        end

                        // Phase 15: Done with step
                        15: begin
                            // Wait for state transition
                        end
                    endcase
                end

                CHECK: begin
                    if (length >= k) begin
                        result <= path;
                        done <= 1;
                    end
                end

                FINISH: begin
                    // Output already set, done is high
                end
            endcase
        end
    end

    // Helper task to add candidate
    task add_cand;
        begin
            if (cand_count < 4) begin
                cand_vals[cand_count] <= grid[nr][nc];
                cand_r[cand_count] <= nr;
                cand_c[cand_count] <= nc;
                cand_count <= cand_count + 1;
            end
        end
    endtask

    // Helper function to check duplicates in current path
    function automatic logic is_dup(input [1:0] r, input [1:0] c);
        logic dup;
        dup = 0;
        for (int k = 0; k < 10; k++) begin
            if (k < length && path_r[k] == r && path_c[k] == c) dup = 1;
        end
        return dup;
    endfunction

endmodule