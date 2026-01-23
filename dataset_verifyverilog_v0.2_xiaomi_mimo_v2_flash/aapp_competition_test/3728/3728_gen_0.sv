module table_sorter (
    input clk,
    input rst_n,
    input start,
    input [2:0] row_idx,
    input [7:0] col_val_0, col_val_1, col_val_2, col_val_3,
               col_val_4, col_val_5, col_val_6, col_val_7,
    output reg result,
    output reg done
);

    // Parameters
    parameter ROWS = 4;
    parameter COLS = 8;
    parameter IDENTITY_0 = 8'h01;
    parameter IDENTITY_1 = 8'h02;
    parameter IDENTITY_2 = 8'h03;
    parameter IDENTITY_3 = 8'h04;
    parameter IDENTITY_4 = 8'h05;
    parameter IDENTITY_5 = 8'h06;
    parameter IDENTITY_6 = 8'h07;
    parameter IDENTITY_7 = 8'h08;

    // State definition
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam PROCESS = 3'b010;
    localparam CHECK_ROW = 3'b011;
    localparam DONE_STATE = 3'b100;

    // Memory storage (1 bit per element since values are 1-8)
    reg table [0:3][0:7];
    
    // Registers for state machine
    reg [2:0] current_state, next_state;
    
    // Process registers
    reg [3:0] c1, c2;            // Column pair iterators
    reg [3:0] r;                 // Row iterator
    reg [2:0] mismatches;        // Count of mismatches in current row
    reg [3:0] col_iter;          // Column iterator for row check
    reg current_pair_valid;      // Flag if current (c1,c2) pair is valid
    reg found_solution;          // Final result flag
    
    // Temporary registers for values
    reg val_a, val_b;            // Values at swapped positions
    reg target_a, target_b;      // Target values at swapped positions
    reg mismatch_detected;       // Flag for single mismatch check

    // State transition and control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            
            // Update result only in DONE state
            if (current_state == DONE_STATE) begin
                result <= found_solution;
                done <= 1'b1;
            end else if (current_state == IDLE && start) begin
                done <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            
            LOAD: begin
                // Check if all rows are loaded (row_idx reaches max or specific load complete logic)
                // Here we assume external control drives row_idx, we just latch data.
                // Transition to PROCESS when start is asserted (handled in IDLE) or implicitly.
                // Since we don't have a 'load_done' signal, we rely on the fact that
                // the testbench will hold start and provide row data. 
                // We will transition to PROCESS if start drops or after a delay.
                // However, to stick to spec: "Upon 'start' being high, it iterates..."
                // This implies loading happens first. Let's define internal load counter.
                // But spec says "streaming input via row_idx". 
                // We will simply transition to PROCESS when 'start' is high but we assume loading is done.
                // To make it robust, let's say we transition immediately to PROCESS from IDLE on start.
                // But we need to capture data. 
                // Let's refine: IDLE waits for start. On start, we go to PROCESS.
                // We sample inputs at the transition LOAD -> PROCESS or continuously.
                // Given the instructions, let's assume the sequence is:
                // 1. Put data on bus, toggle start.
                // 2. FSM transitions IDLE -> PROCESS.
                // 3. We use row_idx to index the memory write.
                // Wait, the inputs are streaming. So LOAD state is needed.
                // Let's say LOAD state lasts 4 cycles (one per row).
                // Or, simpler: The 'start' pulse initiates the process. 
                // We will just latch data whenever 'start' is high and row_idx changes.
                // Actually, let's create a logic that iterates internally for loading if we can't rely on streaming easily.
                // However, "streaming input via row_idx and col_val_X ports" is explicit.
                // Let's assume we are in IDLE, we see start, we go to LOAD.
                // In LOAD, we wait for 4 cycles (detect row_idx changes) or just latch continuously.
                // To keep it simple and robust: 
                // We will use a 'load_done' counter internally.
                // Transition IDLE -> LOAD on start.
                // Transition LOAD -> PROCESS when all 4 rows latched.
                next_state = LOAD; 
            end
            
            LOAD: begin
                // We need to detect when all rows are loaded. 
                // Since we don't have a ready signal, we might need to wait a fixed time or assume inputs are ready.
                // Let's use a simple counter: 4 cycles.
                if (load_counter == 3'd4) next_state = PROCESS;
                else next_state = LOAD;
            end

            PROCESS: begin
                // We need to check the pair (c1, c2).
                // If we are done checking this pair (check_complete), we need to see if it was valid.
                // If valid, we go to DONE. If not, increment pair.
                // The row checking logic is separate. 
                // We will use a sub-state or flag to handle row checking.
                // Let's go to CHECK_ROW to verify the current (c1, c2) pair.
                next_state = CHECK_ROW;
            end

            CHECK_ROW: begin
                // Check current row 'r'.
                // If row fails (mismatches > 2 or >1 swap logic), 
                // we need to break and try next pair.
                // If row passes (check done), move to next row.
                // If all rows pass, go to DONE (success).
                // 
                // Logic inside CHECK_ROW:
                // If row check done:
                //    If row valid:
                //       If r == 3: Success -> DONE
                //       Else: r++, go back to CHECK_ROW (next row)
                //    Else: (row invalid) -> go to PROCESS (next pair)
                // We handle this in combinational logic below.
            end

            DONE_STATE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Data Path Logic (Sequential for counters, Combinational for comparisons)
    reg [2:0] load_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_counter <= 3'd0;
            c1 <= 4'd0;
            c2 <= 4'd0;
            r <= 3'd0;
            found_solution <= 1'b0;
            mismatches <= 3'd0;
        end else begin
            // Load Logic
            if (current_state == IDLE && start) begin
                load_counter <= 3'd0;
            end else if (current_state == LOAD) begin
                // Latch data based on row_idx
                // Note: row_idx is input. We latch when counter matches row_idx or just latch all.
                // To be robust with streaming, we just latch the inputs into the memory array.
                // We assume row_idx increments or is provided for each row.
                // We will increment a counter each cycle to ensure we cover all rows.
                // Or better: check if we haven't latched this row_idx yet.
                // Simple approach: Assume row_idx is 0, then 1, then 2, then 3 sequentially.
                // If we are in LOAD state, we write the inputs to table[row_idx].
                // We count up to 4.
                
                // Let's latch the data:
                table[row_idx][0] <= col_val_0[0];
                table[row_idx][1] <= col_val_1[0];
                table[row_idx][2] <= col_val_2[0];
                table[row_idx][3] <= col_val_3[0];
                table[row_idx][4] <= col_val_4[0];
                table[row_idx][5] <= col_val_5[0];
                table[row_idx][6] <= col_val_6[0];
                table[row_idx][7] <= col_val_7[0];

                // Counting rows loaded. 
                // We need to ensure we count each unique row index or just fixed cycles.
                // Given it's a simulation/streaming, let's just wait 4 cycles.
                if (load_counter < 3'd4)
                    load_counter <= load_counter + 1'b1;
            end

            // Processing Logic
            if (current_state == PROCESS) begin
                r <= 3'd0; // Start checking from row 0
            end

            if (current_state == CHECK_ROW) begin
                // This state is effectively a cycle where we evaluate the current row for current (c1,c2).
                // Evaluation Logic (below in combinational block) determines:
                // 1. Is this row valid for (c1,c2)?
                // 2. Are we done with all rows (and valid)?
                
                // We handle row iterator increment here based on valid result
                // But wait, the transition logic needs to know if we are done with the row.
                // Let's do the heavy lifting in a combinational block that sets 'row_valid' and 'check_done'.
            end
            
            // Pair Iterator Logic
            if (current_state == PROCESS) begin
                c1 <= 0;
                c2 <= 0;
                found_solution <= 1'b0;
            end else if (current_state == CHECK_ROW && pair_transition) begin
                // Increment pair (c1, c2)
                if (c2 < 4'd7) begin
                    c2 <= c2 + 1'b1;
                end else begin
                    c2 <= c1 + 1'b1;
                    if (c1 < 4'd6) begin
                        c1 <= c1 + 1'b1;
                    end else begin
                        // Exhausted all pairs
                        // Go to DONE
                    end
                end
                r <= 3'd0; // Reset row counter for new pair
            end
            
            // Row Iterator Logic
            if (current_state == CHECK_ROW && !pair_transition && !all_done) begin
                r <= r + 1'b1;
            end
            
            // Success Flag
            if (current_state == CHECK_ROW && all_done && row_valid) begin
                found_solution <= 1'b1;
            end
        end
    end

    // --- Combinational Logic for Row Validation and State Transitions ---
    
    reg row_valid;
    reg pair_transition; // Flag to move to next pair
    reg all_done;        // Flag that we checked all rows for this pair
    reg [3:0] c1_t, c2_t; // Helper for combinational lookup
    
    always @(*) begin
        // Default values
        row_valid = 1'b0;
        pair_transition = 1'b0;
        all_done = 1'b0;
        
        // We need to compute the validity of the current row 'r' under the swap (c1, c2)
        // Since we are in CHECK_ROW state, we look at table[r][*].
        
        // Values in row r after swap:
        // For col j:
        //   if j == c1, val = table[r][c2]
        //   if j == c2, val = table[r][c1]
        //   else val = table[r][j]
        
        // Identity values: 1..8 (binary 0001..1000)
        // Check "differs from identity by at most 2 elements". 
        // Interpretation: Hamming distance <= 2 (0 or 1 swaps needed).
        // Wait, "by at most 2 elements" could mean Hamming distance <= 2.
        // "0 or 1 swap within the row is needed" means we can fix the row with one swap?
        // No, the text says: "differs from the identity [1,2,3,4,5,6,7,8] by at most 2 elements".
        // This implies Hamming distance <= 2.
        // Let's check: Identity [1,2,3,4]. Row [1,2,4,3]. Differs by 2 elements (3 and 4). One swap fixes it.
        // Row [1,3,2,4]. Differs by 2 elements. One swap fixes it.
        // Row [1,2,3,5]. Differs by 1 element (4 vs 5). One swap (with 4) fixes it.
        // Row [2,1,3,4]. Differs by 2 elements. One swap fixes it.
        // So yes, Hamming distance <= 2 is the correct logic.
        
        // Let's compute mismatches for the current row r.
        // To save logic, we can unroll or use a loop, but Verilog for synthesis is tricky with complex loops.
        // We will do a bit-wise comparison.
        // However, we need to account for the column swap (c1, c2).
        
        // Let's define the swapped columns indices for clarity.
        // Note: c1 and c2 are indices 0..7.
        
        // We need to count how many j in 0..7 satisfy: SwappedValue(j) != (j+1).
        
        // Implementation strategy: 
        // Since we have 8 columns, we can do a long case statement or generate block logic.
        // But we need to handle the swap dynamic c1, c2.
        // We can read the values dynamically.
        
        // Let's use a loop for synthesis. Modern synthesis tools handle this fine for small fixed counts.
        // But to be safe and explicit:
        
        reg [3:0] mismatch_count;
        mismatch_count = 0;
        
        // We iterate j from 0 to 7
        // Note: Using a for-loop in combinational block is standard for synthesis.
        integer j;
        reg [3:0] val;
        reg [3:0] target;
        
        for (j = 0; j < 8; j = j + 1) begin
            // Determine value at column j after swap
            if (j == c1) val = table[r][c2];
            else if (j == c2) val = table[r][c1];
            else val = table[r][j];
            
            // Determine target value at column j
            target = j + 1;
            
            if (val != target) mismatch_count = mismatch_count + 1'b1;
        end
        
        if (mismatch_count <= 2) row_valid = 1'b1;
        
        // Determine if we are done with all rows (0, 1, 2, 3)
        if (r == 3'd3) all_done = 1'b1;
        else all_done = 1'b0;
        
        // State transition logic based on validation
        if (current_state == CHECK_ROW) begin
            if (row_valid) begin
                if (all_done) begin
                    // Found a valid pair that works for ALL rows
                    // Go to DONE state
                    // We set transition signals.
                    // Since the FSM logic needs to know this, we might need to drive next_state directly here
                    // or use flags handled in the sequential block.
                    // Let's use flags to control the sequential block.
                    // But the question asks for a state machine.
                    // Let's refine the state machine logic:
                    // In CHECK_ROW state (at posedge clk):
                    // If current row is valid:
                    //   if last row: -> DONE
                    //   else: r++, stay in CHECK_ROW (or go back to PROCESS to trigger next row?)
                    // If invalid: -> PROCESS (next pair)
                    
                    // Wait, we are in CHECK_ROW state. This implies we just finished checking the row (or are checking it).
                    // Let's assume CHECK_ROW is a transient state or the state we enter to check a row.
                    // We will use the combinational output to determine the next state directly inside the FSM block.
                    // But the instructions said "Use a state machine: IDLE, LOAD, PROCESS, DONE".
                    // It didn't forbid extra states. However, sticking to 4 is better.
                    
                    // Let's re-interpret the state machine:
                    // IDLE: Wait
                    // LOAD: Fill memory (4 cycles)
                    // PROCESS: The heavy lifter. This state iterates pairs and rows.
                    //          It will take many cycles.
                    //          Inside PROCESS, we need logic to:
                    //          1. Check current (c1,c2) and current row.
                    //          2. If valid, go to next row (check again).
                    //          3. If invalid, go to next pair.
                    //          4. If all rows valid, go to DONE.
                    //          5. If all pairs exhausted, go to DONE (result 0).
                    // 
                    // To implement this in 4 states, the PROCESS state must be a complex logic block.
                    // Or, we can add sub-states within PROCESS using registers.
                    // Let's stick to 4 states and use the combinational block to control iteration within PROCESS.
                    
                    // Revised Plan for PROCESS state:
                    // In PROCESS, we effectively perform one "step" of the search per clock cycle.
                    // Step 1: Check row 'r' for pair (c1, c2).
                    // Step 2: If row OK:
                    //         - If r < 3, r++, stay in PROCESS.
                    //         - If r == 3, Success -> DONE.
                    // Step 3: If row NOT OK:
                    //         - Reset r=0, increment pair (c1,c2).
                    //         - If pair exhausted, -> DONE (fail).
                    //         - Else stay in PROCESS.
                    
                    // This requires the PROCESS state to handle both checking and updating.
                    // Let's refine the combinational block for the PROCESS state transition.
                end
            end
        end
    end

    // --- Re-implementing FSM Logic for Synthesis ---
    // The previous mixed logic was getting complex. Let's clean it up.
    
    // We will use a slightly expanded state machine or just use the PROCESS state with
    // a counter to handle the "cycles".
    // Given the "at most 1024 cycles" constraint, we have plenty of time.
    // Total checks: 36 pairs * 4 rows = 144 checks. Plus overhead. 
    // We can take 1 cycle per row check.
    // So we need to iterate through states. 
    // Let's allow internal state tracking inside the PROCESS state.
    
    // Registers for iteration (moved to top level for clarity)
    // c1, c2, r are defined.
    reg processing_done; // Internal flag for process completion

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            load_counter <= 3'd0;
            c1 <= 4'd0;
            c2 <= 4'd0;
            r <= 3'd0;
            found_solution <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        current_state <= LOAD;
                        load_counter <= 3'd0;
                        done <= 1'b0;
                    end
                end

                LOAD: begin
                    // Latch inputs into memory based on row_idx
                    // We assume row_idx is valid in this cycle.
                    // We only need to latch once per row. 
                    // To handle streaming: we write whenever row_idx changes or counter increments.
                    // Let's latch the inputs into table[row_idx] in this state.
                    // We increment counter to track progress.
                    
                    table[row_idx][0] <= col_val_0[0];
                    table[row_idx][1] <= col_val_1[0];
                    table[row_idx][2] <= col_val_2[0];
                    table[row_idx][3] <= col_val_3[0];
                    table[row_idx][4] <= col_val_4[0];
                    table[row_idx][5] <= col_val_5[0];
                    table[row_idx][6] <= col_val_6[0];
                    table[row_idx][7] <= col_val_7[0];

                    if (load_counter < 3'd4) begin
                        load_counter <= load_counter + 1'b1;
                    end else begin
                        // We assume 4 cycles have passed, or we have seen all rows.
                        // Moving to PROCESS.
                        current_state <= PROCESS;
                        c1 <= 4'd0;
                        c2 <= 4'd0;
                        r <= 3'd0;
                        found_solution <= 1'b0;
                    end
                end

                PROCESS: begin
                    // In this state, we perform the check for the current (c1, c2) and current row r.
                    // We need to calculate if the current row is valid under the current swap.
                    // Since combinational logic for validation might be large, we do it here or in a helper block.
                    // Let's calculate mismatches using combinational logic derived from table.
                    // We can use the 'row_valid' signal calculated combinationally.
                    
                    if (row_valid) begin
                        // If row is valid, check next row or finish
                        if (r == 3'd3) begin
                            // All rows passed for (c1, c2)
                            current_state <= DONE_STATE;
                            result <= 1'b1;
                            done <= 1'b1;
                        end else begin
                            r <= r + 1'b1; // Move to next row, stay in PROCESS
                        end
                    end else begin
                        // Row invalid, try next column pair
                        // Increment (c1, c2)
                        if (c2 < 4'd7) begin
                            c2 <= c2 + 1'b1;
                        end else begin
                            c2 <= c1 + 1'b1;
                            if (c1 < 4'd6) begin
                                c1 <= c1 + 1'b1;
                            end else begin
                                // All pairs exhausted, no solution
                                current_state <= DONE_STATE;
                                result <= 1'b0;
                                done <= 1'b1;
                            end
                        end
                        r <= 3'd0; // Reset row counter for new pair
                    end
                end

                DONE_STATE: begin
                    // Wait for start to go low (or just transition to IDLE)
                    if (!start) current_state <= IDLE;
                end
                
                default: current_state <= IDLE;
            endcase
        end
    end

    // Combinational Logic for Row Validation (Used in PROCESS state)
    // This block calculates 'row_valid' based on current (c1, c2) and r.
    always @(*) begin
        reg [3:0] val;
        reg [3:0] target;
        reg [3:0] mismatches;
        integer j;
        
        mismatches = 0;
        
        for (j = 0; j < 8; j = j + 1) begin
            // Determine value at column j after swap (c1, c2)
            if (j == c1) val = table[r][c2];
            else if (j == c2) val = table[r][c1];
            else val = table[r][j];
            
            target = j + 1; // Identity value for column j
            
            if (val != target) mismatches = mismatches + 1'b1;
        end
        
        // Condition: differs by at most 2 elements (Hamming distance <= 2)
        row_valid = (mismatches <= 2);
    end

endmodule
