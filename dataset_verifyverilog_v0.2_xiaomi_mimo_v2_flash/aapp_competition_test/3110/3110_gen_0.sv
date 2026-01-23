module code_cracker (
    input clk,
    input rst_n,
    input start,
    input [3:0] row_addr,
    input [3:0] col_addr,
    input [3:0] data_in,
    input load_en,
    output reg [15:0] count,
    output reg done
);

    // State Encodings
    localparam IDLE = 4'b0000;
    localparam LOAD = 4'b0001;
    localparam FIND = 4'b0010;
    localparam SEARCH = 4'b0011;
    localparam CHECK = 4'b0100;
    localparam BACKTRACK = 4'b0101;
    localparam DONE = 4'b0110;
    localparam UPDATE = 4'b0111;

    // Grid Storage: 4x4 array of 4-bit values (0-9)
    reg [3:0] grid [3:0][3:0];
    
    // Stack for backtracking: Stores the value assigned to each unknown position
    // Index 0 is the first unknown found.
    reg [3:0] stack [7:0];
    
    // Unknown Positions: Store coordinates of zeros
    reg [3:0] zero_row [7:0];
    reg [3:0] zero_col [7:0];
    
    // Registers for state machine and counters
    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] row_idx;
    reg [3:0] col_idx;
    reg [3:0] search_digit;
    reg [3:0] zero_count;
    reg [3:0] current_zero_idx;
    
    // Control signals
    reg grid_loaded;
    reg pop_stack;
    reg push_stack;
    
    // Variables for L-Shape check calculation
    reg [3:0] l_val, u_val, r_val;
    reg [3:0] div_result;
    reg [3:0] div_remainder;
    reg valid_op;

    integer i, j;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: begin
                if (!load_en && grid_loaded) next_state = FIND;
                else next_state = LOAD;
            end
            FIND: begin
                // Wait one cycle to latch zero_count
                next_state = SEARCH;
            end
            SEARCH: begin
                if (zero_count == 0) begin
                    // No unknowns, just check the grid once
                    next_state = CHECK;
                end else if (current_zero_idx >= zero_count) begin
                    // All filled, validate
                    next_state = CHECK;
                end else begin
                    // Try to assign digit to current zero
                    next_state = CHECK;
                end
            end
            CHECK: begin
                if (search_digit > 9) begin
                    // Tried all digits, backtrack
                    next_state = BACKTRACK;
                end else if (zero_count == 0) begin
                    // Grid was fully known from start
                    next_state = DONE; // Or update if we handled it, but no unknowns to iterate
                end else if (valid_op) begin
                    // Constraint passed, check if full grid is filled (and valid)
                    // If current_zero_idx + 1 == zero_count, we are done with this branch
                    if (current_zero_idx + 1 == zero_count) begin
                        next_state = UPDATE; // Valid full solution found
                    end else begin
                        next_state = SEARCH; // Go to next zero
                    end
                end else begin
                    // Invalid, try next digit
                    next_state = SEARCH;
                end
            end
            UPDATE: begin
                // Move to next zero or done
                next_state = SEARCH; 
            end
            BACKTRACK: begin
                if (current_zero_idx == 0 && search_digit > 9) begin
                    // Backtracked past the start
                    next_state = DONE;
                end else begin
                    next_state = SEARCH;
                end
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 16'd0;
            done <= 1'b0;
            grid_loaded <= 1'b0;
            zero_count <= 4'd0;
            current_zero_idx <= 4'd0;
            search_digit <= 4'd0;
            // Initialize grid to 0
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    grid[i][j] <= 4'd0;
                end
            end
            // Initialize stack
            for (i = 0; i < 8; i = i + 1) begin
                stack[i] <= 4'd0;
                zero_row[i] <= 4'd0;
                zero_col[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 16'd0;
                    grid_loaded <= 1'b0;
                end
                
                LOAD: begin
                    if (load_en) begin
                        if (row_addr < 4 && col_addr < 4) begin
                            grid[row_addr][col_addr] <= data_in;
                        end
                    end else begin
                        grid_loaded <= 1'b1;
                    end
                end
                
                FIND: begin
                    // Scan grid to find zeros and store their positions
                    zero_count <= 4'd0;
                    // We use a sequential scan approach via index registers (row_idx, col_idx) initialized in SEARCH transition or here
                    // To keep it simple, let's assume we do it in one cycle with generated logic if small, 
                    // but here we'll iterate in SEARCH state for simplicity or use a separate block.
                    // Let's use row_idx/col_idx to scan. Reset them here.
                    row_idx <= 4'd0;
                    col_idx <= 4'd0;
                    current_zero_idx <= 4'd0;
                end
                
                SEARCH: begin
                    // State to handle the scanning and stack management
                    
                    // Part 1: Populating the stack (if we just did FIND)
                    if (state != $past(state) && state == SEARCH && $past(state) == FIND) begin
                        // This logic handles the sequential scan for FIND if we wanted to be super cycle accurate.
                        // Instead, we will do the scan here during SEARCH if zero_count is 0 and grid has zeros.
                    end
                    
                    // Logic for FIND scan simulation (executed once when entering from FIND)
                    if (state == SEARCH && $past(state) == FIND) begin
                        // Manual scan using row_idx/col_idx initialized in FIND
                        // We iterate through grid here to populate zero_row/zero_col
                        if (grid[row_idx][col_idx] == 4'd0) begin
                            zero_row[zero_count] <= row_idx;
                            zero_col[zero_count] <= col_idx;
                            zero_count <= zero_count + 1;
                        end
                        if (col_idx < 3) col_idx <= col_idx + 1;
                        else begin
                            col_idx <= 0;
                            if (row_idx < 3) row_idx <= row_idx + 1;
                        end
                    end
                    
                    // Logic for moving to next zero or popping
                    else if (state == SEARCH && $past(state) != FIND) begin
                        if (pop_stack) begin
                            // We are backtracking, stack pop is handled by logic below
                            // Search digit starts from previous + 1, but that is handled in BACKTRACK state logic below
                            // Actually, we should increment search_digit in SEARCH if we just popped or are testing next digit
                        end else if (push_stack) begin
                            // Logic handled in CHECK -> UPDATE transition usually, or here
                        end
                    end
                    
                    // Logic to initialize search for a specific zero index
                    if ($past(state) == CHECK && $past(search_digit) > 9) begin
                         // We failed all digits, go to backtrack state to handle popping
                    end else if ($past(state) == CHECK && $past(valid_op)) begin
                         // Passed, but we handle the push in CHECK or UPDATE. 
                         // If we are moving to next zero, reset digit to 1.
                         if (current_zero_idx < zero_count - 1) begin // Should be logic in state transition
                             search_digit <= 4'd1; 
                         end
                    end else if ($past(state) == UPDATE) begin
                        // We successfully placed a digit and counted a solution (or full partial valid).
                        // But wait, if it's a full solution, we need to backtrack to find others.
                        // Or if it's just partial, we continue.
                        // The problem asks for number of valid complete codes.
                        // If we found a full solution (current_zero_idx == zero_count-1), we must backtrack to find next one.
                        // Or continue if we are in the middle.
                        // Let's handle stack pushing here.
                        
                        // If full solution found:
                        if (current_zero_idx == zero_count - 1) begin
                            // Pop stack to try next digit for last cell
                            pop_stack <= 1'b1;
                            current_zero_idx <= current_zero_idx - 1;
                            // Get previous digit to increment
                            // We need to get the previous digit from stack
                        end else begin
                            // Partial valid, move to next zero
                            current_zero_idx <= current_zero_idx + 1;
                            search_digit <= 4'd1; // Start from 1 for next zero
                            push_stack <= 1'b1;
                        end
                    end else if ($past(state) == BACKTRACK) begin
                         // Decrement index
                         if (current_zero_idx > 0) current_zero_idx <= current_zero_idx - 1;
                         // Increment search digit for the cell we just backtracked to
                         // We need to read the value from stack to know what to increment from
                    end
                end

                FIND: begin
                   // Clear counters
                   zero_count <= 4'd0;
                   row_idx <= 4'd0;
                   col_idx <= 4'd0;
                end
                
                SEARCH: begin
                    // Handling the scanning of zeros
                    if ($past(state) == FIND) begin
                        // We are scanning sequentially (simpler than parallel block)
                        if (grid[row_idx][col_idx] == 4'd0) begin
                            zero_row[zero_count] <= row_idx;
                            zero_col[zero_count] <= col_idx;
                            zero_count <= zero_count + 1;
                        end
                        if (col_idx < 3) col_idx <= col_idx + 1;
                        else begin
                            col_idx <= 0;
                            if (row_idx < 3) row_idx <= row_idx + 1;
                        end
                    end
                    else if ($past(state) == UPDATE || $past(state) == BACKTRACK || ($past(state) == CHECK && $past(search_digit) > 9)) begin
                        // Logic to adjust current_zero_idx and search_digit based on backtrack or success
                        
                        // Case: Returned from BACKTRACK state
                        if ($past(state) == BACKTRACK) begin
                             // We are now at a lower index, we need to increment the digit for this index
                             // Read current value from stack
                             search_digit <= stack[current_zero_idx] + 1;
                        end
                        // Case: Returned from UPDATE (found a valid full solution or partial)
                        else if ($past(state) == UPDATE) begin
                             if (current_zero_idx == zero_count - 1) begin
                                 // Just found full solution. Backtrack from this position.
                                 // The UPDATE state should have handled decrementing current_zero_idx and popping stack.
                                 // Wait, let's move that logic here for cleaner code.
                                 
                                 // Actually, let's simplify:
                                 // UPDATE sets push_stack = 1 or pop_stack = 1.
                             end
                        end
                        // Case: Returned from CHECK (failure > 9)
                        else if ($past(search_digit) > 9) begin
                            // We exhausted digits at current_zero_idx.
                            // Need to backtrack.
                            // This transition should go to BACKTRACK state.
                        end
                    end
                    
                    // Refined Stack Logic in SEARCH
                    if ($past(state) == CHECK && $past(valid_op)) begin
                        // Valid digit found
                        stack[current_zero_idx] <= $past(search_digit); // Save digit
                        grid[zero_row[current_zero_idx]][zero_col[current_zero_idx]] <= $past(search_digit);
                        
                        if (current_zero_idx == zero_count - 1) begin
                            // Full grid valid solution found
                            count <= count + 1;
                            // Prepare to backtrack
                            current_zero_idx <= current_zero_idx - 1;
                            pop_stack <= 1'b1;
                            search_digit <= stack[current_zero_idx] + 1; // Will be used after pop
                            // Note: stack pop happens physically by reading 'current_zero_idx - 1' next cycle
                            // But we need to clear the cell we are leaving
                            grid[zero_row[current_zero_idx]][zero_col[current_zero_idx]] <= 4'd0;
                        end else begin
                            // Partial valid, go deeper
                            current_zero_idx <= current_zero_idx + 1;
                            search_digit <= 4'd1;
                        end
                    end
                    else if ($past(state) == CHECK && $past(search_digit) > 9) begin
                        // Failed all digits at current index
                        // Go to BACKTRACK state to handle logic
                        // (Handled by state transition)
                    end
                    else if ($past(state) == BACKTRACK) begin
                        // We popped, now we are at previous index.
                        // Search digit was set to stack[index] + 1 by logic in BACKTRACK state (or here).
                        // Let's ensure logic is sound.
                        // grid[prev_pos] is cleared by BACKTRACK logic.
                        // search_digit is already incremented.
                    end
                end
                
                CHECK: begin
                    // Assume search_digit is set by SEARCH state or previous CHECK cycle
                    // Perform constraints
                    // Note: This is complex logic. It might be better to compute 'valid_op' combinationally,
                    // but since we are in sequential block, we calculate 'valid_op' for the *next* state.
                    // However, we need to check the digit 'search_digit' against the current grid state.
                    
                    // This block is a stub for calculation if done sequentially.
                    // Actually, it's better to move the constraint check to combinational logic.
                end
                
                BACKTRACK: begin
                    // Clear current cell
                    grid[zero_row[current_zero_idx]][zero_col[current_zero_idx]] <= 4'd0;
                    
                    if (current_zero_idx == 0) begin
                        // Done
                    end else begin
                        // Decrement index
                        current_zero_idx <= current_zero_idx - 1;
                        // Retrieve previous value to increment
                        search_digit <= stack[current_zero_idx - 1] + 1;
                    end
                end
                
                UPDATE: begin
                    // Not strictly needed as logic moved to SEARCH, but good for safety
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Constraint Checker
    always @(*) begin
        valid_op = 0;
        div_result = 0;
        div_remainder = 0;
        
        // We validate 'search_digit' for 'current_zero_idx'
        // Get coordinates
        // If state is IDLE/LOAD/FIND, valid_op is don't care
        
        // Basic bounds check
        if (search_digit < 1 || search_digit > 9) begin
            valid_op = 0;
        end else begin
            
            // 1. Row Uniqueness Check
            // Check if search_digit exists in row zero_row[current_zero_idx] (excluding current col)
            if (grid[zero_row[current_zero_idx]][0] == search_digit && zero_col[current_zero_idx] != 0) valid_op = 0;
            else if (grid[zero_row[current_zero_idx]][1] == search_digit && zero_col[current_zero_idx] != 1) valid_op = 0;
            else if (grid[zero_row[current_zero_idx]][2] == search_digit && zero_col[current_zero_idx] != 2) valid_op = 0;
            else if (grid[zero_row[current_zero_idx]][3] == search_digit && zero_col[current_zero_idx] != 3) valid_op = 0;
            else begin
                // Row unique passed
                valid_op = 1; // Tentatively true
                
                // 2. L-Shape Rule Check
                // Only if the position is not in top row (row > 0) and not in rightmost col (col < 3)
                if (zero_row[current_zero_idx] > 0 && zero_col[current_zero_idx] < 3) begin
                    // We need to check against values that are *already* in the grid.
                    // l = current value (search_digit)
                    // u = value at (row-1, col)
                    // r = value at (row, col+1)
                    
                    // We must verify that u and r are NOT zeros (are filled).
                    // If they are zeros, we cannot verify the rule yet.
                    // WAIT: The problem says "For (i,j) not in top row or rightmost column".
                    // If u or r are unknown, we can't fail the check yet. We should skip the L-check if dependencies are unknown.
                    // OR, maybe we only check L-shape if U and R are known.
                    // Let's assume we only validate if U and R are non-zero.
                    
                    if (grid[zero_row[current_zero_idx] - 1][zero_col[current_zero_idx]] != 0 && 
                        grid[zero_row[current_zero_idx]][zero_col[current_zero_idx] + 1] != 0) begin
                        
                        l_val = search_digit;
                        u_val = grid[zero_row[current_zero_idx] - 1][zero_col[current_zero_idx]];
                        r_val = grid[zero_row[current_zero_idx]][zero_col[current_zero_idx] + 1];
                        
                        // Check conditions
                        // u == l*r OR u == l+r OR u == |l-r| OR u == l/r (integer) OR u == r/l (integer)
                        
                        if (u_val == l_val * r_val) valid_op = 1;
                        else if (u_val == l_val + r_val) valid_op = 1;
                        else if (u_val > l_val && u_val == l_val - r_val) valid_op = 1; // Unsigned subtraction, usually 0-9
                        else if (u_val > r_val && u_val == r_val - l_val) valid_op = 1; // Order matters for absolute diff in simple algebra, or use > check
                        else if (l_val != 0 && r_val != 0 && (l_val % r_val == 0) && u_val == l_val / r_val) valid_op = 1;
                        else if (l_val != 0 && r_val != 0 && (r_val % l_val == 0) && u_val == r_val / l_val) valid_op = 1;
                        else valid_op = 0;
                    end else begin
                        // Dependencies unknown, we accept the move tentatively
                        valid_op = 1;
                    end
                end
            end
        end
    end

    // State Transition Logic refinement for FIND->SEARCH and UPDATE->SEARCH
    // We need to handle the iteration of the FIND scan specifically.
    // The block in ALWAYS(posedge) handles the accumulation, but we need a trigger to stop.
    
    // Re-defining the Search Loop Logic slightly to ensure robustness:
    // When in SEARCH state and zero_count is not fully populated (scanning phase):
    // We scan until row_idx == 4.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == FIND) begin
                row_idx <= 0;
                col_idx <= 0;
                zero_count <= 0;
            end
            
            // Handle the Scan Phase of SEARCH (if we came from FIND)
            // Note: This logic creates a multi-cycle scan. 
            // If row_idx < 4, we are scanning.
            if (state == SEARCH && $past(state) == FIND && row_idx < 4) begin
                if (grid[row_idx][col_idx] == 0) begin
                    zero_row[zero_count] <= row_idx;
                    zero_col[zero_count] <= col_idx;
                    zero_count <= zero_count + 1;
                end
                if (col_idx < 3) col_idx <= col_idx + 1;
                else begin
                    col_idx <= 0;
                    if (row_idx < 3) row_idx <= row_idx + 1;
                    else row_idx <= 4; // Done
                end
            end
        end
    end

    // Logic to handle transitions within SEARCH state (Backtracking and Advancing)
    // This requires careful synchronization with the state machine transition logic.
    // To ensure robustness, let's add specific signals.
    
    reg scan_done;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) scan_done <= 0;
        else if (state == FIND) scan_done <= 0;
        else if (state == SEARCH && row_idx == 4) scan_done <= 1;
    end

    // Adjusted State Machine Logic for SEARCH/UPDATE
    // We need to strictly control current_zero_idx and search_digit.
    // Let's move the core control flow here to avoid state machine collision.
    
    // Override some next_state logic for the iterative nature of SEARCH
    always @(*) begin
        if (state == SEARCH) begin
            if (!scan_done) begin
                // Still scanning for zeros
                next_state = SEARCH;
                if ($past(state) != SEARCH) next_state = SEARCH; // Stay if just entered
                if (row_idx == 4) next_state = CHECK; // Transition to CHECK to start logic? No, wait.
                // Actually, when scanning is done, we want to start filling.
                if (row_idx == 4) next_state = CHECK; // Go to CHECK to test digit 1 for idx 0
            end else begin
                // Scanning done. Now we are in the filling loop.
                // Check logic from previous cycle to decide where to go next.
            end
        end
    end
    
    // Refined Control Logic in Sequential Block (Correction)
    // We need to integrate the logic for `current_zero_idx` and `search_digit` updates
    // triggered by state changes.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else begin
            
            // --- Handle SEARCH State Transitions ---
            
            // 1. Scan completion
            if (state == SEARCH && row_idx == 4 && $past(state) == SEARCH) begin
                // Scan finished in previous cycle. Start filling.
                current_zero_idx <= 0;
                search_digit <= 4'd1;
            end
            
            // 2. Moving to next zero (From UPDATE if partial)
            // (Handled in SEARCH block below based on $past state)
            
            // 3. Backtracking logic specific triggers
            if (state == SEARCH && ($past(state) == CHECK && $past(search_digit) > 9) || $past(state) == BACKTRACK) begin
                // We need to backtrack or try next digit
                // This logic runs when we are in SEARCH and need to prepare for next check
                
                if ($past(state) == CHECK && $past(search_digit) > 9) begin
                    // Exhausted digits at current index
                    if (current_zero_idx == 0) begin
                        // End of search (handled by transition to DONE or BACKTRACK state)
                    end else begin
                        // Go back one level
                        current_zero_idx <= current_zero_idx - 1;
                        search_digit <= stack[current_zero_idx - 1] + 1; // Increment previous
                        // Clear current cell
                        grid[zero_row[current_zero_idx]][zero_col[current_zero_idx]] <= 4'd0;
                    end
                end else if ($past(state) == BACKTRACK) begin
                    // We entered BACKTRACK state, which cleared cell. 
                    // Now back in SEARCH, we need to increment the digit at the lower index.
                    // But wait, the state machine transition for BACKTRACK goes BACKTRACK -> SEARCH.
                    // The logic inside BACKTRACK state usually handles the index decrement.
                    // So here we just need to ensure search_digit is correct for the new index.
                    // Actually, if BACKTRACK state decremented current_zero_idx, we are now at index N-1.
                    // We need to increment the value at N-1.
                    // But the value at N-1 is stored in stack[N-1] (or stack[N] before pop).
                    
                    // Let's simplify: 
                    // If we are in SEARCH and we came from BACKTRACK, 
                    // current_zero_idx has been decremented. We need to load the incremented value.
                    // However, the BACKTRACK state block logic handles the `current_zero_idx` decrement.
                    // So here we just set search_digit = stack[current_zero_idx] + 1.
                    if ($past(state) == BACKTRACK) begin
                         search_digit <= stack[current_zero_idx] + 1;
                    end
                end
            end
            
            // 4. Handling UPDATE (Success)
            if (state == SEARCH && $past(state) == UPDATE) begin
                // This case depends on if we filled the last cell or not.
                // Logic moved to $past(state)==CHECK block in the main always block above.
            end
        end
    end

    // Re-writing the middle-end logic to be purely driven by state transitions and flag setting
    // to avoid race conditions in simulation and synthesis.
    // We will use a clean 'step' signal.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_zero_idx <= 0;
            search_digit <= 0;
            // clear stack
            for(i=0; i<8; i=i+1) stack[i] <= 0;
        end else begin
            case (state)
                FIND: begin
                    if ($past(state) != FIND) begin
                        row_idx <= 0;
                        col_idx <= 0;
                        zero_count <= 0;
                    end else begin
                        // Scan step
                        if (row_idx < 4) begin
                            if (grid[row_idx][col_idx] == 0) begin
                                zero_row[zero_count] <= row_idx;
                                zero_col[zero_count] <= col_idx;
                                zero_count <= zero_count + 1;
                            end
                            if (col_idx < 3) col_idx <= col_idx + 1;
                            else begin
                                col_idx <= 0;
                                row_idx <= row_idx + 1;
                            end
                        end
                    end
                end
                
                SEARCH: begin
                    // If scan just finished (row_idx just became 4), initialize filling
                    if ($past(state) == FIND || ($past(state) == SEARCH && $past(row_idx) < 4 && row_idx == 4)) begin
                        if (zero_count > 0) begin
                            current_zero_idx <= 0;
                            search_digit <= 4'd1;
                        end else begin
                            // No zeros, will go to CHECK to validate initial grid
                        end
                    end
                    
                    // If we are filling (scan done)
                    if (row_idx == 4 && zero_count > 0) begin
                        // Check logic handles next steps
                    end
                end
                
                CHECK: begin
                    // Check logic is combinational. 
                    // If valid_op is high (set by combinational block), we update grid/stack and counters here for next cycle.
                    // BUT, we need to make sure we update only once per valid digit test.
                    // So we do updates based on $past(search_digit) validity.
                    
                    if (valid_op) begin
                        // Place value
                        grid[zero_row[current_zero_idx]][zero_col[current_zero_idx]] <= search_digit;
                        stack[current_zero_idx] <= search_digit;
                        
                        if (current_zero_idx + 1 == zero_count) begin
                            // Found complete solution
                            count <= count + 1;
                            // We need to backtrack to find other solutions
                            // But wait, if we are in CHECK, we are just validating.
                            // We need to move to state that handles backtracking.
                            // So in state machine, if valid_op && full -> state BACKTRACK (or UPDATE then BACKTRACK).
                        end
                    end
                end
                
                BACKTRACK: begin
                    // Clear current position
                    grid[zero_row[current_zero_idx]][zero_col[current_zero_idx]] <= 4'd0;
                    
                    if (current_zero_idx > 0) begin
                        current_zero_idx <= current_zero_idx - 1;
                        // search_digit will be updated in next cycle's SEARCH or stay in BACKTRACK loop
                        // Let's try to increment here and stay in BACKTRACK if we exceed 9, else go to SEARCH
                        search_digit <= stack[current_zero_idx - 1] + 1;
                        if (stack[current_zero_idx - 1] + 1 > 9) begin
                            // Need to backtrack further
                            // This requires a loop in BACKTRACK state or transitions
                        end
                    end
                end
            endcase
        end
    end

    // ------------------------------------------------------------------
    // FINALIZED STATE MACHINE & DATAPATH LOGIC
    // Combining everything into a cleaner structure to ensure synthesis correctness
    // ------------------------------------------------------------------

    // Registers for iterative scanning and filling
    reg [3:0] r_idx, c_idx; // For scanning
    reg [3:0] z_cnt;
    
    // Reset & Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            done <= 0;
            z_cnt <= 0;
            r_idx <= 0;
            c_idx <= 0;
            current_zero_idx <= 0;
            search_digit <= 1;
            // Clear Grid
            for(i=0; i<4; i=i+1)
                for(j=0; j<4; j=j+1)
                    grid[i][j] <= 0;
            // Clear Stack/Pos
            for(i=0; i<8; i=i+1) begin
                stack[i] <= 0;
                zero_row[i] <= 0;
                zero_col[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) state <= LOAD;
                end
                
                LOAD: begin
                    if (load_en) begin
                        if (row_addr < 4 && col_addr < 4)
                            grid[row_addr][col_addr] <= data_in;
                    end else begin
                        state <= FIND;
                    end
                end
                
                FIND: begin
                    // Scan grid to find zeros
                    if (r_idx < 4) begin
                        if (grid[r_idx][c_idx] == 0) begin
                            zero_row[z_cnt] <= r_idx;
                            zero_col[z_cnt] <= c_idx;
                            z_cnt <= z_cnt + 1;
                        end
                        if (c_idx < 3) c_idx <= c_idx + 1;
                        else begin
                            c_idx <= 0;
                            r_idx <= r_idx + 1;
                        end
                    end else begin
                        // Scan complete
                        state <= SEARCH;
                        current_zero_idx <= 0;
                        search_digit <= 4'd1;
                    end
                end
                
                SEARCH: begin
                    // This state validates the current search_digit against the grid
                    // If valid, we commit to grid and move to next zero (or done)
                    // If invalid, we increment digit
                    // If digit > 9, we backtrack
                    
                    // Combinational logic sets 'valid_op'
                    if (valid_op) begin
                        // Commit
                        grid[zero_row[current_zero_idx]][zero_col[current_zero_idx]] <= search_digit;
                        stack[current_zero_idx] <= search_digit;
                        
                        if (current_zero_idx + 1 == z_cnt) begin
                            // Solution Found
                            count <= count + 1;
                            // Must backtrack to find other solutions
                            state <= BACKTRACK;
                        end else begin
                            // Move to next zero
                            current_zero_idx <= current_zero_idx + 1;
                            search_digit <= 4'd1;
                        end
                    end else begin
                        // Invalid, try next digit
                        if (search_digit < 9) begin
                            search_digit <= search_digit + 1;
                        end else begin
                            // Backtrack
                            state <= BACKTRACK;
                        end
                    end
                    
                    // Special case: No zeros at all
                    if (z_cnt == 0 && valid_op) begin
                        // Initial grid is valid and complete
                        state <= DONE;
                        count <= count + 1;
                    end else if (z_cnt == 0 && !valid_op) begin
                        // Initial grid invalid
                        state <= DONE;
                    end
                end
                
                BACKTRACK: begin
                    // Clear current position
                    grid[zero_row[current_zero_idx]][zero_col[current_zero_idx]] <= 4'd0;
                    
                    if (current_zero_idx == 0) begin
                        // All branches exhausted
                        state <= DONE;
                    end else begin
                        // Go back one level
                        current_zero_idx <= current_zero_idx - 1;
                        // Read previous value from stack and increment
                        search_digit <= stack[current_zero_idx - 1] + 1;
                        // Stay in SEARCH to test the new digit
                        state <= SEARCH;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Validity Check
    always @(*) begin
        valid_op = 0;
        
        // Bounds
        if (search_digit < 1 || search_digit > 9) valid_op = 0;
        else begin
            // Row Uniqueness
            if (grid[zero_row[current_zero_idx]][0] == search_digit && zero_col[current_zero_idx] != 0) valid_op = 0;
            else if (grid[zero_row[current_zero_idx]][1] == search_digit && zero_col[current_zero_idx] != 1) valid_op = 0;
            else if (grid[zero_row[current_zero_idx]][2] == search_digit && zero_col[current_zero_idx] != 2) valid_op = 0;
            else if (grid[zero_row[current_zero_idx]][3] == search_digit && zero_col[current_zero_idx] != 3) valid_op = 0;
            else begin
                // Tentatively valid
                valid_op = 1;
                
                // L-Shape Rule
                // Check if we are in a position to check it (row > 0, col < 3)
                if (zero_row[current_zero_idx] > 0 && zero_col[current_zero_idx] < 3) begin
                    // Check dependencies (u and r)
                    // If u or r is 0, they are unknown. We cannot check L-rule, so we pass (valid_op remains 1)
                    // If u or r is filled, we must check.
                    
                    if (grid[zero_row[current_zero_idx] - 1][zero_col[current_zero_idx]] != 0 && 
                        grid[zero_row[current_zero_idx]][zero_col[current_zero_idx] + 1] != 0) begin
                        
                        l_val = search_digit;
                        u_val = grid[zero_row[current_zero_idx] - 1][zero_col[current_zero_idx]];
                        r_val = grid[zero_row[current_zero_idx]][zero_col[current_zero_idx] + 1];
                        
                        // Check Operations
                        valid_op = 0; // Reset to check conditions
                        
                        if (u_val == l_val * r_val) valid_op = 1;
                        else if (u_val == l_val + r_val) valid_op = 1;
                        else if (u_val > l_val && u_val == l_val - r_val) valid_op = 1;
                        else if (u_val > r_val && u_val == r_val - l_val) valid_op = 1;
                        else if (l_val != 0 && r_val != 0 && (l_val % r_val == 0) && u_val == l_val / r_val) valid_op = 1;
                        else if (l_val != 0 && r_val != 0 && (r_val % l_val == 0) && u_val == r_val / l_val) valid_op = 1;
                    end
                end
            end
        end
    end

    // State Transition Logic for 'search' state
    // We need to ensure we don't get stuck if initial grid has no zeros
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // idle
        end else begin
            if (state == FIND && r_idx == 4) begin
                // Determine next state immediately if no zeros found to avoid SEARCH hang
                if (z_cnt == 0) begin
                    // No zeros, go directly to validation logic (SEARCH handles this)
                end
            end
            
            // Fix for transitioning out of BACKTRACK (loop)
            if (state == BACKTRACK) begin
                // If we popped and search_digit <= 9, we go to SEARCH to test it.
                // Handled by state transition: BACKTRACK -> SEARCH.
                // If search_digit > 9 after popping, we need to pop again.
                // Handled by: BACKTRACK -> SEARCH. SEARCH sees > 9 -> BACKTRACK.
                // This creates a loop until index 0 is exceeded.
            end
        end
    end

endmodule
