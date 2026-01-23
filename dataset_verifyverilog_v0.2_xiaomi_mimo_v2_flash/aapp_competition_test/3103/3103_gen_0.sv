module ship_routes (
    input clk,
    input rst_n,
    input start,
    input [3:0] grid_row_idx,
    input [7:0] grid_char,
    output reg [23:0] result,
    output reg valid,
    output reg done,
    output reg [3:0] load_row
);

    // Parameters for row count and modulo
    parameter ROWS = 16;
    parameter MOD = 24'd1000003;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam LOAD_ROW = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam CHECK_DONE = 3'b011;
    localparam FINISHED = 3'b100;

    // Registers for State Machine
    reg [2:0] current_state, next_state;
    reg [3:0] current_row; // Tracks row index being processed (15 down to 0)
    reg [3:0] load_row_reg;

    // Grid Storage (16 rows x 16 cols) - 8 bits per char
    reg [7:0] grid_storage [0:15][0:15];
    
    // Horizontal Link Table (Pre-calculated destination for each column in the current row)
    // 16 entries, each is 4 bits (destination column) or 0xF if no link
    reg [3:0] h_links [0:15][0:15];

    // Reachability and Count Arrays
    // reachability_r: 1 bit per column
    // count_r: 24 bits per column
    reg [15:0] reachability_r;
    reg [23:0] count_r [0:15];

    // Intermediate results for horizontal propagation
    reg [15:0] reachability_horiz;
    reg [23:0] count_horiz [0:15];

    // Loop counters
    integer i, j;
    reg [3:0] col_idx;
    
    // Combinational intermediate signals for next state logic
    reg [2:0] next_state_c;
    reg [3:0] next_row_c;
    reg [23:0] result_sum;
    reg found_target;

    // Helper variables for combinational logic (must be declared inside always block or as reg/wire)
    reg [3:0] dest_col;
    reg [23:0] curr_cnt;
    reg curr_reach;
    reg [23:0] sum_temp;

    // Sequential Logic: State and Row Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_row <= 4'd15;
            load_row_reg <= 4'd15;
            valid <= 1'b0;
            done <= 1'b0;
            result <= 24'd0;
        end else begin
            current_state <= next_state;
            if (next_state == IDLE) begin
                current_row <= 4'd15;
                load_row_reg <= 4'd15;
            end else if (next_state == LOAD_ROW) begin
                // Keep loading the current row until switch to CALCULATE
                load_row_reg <= current_row;
            end else if (next_state == CALCULATE) begin
                // Prepare for next row or check
                if (current_row > 0) begin
                    current_row <= current_row - 1;
                    load_row_reg <= current_row - 1;
                end else begin
                    // Will transition to CHECK_DONE
                    current_row <= 4'd0; // Stay at 0 for final check
                end
            end else if (next_state == FINISHED) begin
                valid <= 1'b1;
                done <= 1'b1;
                result <= result_sum; // The final calculated total
            end
        end
    end

    // Grid Loading: Store characters when in LOAD_ROW state and inputs match
    // Assuming external TB provides valid char when load_row is asserted.
    // We capture the char at the specific column index requested (implied by the input stream or row-major order)
    // To simplify, we assume the TB sends 16 chars sequentially for the requested row.
    // We use a load counter internal to this block to index columns 0 to 15.
    reg [3:0] load_col_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_col_counter <= 4'd0;
        end else begin
            if (current_state == IDLE) begin
                load_col_counter <= 4'd0;
            end else if (current_state == LOAD_ROW) begin
                // Normally we would consume data. But the interface is input streaming. 
                // We need to assume the testbench puts grid_char on bus for us to latch.
                // To latch 16 chars, we increment a counter.
                if (load_col_counter < 15) begin
                    load_col_counter <= load_col_counter + 1;
                end else begin
                    load_col_counter <= 4'd0; // Reset for next row
                end
                // Store the char
                grid_storage[current_row][load_col_counter] <= grid_char;
            end else if (current_state == CALCULATE) begin
                // Pre-calculate horizontal links for the CURRENT row being processed
                for (i = 0; i < 16; i = i + 1) begin
                    if (grid_storage[current_row][i] == 8'h3C) begin // '<'
                        // If column > 0, link to left, else no valid link (or self? spec says adjacent if valid)
                        if (i > 0) h_links[current_row][i] <= i - 1;
                        else h_links[current_row][i] <= 4'hF; // No valid link (edge)
                    end else if (grid_storage[current_row][i] == 8'h3E) begin // '>'
                        // If column < 15, link to right
                        if (i < 15) h_links[current_row][i] <= i + 1;
                        else h_links[current_row][i] <= 4'hF; // No valid link (edge)
                    end else begin
                        h_links[current_row][i] <= 4'hF; // No horizontal link
                    end
                end
            end
        end
    end

    // Combinational Logic for Calculation (DP Transition)
    // This is complex, so we break it down. 
    // In CALCULATE state, we take the Reachability/Counts of the *current* row (stored in registers)
    // and compute the *next* row's reachability/counts.
    // However, horizontal moves happen in the SAME row before moving up.
    // Effectively: Horizontal propagation -> Vertical propagation.
    
    always @(*) begin
        // Defaults
        next_state_c = current_state;
        result_sum = result;
        
        case (current_state)
            IDLE: begin
                if (start) next_state_c = LOAD_ROW;
                else next_state_c = IDLE;
            end

            LOAD_ROW: begin
                // Wait until 16 chars loaded (load_col_counter wraps to 0 after 15)
                // Actually, load_col_counter increments on the cycle we read data.
                // We need to load 16 chars. 
                // Let's say we need to see load_col_counter == 15 AND a valid char.
                // To be safe, we use a simple counter in the sequential block or check row index.
                // Since we read 1 char per cycle, we can stay here for 16 cycles.
                // Let's count cycles inside the LOAD_ROW state.
                if (load_col_counter == 15 && grid_row_idx == current_row) begin // Simple hack: wait for last col
                     next_state_c = CALCULATE;
                end else if (load_col_counter == 15 && grid_row_idx != current_row) begin
                     // Wait for data
                     next_state_c = LOAD_ROW;
                end else if (load_col_counter == 15) begin
                     // Wait for 16th char to be latched (next cycle)
                     // Actually better to track cycles. Let's rely on the sequential counter.
                     // If counter is 15, we are writing the 16th char (index 15).
                     // Next cycle we should switch.
                     // Wait, the check happens simultaneously with the write.
                     // Let's assume we need to see the index reach 15.
                     // To avoid race conditions on reset/initial, let's stay 16 cycles explicitly if possible, 
                     // or rely on the fact that the external stimulus knows row 15 is requested.
                     // Let's check if we have loaded 16 items. 
                     // Actually, since load_col_counter is reset in IDLE and increments in LOAD_ROW, 
                     // we can check if it has completed a sequence.
                     // Simplification: transition when counter hits 15 (after latching).
                     next_state_c = CALCULATE;
                end else begin
                     next_state_c = LOAD_ROW;
                end
            end

            CALCULATE: begin
                // Logic:
                // 1. Apply horizontal moves on the reachability/count of the CURRENT row.
                //    (Input is reachability_r/count_r)
                // 2. Propagate vertically to NEXT row (row-1).
                //    The results become the new reachability_r/count_r for the next clock cycle.
                
                // We perform combinational propagation.
                // After this propagation, we go to CHECK_DONE to commit to registers or move to next row.
                next_state_c = CHECK_DONE;
            end

            CHECK_DONE: begin
                // Check if we processed all rows or reached a terminal state
                if (current_row == 0) begin
                    // We just finished row 0 processing (calculating reachability for "above" row -1, which doesn't exist).
                    // Wait, let's trace: 
                    // Cycle T: State=LOAD_ROW, loading Row 15.
                    // Cycle T+16: State=CALCULATE. Process Row 15. Reachability R15 -> R15_Horz -> R14.
                    // Cycle T+17: State=CHECK_DONE. Store R14. Row 14. 
                    // ...
                    // Cycle T+16+16*15: State=CALCULATE (Row 0). R0 -> R0_Horz -> R(-1) [Discard]
                    // Cycle T+16+16*15+1: State=CHECK_DONE. current_row = 0. 
                    // We are done with all rows. Calculate final result.
                    next_state_c = FINISHED;
                end else begin
                    // More rows to process
                    // Check if reachability for next row is zero (no paths)
                    // The reachability_r register now holds the state for the *next* row (because we updated it in CHECK_DONE's sequential logic? 
                    // Or do we update it in CALCULATE? 
                    // Let's update in CHECK_DONE sequence block to avoid timing loops.
                    // So here, we look at the 'computed next row' state.
                    
                    // But wait, we need to detect termination early.
                    // If the set of reachable columns for the next row is empty, we can stop.
                    // However, the prompt says "Result valid ~300 cycles". 
                    // Standard DP runs exactly 16 iterations. Let's just run 16 iterations for simplicity and correctness.
                    // But wait, if we reach '@', we should stop?
                    // "If a cell is '@', it is the target (valid path ends here)."
                    // Usually in DP, '@' stops propagation from that cell, but paths leading to it are summed.
                    // Since we are calculating path counts to the top, we sum when we land on '@' in the current row.
                    // The prompt says "Valid path ends here".
                    // So if we reach '@' in row r, we don't propagate to row r-1 from that column.
                    // The total result is the sum of ways to reach ANY '@' in the grid.
                    // Since we process from bottom up, the total ways to reach '@' is the sum of counts in the current row for columns containing '@'.
                    // But wait, we continue to process upper rows to find other '@'s?
                    // Yes, likely. So we accumulate counts into `result` whenever we see '@' in the current row.
                    // Then we continue propagation for other paths that might reach other '@'s.
                    // If reachability for the next row is empty, we can stop early.
                    
                    if (reachability_horiz == 16'b0) begin
                        // No way to reach row r-1 from row r.
                        // If we have accumulated a result, we are done.
                        // If not, no paths.
                        if (result_sum != 0) next_state_c = FINISHED;
                        else next_state_c = FINISHED; // Still done, result is 0
                    end else begin
                        next_state_c = LOAD_ROW;
                    end
                end
            end
            
            FINISHED: begin
                next_state_c = FINISHED;
            end

            default: next_state_c = IDLE;
        endcase
    end

    // Combinational DP Calculation Logic
    // This block calculates reachability_horiz and count_horiz, and also next_reachability/next_count
    // Actually, let's implement the logic explicitly inside the combinational block to wire to the registers.
    
    // We need to calculate:
    // 1. Horizontal propagation on current row state (reachability_r, count_r)
    //    -> reachability_horiz, count_horiz
    // 2. Vertical propagation from row 'current_row' to 'current_row - 1'
    //    -> next_reachability, next_count
    // 3. Accumulate results for '@'
    
    reg [15:0] next_reachability;
    reg [23:0] next_count [0:15];
    reg [23:0] current_result_sum;

    integer k;
    always @(*) begin
        // Step 1: Horizontal Propagation
        // Initialize horiz arrays with zeros
        for (k = 0; k < 16; k = k + 1) begin
            reachability_horiz[k] = 1'b0;
            count_horiz[k] = 24'd0;
        end

        // Iterate over columns of CURRENT row
        for (k = 0; k < 16; k = k + 1) begin
            if (reachability_r[k]) begin
                // Current cell is reachable
                if (grid_storage[current_row][k] == 8'h23) begin // '#' blocked
                    // Do nothing
                end else if (grid_storage[current_row][k] == 8'h3C || grid_storage[current_row][k] == 8'h3E) begin // < or >
                    // Follow link
                    dest_col = h_links[current_row][k];
                    if (dest_col != 4'hF) begin // Valid link within bounds
                        reachability_horiz[dest_col] = 1'b1;
                        count_horiz[dest_col] = count_horiz[dest_col] + count_r[k];
                        if (count_horiz[dest_col] >= MOD) count_horiz[dest_col] = count_horiz[dest_col] - MOD;
                    end else begin
                        // Link goes off grid? Link to self if blocked by edge? Spec: "if valid". 
                        // If invalid, usually means stay or blocked. Let's assume blocked/off-grid implies no path through this link.
                    end
                end else begin // '~' or '@' or other
                    // Stay in same column
                    reachability_horiz[k] = 1'b1;
                    count_horiz[k] = count_horiz[k] + count_r[k];
                    if (count_horiz[k] >= MOD) count_horiz[k] = count_horiz[k] - MOD;
                end
            end
        end

        // Step 2: Vertical Propagation to Next Row (current_row - 1)
        // Initialize next arrays with zeros
        for (k = 0; k < 16; k = k + 1) begin
            next_reachability[k] = 1'b0;
            next_count[k] = 24'd0;
        end
        current_result_sum = result; // Initialize with current accumulated result

        // Iterate over columns of CURRENT row after horizontal moves
        for (k = 0; k < 16; k = k + 1) begin
            if (reachability_horiz[k]) begin
                // Check if this cell is an '@' -> Add to result, do NOT propagate up
                if (grid_storage[current_row][k] == 8'h40) begin // '@'
                    current_result_sum = current_result_sum + count_horiz[k];
                    if (current_result_sum >= MOD) current_result_sum = current_result_sum - MOD;
                    // Don't propagate up from '@'
                end else if (grid_storage[current_row][k] == 8'h23) begin
                    // Blocked (should not happen as horizontal logic handles blocked, but safety)
                end else begin
                    // Valid cell (~ or < or >). Propagate UP to row-1 if valid.
                    // The ship moves North to the cell directly above.
                    // The target cell above must not be '#' (blocked).
                    // But we don't have the row above loaded yet if we are in CALCULATE state?
                    // WAIT. This is a problem. 
                    // We are in CALCULATE state for row 'current_row' (e.g., 15).
                    // We have loaded row 'current_row' in LOAD_ROW state.
                    // To propagate to row 14, we need to know if grid_storage[14][k] is '#'.
                    // But row 14 is loaded in the *next* LOAD_ROW state.
                    // So we cannot decide validity of vertical move in this cycle.
                    // CORRECTION:
                    // We need to load the NEXT row *before* calculating the transition from the CURRENT row.
                    // OR, we assume that '#' blocking is only checked when arriving at the cell.
                    // Prompt: "From any reachable cell in the current row, the ship can move North to the cell directly above in the next row."
                    // "If a cell is '#', it is blocked."
                    // This implies we check the cell ABOVE.
                    // So the order must be:
                    // 1. Load Row N.
                    // 2. Load Row N-1. (Wait, we process bottom up).
                    // 3. Calculate transitions from N to N-1, checking Row N-1 characters.
                    // 
                    // REVISED STATE MACHINE STRATEGY:
                    // INIT: Load Row 15.
                    // LOOP:
                    //   Load Row N-1.
                    //   Calculate Row N -> N-1 (using loaded N-1).
                    //   Move to N-2.
                    // 
                    // Initial setup:
                    // IDLE -> LOAD_ROW 15 -> IDLE (Wait, we need Row 14 to calc 15->14).
                    // Prompt says: "Process rows from bottom to top."
                    // "Use dynamic programming..."
                    // It might be easier to double buffer.
                    // 
                    // ALTERNATIVE INTERPRETATION:
                    // The movement logic "North to cell above" means simply shift column index.
                    // If the cell above is '#', you just can't be there.
                    // But you determine if you can be there based on *previous* calculations.
                    // No, you determine if you can move *to* it.
                    // 
                    // Let's look at the "Implementation Strategy" hint: 
                    // "In LOAD_ROW state... pre-calculate horizontal mapping..."
                    // "From any reachable cell... check the cell above... mark column as reachable in the next row's state."
                    // This implies we need the 'cell above' info to calculate 'next row's state'.
                    // BUT we are processing bottom-up. 
                    // When we are at row 15, we don't know row 14 content to check if we can move to 14.
                    // 
                    // Let's assume the prompt implies we LOAD the row ABOVE first, or we process horizontally then pass up.
                    // Actually, standard DP for this problem (Ship routes) usually works like this:
                    // State variables: Reachability/Counts for the *current* horizontal positions on the *current* row.
                    // Transition: Move horizontally on current row -> Update current positions.
                    // Transition: Move North -> Create new Reachability/Counts for the *next* row.
                    // 
                    // We need to know if the cell at (row-1, col) is '#' to allow the move.
                    // This means we need row N-1 available when processing row N.
                    // 
                    // Revised Plan to fit the constraints (only 1 row input at a time):
                    // We must cache the 'vertical move validity' or the row above.
                    // Since we process 16 rows, we can store the whole grid.
                    // The prompt says "In LOAD_ROW state... store char".
                    // And "Use a small internal table (e.g., 16 registers)" for horizontal links.
                    // It doesn't explicitly say we store the whole grid, but "grid_storage" is implied.
                    // However, we must verify the interface.
                    // `input [3:0] grid_row_idx`
                    // `input [7:0] grid_char`
                    // `output reg [3:0] load_row`
                    // The testbench provides chars. 
                    // 
                    // Maybe we don't need to know row N-1 content *during* N's calculation if we do it in two passes?
                    // No, that's inefficient.
                    // 
                    // Let's stick to the most robust interpretation of the prompt's "Implementation Strategy":
                    // 1. Load Row 15. (Wait, do we have row 14? No).
                    // 2. Load Row 14. (Now we have 15 and 14).
                    // 3. Calculate for 15 (using 14 for vertical check).
                    // 4. Discard 15 (or keep if needed).
                    // 5. Load Row 13.
                    // 6. Calculate for 14 (using 13).
                    // 
                    // Wait, the prompt says: "Process rows from bottom to top (row 15 down to 0)."
                    // This usually implies Row 15 is processed first.
                    // If we need Row 14 to process Row 15, we must load Row 14 *before* we start calculating Row 15.
                    // But Row 15 is the start. 
                    // The "Start" is at Row 15. 
                    // The move is "North" to Row 14.
                    // So we need to know if Row 14 cells are blocked.
                    // 
                    // Strategy: Load the rows in reverse order (0 to 15)?
                    // No, bottom to top.
                    // 
                    // Maybe the 'blocked' check for vertical move is done when we *arrive* at the next row, not when leaving.
                    // "Transition: ... Check the cell above (row-1): if it is not '#', mark column as reachable..."
                    // This explicitly says check the cell above.
                    // 
                    // Solution:
                    // We need to buffer one row.
                    // Cycle 1-16: Load Row 15.
                    // Cycle 17-32: Load Row 14.
                    // Now we have Row 15 and Row 14.
                    // Cycle 33: CALCULATE Row 15 (horiz + vert to 14).
                    // Cycle 34: Load Row 13.
                    // Cycle 35: CALCULATE Row 14.
                    // ...
                    // This is "Double Buffering".
                    // However, the prompt suggests a simpler state machine: IDLE -> LOAD -> CALC -> IDLE/LOAD.
                    // And "use a small internal table (e.g., 16 registers)".
                    // This usually implies we are allowed to store the grid.
                    // The "Dynamic Programming" arrays (reachability, count) are the "small internal table".
                    // The prompt allows 16x16 grid storage implicitly (it's a requirement).
                    // 
                    // So, let's implement double buffering or just store the whole grid first.
                    // The prompt says: "The module should output 'valid' and 'done' when the count... is finalized."
                    // It implies we can just load the whole grid first. 
                    // But the prompt says: "Since the grid is small... we can process one row per clock cycle after loading."
                    // This implies we load row, process row, load row, process row.
                    // 
                    // If we load row, process row, we don't know the row above.
                    // UNLESS:
                    // The DP works by accumulating *paths to the bottom*.
                    // Start at row 15. Reachability = {start_col}.
                    // Move Horizontal.
                    // Move North.
                    // To move North, we need to know if the cell at Row 14 is blocked.
                    // But we haven't loaded Row 14 yet in a "Load -> Calc -> Load -> Calc" stream.
                    // 
                    // RETHINK: 
                    // Maybe the check is: "Check the cell above... if not blocked".
                    // If we assume we process from Row 15 to 0.
                    // We need the content of Row X-1 when processing Row X.
                    // So we need to load Row X-1 BEFORE processing Row X.
                    // 
                    // Initial State:
                    // Load Row 0.
                    // Load Row 1.
                    // ...
                    // Load Row 15.
                    // Now we have the whole grid. Then calculate.
                    // This takes 16 * 16 = 256 cycles.
                    // The prompt says "Result valid ~300 cycles". 
                    // 256 load + 16 calc = 272. Close enough.
                    // This matches "Process rows from bottom to top" (conceptually) while loading top to bottom (or whatever order).
                    // 
                    // However, the prompt explicitly defines a state machine: 
                    // "1. Initialize state at row 15..."
                    // "2. Process rows from bottom to top."
                    // "3. Use dynamic programming..."
                    // "Implementation Strategy: ... LOAD_ROW, CALCULATE..."
                    // 
                    // Let's look at the hint: "In LOAD_ROW state, the module reads 16 characters. It should pre-calculate the horizontal mapping..."
                    // "To handle vertical movement: ... check the cell above (row-1)..."
                    // 
                    // If we are in LOAD_ROW, we are loading Row N. 
                    // We can pre-calculate horizontal links for Row N.
                    // We can't check Row N-1 yet if we are loading sequentially N, N-1, N-2...
                    // (Wait, bottom to top means 15, 14, 13...)
                    // If we load 15, then 14, when loading 14 we have 15 available.
                    // So when loading N (where N is decreasing), we have N+1 available.
                    // 
                    // Let's trace:
                    // Start at IDLE.
                    // Start signal -> LOAD_ROW (Row 15). Store Row 15.
                    // Switch to CALCULATE.
                    // Problem: No Row 14.
                    // 
                    // Maybe the logic is:
                    // Load Row 15. (Setup).
                    // Loop:
                    //   Load Row 14 (while holding 15).
                    //   Calculate transitions from 15 to 14.
                    //   Swap/Update pointers.
                    //   Load Row 13.
                    //   Calculate transitions from 14 to 13.
                    //   ...
                    // 
                    // This implies we are loading the *destination* row before calculating the move from the *source*.
                    // 
                    // Let's try to fit the "Load Row" output.
                    // The module outputs `load_row`. It tells the TB which row to send.
                    // If we output load_row = 15, we get grid chars for row 15.
                    // If we output load_row = 14, we get chars for row 14.
                    // 
                    // Revised Algorithm:
                    // 1. Load Row 15. (store in Row_Buffer_B). 
                    //    (Actually, let's store in `current_row_buffer`).
                    // 2. Loop i from 15 down to 1:
                    //    a. Load Row i-1. (store in `next_row_buffer`).
                    //    b. Process Row i (from `current_row_buffer`) -> `current_reachability/count`.
                    //       Horizontal move on Row i.
                    //       Vertical move to Row i-1 (check `next_row_buffer` for '#' to allow move).
                    //       Update `next_reachability/count` (for Row i-1).
                    //    c. Copy `next_reachability/count` to `current_reachability/count`.
                    //    d. Swap buffers.
                    // 3. Process Row 0 (special case, no move up).
                    // 
                    // This requires 15 iterations of Load+Calc.
                    // Initial Load Row 15 (Calc delayed).
                    // 
                    // Let's adapt the state machine to this.
                    // 
                    // IDLE -> LOAD_START (Row 15) -> LOAD_NEXT (Row 14) -> CALC (Row 15 to 14) -> LOAD_NEXT (Row 13) -> CALC (Row 14 to 13) -> ... -> FINISHED.
                    // 
                    // But the prompt says: 
                    // "IDLE, LOAD_ROW, CALCULATE, CHECK_DONE."
                    // 
                    // Let's stick to the prompt's flow as much as possible, but ensure we have the Row Above.
                    // 
                    // Correct Logic:
                    // We are calculating paths that START at row 15 and go UP.
                    // So the flow is:
                    // 1. Get start column. (Wait, where does start column come from?)
                    //    "Initialize state at row 15, column x_init." 
                    //    "loaded from input stream".
                    //    Inputs: `start`, `grid_row_idx`, `grid_char`. 
                    //    There is no `x_init` input port.
                    //    Maybe `grid_row_idx` is used for start column? Or `grid_char` on start?
                    //    Actually, the problem is ambiguous about the start column input.
                    //    Let's assume `grid_char` on the cycle `start` is high provides the start column? No.
                    //    "The external testbench will provide the characters."
                    //    Maybe the start column is fixed in the testbench? Or the prompt implies it is part of the grid.
                    //    Re-read: "The ship starts at the bottom row (row 15) and a specified initial column (loaded from input stream)."
                    //    It doesn't specify how. 
                    //    Let's assume a separate mechanism is not provided, so we must deduce it.
                    //    Or maybe we just initialize reachability for ALL columns at row 15? No.
                    //    "Initialize state at row 15, column x_init." -> implies specific column.
                    //    Let's check inputs again. `grid_row_idx`, `grid_char`.
                    //    Maybe when `start` is high, `grid_row_idx` contains the start column? 
                    //    Since `grid_row_idx` is 4 bits, it goes 0-15. That works for a column index.
                    //    Let's assume `start` asserts, and `grid_row_idx` gives the start column.
                    //    Or `grid_char` (8 bits) gives ASCII '0'-'9'? No, ASCII.
                    //    Let's assume `grid_row_idx` is used as the Start Column when `start` is high.
                    //    This seems plausible.
                    // 
                    // Implementation plan:
                    // We need to store 2 rows: Current Row (Row N) and Next Row (Row N-1).
                    // But wait, we need to process row 15 (start). Row 15 is the start row.
                    // So we need Row 15 content. Then we need Row 14 content to see where we can go from 15.
                    // 
                    // So the sequence is:
                    // 1. Load Row 15 (store in R_top). (Wait, we need start column. Assume start column is provided on start cycle).
                    //    Actually, we load 16 chars for row 15.
                    //    During loading, we don't know the start column.
                    //    Let's assume `grid_row_idx` is the start column when `start` is asserted.
                    //    But `start` might just pulse high.
                    //    Let's look at `input start`. 
                    //    "2. Initialize state at row 15, column x_init." -> implies we need to set initial reachability.
                    //    If we can't get x_init, we might have to scan the grid for a start marker? 
                    //    Or maybe the prompt implies `grid_char` stream includes start info?
                    //    "input [7:0] grid_char // Character input for current cell"
                    //    "Characters: '~' (open), '#' (block), '>' ('<', '@')."
                    //    No start marker.
                    //    "Input stream" -> maybe the testbench puts `x_init` on `grid_char` on the first cycle before row data?
                    //    This is fragile. 
                    //    
                    //    Let's assume a convention: The testbench asserts `start` and puts `x_init` (ASCII representation?) on `grid_char` for 1 cycle.
                    //    OR, simpler: `grid_row_idx` on start cycle is `x_init`.
                    //    Since `grid_row_idx` is 4 bits, it maps directly to column index (0-15).
                    //    I will assume `start` signal comes with `grid_row_idx` as `x_init`.
                    //    Then `start` is de-asserted, and loading of Row 15 begins (or continues).
                    //    
                    //    Wait, the prompt says: "The external testbench will provide the characters."
                    //    "In the LOAD_ROW state, the module reads 16 characters."
                    //    "Store char and calculate horizontal link."
                    //    
                    //    If we use `grid_row_idx` as start column, we lose track of which row we are requesting?
                    //    No, `grid_row_idx` is an INPUT. It tells the module "I am sending data for row X".
                    //    But wait, `output reg [3:0] load_row` implies we REQUEST a row.
                    //    So `grid_row_idx` is an input FROM the TB indicating which row the char belongs to.
                    //    So `grid_row_idx` is NOT start column.
                    //    
                    //    Where does start column come from?
                    //    Maybe it is fixed in the code? No.
                    //    "specified initial column (loaded from input stream)."
                    //    Maybe the first character sent is the start column index?
                    //    `grid_char` is 8 bits. '0' is 0x30. '1' is 0x31...
                    //    But the grid characters are also sent on `grid_char`.
                    //    We need a way to distinguish.
                    //    
                    //    Perhaps `load_row` acts as a handshake.
                    //    When we go to IDLE, we wait for `start`.
                    //    When `start` is high, maybe `grid_char` contains `x_init`?
                    //    
                    //    Let's assume the `start` pulse is accompanied by `grid_char` containing the ASCII of the start column (0-9, A-F?) or just the binary value?
                    //    "Assume all inputs are of type `reg` unless otherwise specified."
                    //    Let's assume the simplest: `start` is high, `grid_char` is the binary column index (0-15) for 1 cycle.
                    //    Then we go to LOAD_ROW.
                    //    
                    //    ALTERNATIVE:
                    //    Maybe the grid is loaded into `grid_storage` first, and THEN `start` is asserted to begin calculation?
                    //    "Inputs: start, grid_row_idx, grid_char"
                    //    "Outputs: load_row"
                    //    If `load_row` is output, we request data. 
                    //    So the module initiates the loading.
                    //    The prompt says "The external testbench will provide the characters."
                    //    So we say "Load Row 15", TB sends 16 chars. 
                    //    But we need `x_init` to initialize the reachability.
                    //    
                    //    What if `x_init` is inside the grid data? No.
                    //    What if `x_init` is part of the interface but omitted by mistake? 
                    //    I must design with given ports.
                    //    
                    //    Maybe `grid_row_idx` is shared? 
                    //    When `load_row` is output, `grid_row_idx` input should match.
                    //    When `start` is high, `grid_row_idx` is the start column? 
                    //    This is confusing.
                    //    
                    //    Let's look at the "State Definitions".
                    //    "IDLE: Wait for start. Clear internal arrays."
                    //    "LOAD_ROW: Assert 'load_row'... Store char."
                    //    
                    //    Maybe the `start` signal simply enables the FSM, and `x_init` is implicitly the column where the ship is found in row 15?
                    //    "The ship starts at the bottom row (row 15) and a specified initial column (loaded from input stream)."
                    //    "Initialize state at row 15, column x_init."
                    //    This implies we set reachability to {x_init} = 1.
                    //    
                    //    Since `x_init` is not an input, I will assume a convention: 
                    //    `grid_char` on the cycle after `start` is asserted contains `x_init` (binary value).
                    //    Or `grid_row_idx` on start cycle.
                    //    Given `grid_row_idx` is 4 bits, and 0-15 are columns, `grid_row_idx` makes sense as `x_init`.
                    //    But `grid_row_idx` is also used to validate the loaded row.
                    //    If `start` is high, we are not in `LOAD_ROW` yet. 
                    //    So `grid_row_idx` in `IDLE` state is free to be `x_init`.
                    //    
                    //    Let's use that. 
                    //    State IDLE, if start: latched_start_col <= grid_row_idx.
                    //    
                    //    Now, about Double Buffering.
                    //    We need Row N and Row N-1.
                    //    We can store Row N in registers `row_current`.
                    //    We can store Row N-1 in registers `row_next`.
                    //    
                    //    Modified FSM:
                    //    IDLE -> LOAD (Row 15) -> PREP (Load Row 14) -> CALC -> PREP (Load Row 13) -> CALC -> ... -> FINISHED.
                    //    
                    //    Actually, to save states, we can do:
                    //    LOAD_ROW: Loads into `row_next`.
                    //    Once loaded, if `row_current` is valid (start or from prev calc):
                    //      Goto CALC.
                    //    CALC: 
                    //      Process `row_current` (horiz) + `row_next` (vert check) -> `next_reachability/count`.
                    //      Copy `next_reachability/count` -> `reachability_r/count_r`.
                    //      Copy `row_next` -> `row_current`.
                    //      If `row_next` index > 0, decrement index, Goto LOAD_ROW.
                    //      Else Goto FINISHED.
                    //    
                    //    Wait, we need to load the grid. We don't have `row_current` initially (for row 15).
                    //    So:
                    //    1. IDLE -> LOAD_ROW (Row 15). Store in `row_current` (or `row_next` and swap).
                    //       But we don't calc yet.
                    //    2. LOAD_ROW (Row 14). Store in `row_next`.
                    //    3. CALC (Row 15 + Row 14).
                    //    4. Update pointers. (Row 14 becomes current, need Row 13 next).
                    //    5. LOAD_ROW (Row 13). Store in `row_next`.
                    //    6. CALC (Row 14 + Row 13).
                    //    ...
                    //    
                    //    This requires a PREP state or just logic in LOAD_ROW.
                    //    Let's define a counter `load_phase` to track if we are loading the FIRST row or SUBSEQUENT rows.
                    //    
                    //    To fit the prompt's states: IDLE, LOAD_ROW, CALCULATE, CHECK_DONE.
                    //    Let's use `current_row` as the row index we are currently *processing* (Source row).
                    //    
                    //    Logic:
                    //    `current_row` starts at 15.
                    //    In IDLE: Set `current_row` = 15. Set `next_row_idx` = 14.
                    //    In LOAD_ROW:
                    //      If `current_row` == 15 (first time):
                    //        Load data into `row_buffer_B` (let's say). 
                    //        (Actually, simpler: Load into `row_buffer_A` if `current_row` == 15, else `row_buffer_B`?)
                    //        No, let's just load into `row_current` if `current_row` == 15. 
                    //        Then transition to LOAD_ROW again? Or CALC?
                    //        We can't calculate without Row 14.
                    //        So after loading Row 15, we go to LOAD_ROW for Row 14.
                    //        But how to distinguish?
                    //        Use a `init_load_done` flag.
                    //    
                    //    Let's simplify:
                    //    We will load ALL 16 rows first into `grid_storage`. 
                    //    The prompt allows 16x16 storage. 
                    //    The prompt says "In LOAD_ROW state... store char".
                    //    So we can load the whole grid.
                    //    Then we perform the DP calculation.
                    //    This is much safer and deterministic.
                    //    Prompt says "Result valid ~300 cycles". Loading 16 rows * 16 chars = 256 cycles. Calculating 16 rows = 16 cycles. Total 272. Matches.
                    //    
                    //    However, the prompt says "In LOAD_ROW state... pre-calculate horizontal mapping".
                    //    If we load all, we can't calculate horizontal mapping per cycle because we don't know which row is being processed yet.
                    //    But we can store `grid_char` in `grid_storage` and calculate links later in CALCULATE state.
                    //    The prompt says: "It should pre-calculate the horizontal mapping for that row... and store it in a small internal table."
                    //    This implies per-row processing.
                    //    
                    //    Let's try to implement the "per row" processing but with buffering.
                    //    
                    //    Revised FSM:
                    //    IDLE:
                    //      Start -> Check `grid_row_idx` (as x_init). Initialize Reachability/Cycles.
                    //      Next: LOAD_ROW.
                    //    LOAD_ROW:
                    //      Assert `load_row`.
                    //      Wait for 16 chars.
                    //      Store chars in `grid_storage` at index `current_row`.
                    //      Calculate H_Links for `current_row`.
                    //      If `current_row` == 15 (First load):
                    //        Decrement `current_row` to 14.
                    //        Go to LOAD_ROW again (load row 14).
                    //      Else:
                    //        We now have Row X+1 (in `grid_storage`) and Row X (just loaded).
                    //        Wait, we need Row X+1 to process Row X.
                    //        So we always need to load the row ABOVE the one we want to process.
                    //        
                    //        Let's trace:
                    //        We want to process Row 15. Need Row 14.
                    //        We want to process Row 14. Need Row 13.
                    //        ...
                    //        We want to process Row 0. Need Row -1 (None).
                    //        
                    //        So, we need to load Row 14, 13, ..., 0. And Row 15 is the start row.
                    //        The start row (15) is just initialized in reachability.
                    //        
                    //        Wait, if we initialize reachability at Row 15, we need to check cells at Row 15.
                    //        Actually, we initialize reachability for Row 15. 
                    //        Then we move to Row 14.
                    //        To move to Row 14, we need Row 15 content (for horizontal move) and Row 14 content (for vertical valid).
                    //        
                    //        So:
                    //        1. Load Row 15. Store in `row_A`. (No calc yet).
                    //        2. Load Row 14. Store in `row_B`.
                    //        3. Calc: `reachability_r` (Row 15) + `row_A` (Row 15) + `row_B` (Row 14) -> `next_reachability` (Row 14).
                    //        4. Copy `row_B` to `row_A`. (Row 14 becomes A).
                    //        5. Load Row 13. Store in `row_B`.
                    //        6. Calc: `reachability_r` (Row 14) + `row_A` (Row 14) + `row_B` (Row 13) -> `next_reachability` (Row 13).
                    //        ...
                    //        
                    //        This uses 2 row buffers. 
                    //        
                    //        We need to fit this into states.
                    //        Let's use `current_row` as the row index we are trying to REACH.
                    //        Actually, let's use `current_row` as the row we are currently LOADING.
                    //        
                    //        Start: IDLE.
                    //        IDLE -> LOAD_ROW. (Load Row 15 into `row_buffer_1`).
                    //        In LOAD_ROW: 
                    //          If `load_cnt` == 15:
                    //            If `first_load` (Row 15):
                    //              `first_load` = 0;
                    //              `current_row` = 14;
                    //              `row_buffer_select` = 2;
                    //              Stay in LOAD_ROW (to load next).
                    //            Else:
                    //              Switch to CALCULATE.
                    //              (We have loaded the 'next' row).
                    //              
                    //        CALCULATE:
                    //          Source: Row `current_row + 1` (which is in `row_buffer_1` or `2`?).
                    //          Dest: `current_row` (in the other buffer).
                    //          Transition Logic.
                    //          After calc, we need to load `current_row - 1`.
                    //          So `current_row` decrements.
                    //          If `current_row` == 0, we do one last calc, then done.
                    //          
                    //          Wait, if we calc for Row `current_row + 1` -> `current_row`.
                    //          After calc, `reachability_r` holds state for `current_row`.
                    //          Then we need to load `current_row - 1`.
                    //          So we go to LOAD_ROW (load `current_row - 1`).
                    //          
                    //        CHECK_DONE state is needed to see if we are done.
                    //        
                    //        Let's refine the state transitions:
                    //        
                    //        IDLE:
                    //          Start: Set `start_col`. Init `reachability_r` (only bit `start_col` set). Init `count_r` (only bit `start_col` = 1).
                    //          Set `current_row` = 15.
                    //          Next: Goto LOAD_ROW.
                    //          
                    //        LOAD_ROW:
                    //          (Target row: `current_row`).
                    //          If `current_row` == 15:
                    //             Load 16 chars into `row_15_buffer`.
                    //             Pre-calc H_Links for row 15.
                    //             `current_row` = 14.
                    //             (We have row 15. Need row 14 to calc).
                    //             Next: Goto LOAD_ROW (to load row 14).
                    //          Else:
                    //             Load 16 chars into `row_N_buffer`.
                    //             Pre-calc H_Links for row N.
                    //             (We now have Row N and Row N+1).
                    //             Next: Goto CALCULATE.
                    //             
                    //        CALCULATE:
                    //          Process Row N+1 (source) -> Row N (dest).
                    //          Inputs: 
                    //            `reachability_r` (valid for Row N+1).
                    //            `count_r` (valid for Row N+1).
                    //            `h_links` (valid for Row N+1).
                    //            `grid_char` of Row N (stored in `row_N_buffer`) to check for '#'.
                    //          Logic:
                    //            Horizontal moves on Row N+1.
                    //            Vertical moves to Row N (if Row N cell is not '#').
                    //            Accumulate '@' counts in `result`.
                    //          Output: Update `reachability_r` (for Row N), `count_r` (for Row N).
                    //          Next: 
                    //            If `current_row` == 0: 
                    //               (We just finished processing Row 1->0).
                    //               Now we need to process Row 0 (final).
                    //               But we don't have Row -1.
                    //               So we need a special case for Row 0.
                    //               Actually, in CALCULATE, we process Source N+1 -> Dest N.
                    //               When `current_row` (the target) is 0, we are done with the vertical transition.
                    //               We still need to check Row 0 for '@' and add to result.
                    //               Wait, in the transition to Row 0, we check Row 0 cells.
                    //               If we are at Row 0, no more upward moves.
                    //               So we need a final check on Row 0.
                    //               
                    //               Maybe we should change the loop structure.
                    //               
                    //               Standard Loop:
                    //               We have Reachability at Row X.
                    //               We want to move to Row X-1.
                    //               So we need content of Row X and Row X-1.
                    //               
                    //               Loop:
                    //               Load Row X.
                    //               Load Row X-1.
                    //               Process Row X -> X-1.
                    //               Update Reachability for X-1.
                    //               Discard Row X. Keep Row X-1 as new Row X.
                    //               Load Row X-2.
                    //               ...
                    //               
                    //               Implementation:
                    //               Load Row 15. (Store in `row_buffer_A`). (Start State).
                    //               Load Row 14. (Store in `row_buffer_B`). (Start State).
                    //               Loop:
                    //                 Process `row_buffer_A` -> `row_buffer_B`.
                    //                 Swap buffers (B becomes A).
                    //                 Load next row (X-2) into B.
                    //                 
                    //               This is hard to map to IDLE/LOAD/CALC.
                    //               
                    //               Let's go back to "Load All" strategy.
                    //               It is safer, fits the cycle budget, and avoids complex double-buffer state logic.
                    //               The prompt says "In LOAD_ROW state... pre-calculate horizontal mapping".
                    //               If we load all, we can calculate horizontal mapping in CALCULATE state by iterating columns.
                    //               Or, we can calculate H_Links in LOAD_ROW state for the row being loaded.
                    //               
                    //               "Load All" Strategy:
                    //               IDLE -> LOAD_ROW -> LOAD_ROW -> ... (16 times) -> CALCULATE -> CHECK_DONE -> (loop rows) -> FINISHED.
                    //               
                    //               But the prompt says "Use dynamic programming: maintain reachability and count arrays".
                    //               And "Transition: ... use horizontal mapping".
                    //               
                    //               If we load all, we need 16 rows * 16 cols = 256 bytes of storage. 
                    //               The prompt doesn't forbid it. "Grid width: 16 bits (8 bits for char * 16 columns)." implies per cycle.
                    //               
                    //               Let's try the "Load All" method, as it's most robust.
                    //               
                    //               LOAD_ROW Phase (16 iterations):
                    //                 State: LOAD_ROW.
                    //                 Counter `load_idx` 0 to 15.
                    //                 Assert `load_row = load_idx`.
                    //                 Wait for char, store in `grid_storage[load_idx][col_counter]`.
                    //                 (Actually `load_row` is output, `grid_row_idx` is input. We request row X, TB sends chars with `grid_row_idx` = X).
                    //                 
                    //                 Wait, `grid_row_idx` is an INPUT. The TB tells us which row it is sending.
                    //                 If we assert `load_row = 15`, TB sends `grid_row_idx = 15`. 
                    //                 We need to read 16 chars. 
                    //                 We need a counter `col_counter` (0-15).
                    //                 
                    //                 In LOAD_ROW:
                    //                 `load_row` = `current_row_idx` (starts 15, decrements to 0).
                    //                 When `col_counter` == 0 and data valid, we know we are loading `current_row_idx`.
                    //                 We consume 16 chars.
                    //                 After 16 chars, `current_row_idx` --.
                    //                 If `current_row_idx` < 0, Goto CALCULATE.
                    //                 
                    //               CALCULATE Phase:
                    //                 Initialize Reachability/Cycles for Row 15.
                    //                 Actually, we need `x_init`. 
                    //                 Where do we get `x_init`?
                    //                 I'll assume `start` signal provides `x_init` on `grid_char` (1 cycle).
                    //                 
                    //                 State: CALCULATE.
                    //                 Loop from Row 15 down to 0:
                    //                   Horizontal Propagation on current Row.
                    //                   Vertical Propagation to Row-1 (Check `grid_storage[row-1][col]`).
                    //                   (Wait, we need to know Row-1 content. We have all rows stored!)
                    //                   Update Reachability/Counts for Row-1.
                    //                   Accumulate Result if `@` found.
                    //                   
                    //                 This loop takes 16 cycles.
                    //                 
                    //                 Total Cycles: 
                    //                 IDLE: 1
                    //                 LOAD_ROW: 16 (rows) * 16 (cols) = 256. 
                    //                 CALCULATE: 16 (rows) * 1 (cycle) = 16.
                    //                 Total = 273. Fits "~300".
                    //                 
                    //                 This is the best approach. 
                    //                 The prompt says "In LOAD_ROW state... pre-calculate horizontal link". 
                    //                 If we store the whole grid, we can't pre-calculate H_Links during load unless we store them too.
                    //                 We can store H_Links in 16x16 array, same size as grid.
                    //                 Or, we can calculate H_Links in the CALCULATE state for the current row.
                    //                 Given the prompt says "pre-calculate", maybe they expect us to do it during load.
                    //                 But doing it during load is easier if we process one row at a time.
                    //                 
                    //                 Let's stick to "Load All", but if we want to be strictly faithful to "pre-calculate", 
                    //                 we could store H_Links in a separate array `h_links_storage[16][16]`.
                    //                 Or, just calculate in CALCULATE state.
                    //                 
                    //                 Let's try to combine: 
                    //                 Load Row N -> `grid_storage`. 
                    //                 Calculate H_Links for Row N -> `h_links_storage`.
                    //                 
                    //                 This is fine. 
                    //                 
                    //                 Wait, the prompt says "Use a small internal table (e.g., 16 registers storing the destination column for each cell)".
                    //                 This sounds like it's for the CURRENT row being processed.
                    //                 "In LOAD_ROW state... store char and calculate horizontal link."
                    //                 So we calculate links during load.
                    //                 But if we load ALL first, we don't know which row is "current".
                    //                 Unless we fill `h_links_storage` while loading.
                    //                 
                    //                 Okay, let's assume we are allowed to store 16x16 grid of chars.
                    //                 And we calculate H_Links in CALCULATE state on the fly. 
                    //                 It's just 16 iterations, calculating 16 links takes time. 
                    //                 We want 1 cycle per row.
                    //                 So we need the links ready.
                    //                 
                    //                 So, let's store `h_links` in registers: `h_links [15:0][3:0]`.
                    //                 This is 16*16*4 bits = 1024 bits. Fine for ASIC.
                    //                 
                    //                 Implementation:
                    //                 1. Load rows. 
                    //                    Loop 15 to 0:
                    //                    `load_row` = row_idx.
                    //                    Read 16 chars.
                    //                    Store in `grid_storage[row_idx][col]`.
                    //                    Calculate `h_links[row_idx][col]` (destination col or 0xF).
                    //                 2. Calculate DP.
                    //                    Init Reachability for Row 15 (Wait, start col).
                    //                    Assume `start` comes first.
                    //                    
                    //                 How to catch `start` and `x_init`?
                    //                 `start` is a signal. 
                    //                 If `start` is high in IDLE, we latch `grid_row_idx` as `x_init`.
                    //                 Then go to LOAD_ROW (start loading row 15).
                    //                 
                    //                 What if `start` comes later?
                    //                 "Start computation". 
                    //                 So we should wait for `start`.
                    //                 
                    //                 Detailed FSM:
                    //                 
                    //                 IDLE:
                    //                   if (start) begin
                    //                     start_col <= grid_row_idx;
                    //                     current_row <= 15;
                    //                     next_state <= LOAD_ROW;
                    //                   end
                    //                 
                    //                 LOAD_ROW:
                    //                   // Request `current_row`.
                    //                   // Wait 16 cycles.
                    //                   // Store `grid_char` in `grid_storage[current_row][cycle_index]`.
                    //                   // Calculate `h_links[current_row][cycle_index]`.
                    //                   // Decrement `current_row` when done.
                    //                   // If `current_row` < 0, go to CALCULATE.
                    //                   // Else stay in LOAD_ROW.
                    //                   // Note: We need to count 16 cycles. Use a sub-counter `col_cnt`.
                    //                 
                    //                 CALCULATE:
                    //                   // Setup Reachability for Row 15.
                    //                   // Loop i from 15 down to 0:
                    //                   //   Horizontal Prop: Update Reachability/Counts in place (or to temp).
                    //                   //   Vertical Prop: 
                    //                   //     If row > 0:
                    //                   //       For each col, if reachable and grid[i-1][col] != '#', mark reachable in next row.
                    //                   //       If grid[i-1][col] == '@', accumulate result.
                    //                   //     Else (row 0):
                    //                   //       Just accumulate result for '@'.
                    //                   //   Move to next row.
                    //                   //   If Reachability is 0, break early.
                    //                   // End loop.
                    //                   // Goto FINISHED.
                    //                 
                    //                 This requires a loop inside CALCULATE state.
                    //                 Since we want 1 cycle per row, we need to unroll the loop or use a sub-state.
                    //                 But the prompt asks for states IDLE, LOAD_ROW, CALCULATE, CHECK_DONE.
                    //                 CHECK_DONE suggests an iterative process.
                    //                 
                    //                 Let's use CHECK_DONE to iterate the rows.
                    //                 
                    //                 IDLE -> LOAD_ROW (Load all) -> CALCULATE (One row step) -> CHECK_DONE (Loop) -> CALCULATE -> ... -> FINISHED.
                    //                 
                    //                 Wait, if we load all in LOAD_ROW, we have 16 rows.
                    //                 Then we need to process 16 rows.
                    //                 So:
                    //                 LOAD_ROW: Loads ALL rows (16x16). 
                    //                 Then goes to CALCULATE.
                    //                 CALCULATE: 
                    //                   // Current logic for one row step.
                    //                   // Compute Reachability/Cycles for Row N-1 from N.
                    //                   // Update `current_row` --.
                    //                 CHECK_DONE:
                    //                   // If `current_row` > 0, go back to CALCULATE? No.
                    //                   // We are in CALCULATE for row X.
                    //                   // We need to stay in CALCULATE or go to CHECK_DONE.
                    //                   // 
                    //                   // Let's define:
                    //                   // IDLE: Wait for start.
                    //                   // LOAD_ROW: Load the grid. 
                    //                   // CALCULATE: Process one step (Row N -> N-1).
                    //                   // CHECK_DONE: Check if done. If not, go to CALCULATE (next step).
                    //                   // But we need to know which row we are at.
                    //                   // 
                    //                   // If we use `current_row` as index (15 down to 0).
                    //                   // LOAD_ROW loads 15..0.
                    //                   // Then `current_row` becomes 15.
                    //                   // Init Reachability for Row 15.
                    //                   // 
                    //                   // CALCULATE:
                    //                   //   Process `current_row` -> `current_row - 1`.
                    //                   //   Store result if '@' found.
                    //                   //   Update Reachability for `current_row - 1`.
                    //                   //   `current_row` --.
                    //                   //   If `current_row` < 0 -> FINISHED.
                    //                   //   Else -> CHECK_DONE? Or back to CALCULATE?
                    //                   //   
                    //                   // Since we need to process 16 rows, we need 16 iterations.
                    //                   // Let's use CHECK_DONE as the branch point.
                    //                   // 
                    //                   // IDLE
                    //                   //   -> LOAD_ROW
                    //                   // LOAD_ROW (Load grid)
                    //                   //   -> PREP_DP (Init Row 15 reachability)
                    //                   //      (Wait, we need to do this once).
                    //                   //      Maybe we can do it in the first CALCULATE.
                    //                   // 
                    //                   // Let's add a PREP state implicitly to IDLE or LOAD_ROW exit.
                    //                   // 
                    //                   // Refined:
                    //                   // IDLE -> LOAD_ROW (Load grid, 256 cycles)
                    //                   // LOAD_ROW -> SETUP_DP
                    //                   // SETUP_DP -> CALCULATE (Row 15)
                    //                   // CALCULATE -> CHECK_DONE
                    //                   // CHECK_DONE -> CALCULATE (Row 14) or FINISHED
                    //                   // 
                    //                   // This adds a state. But the prompt allows IDLE, LOAD, CALC, CHECK.
                    //                   // We can merge SETUP_DP into the start of CALCULATE.
                    //                   // 
                    //                   // Let's try to minimize states.
                    //                   // 
                    //                   // IDLE -> LOAD_ROW
                    //                   // LOAD_ROW -> CALCULATE
                    //                   // CALCULATE -> CHECK_DONE
                    //                   // CHECK_DONE -> CALCULATE (if `current_row` > 0) or FINISHED.
                    //                   // 
                    //                   // We need a flag `grid_loaded`.
                    //                   // In LOAD_ROW, we load everything.
                    //                   // In CALCULATE, we process one row.
                    //                   // 
                    //                   // This requires a loop.
                    //                   // 
                    //                   // Alternative: 
                    //                   // LOAD_ROW: Loads ONE row. 
                    //                   // CALCULATE: Processes that row.
                    //                   // This requires a buffer for the row above.
                    //                   // 
                    //                   // Given the strict state definitions, and the "200-300 cycles", the "Load All" + "Iterate Calculation" is the most robust.
                    //                   // But we need to fit the states.
                    //                   // 
                    //                   // Let's define the states to allow a loop.
                    //                   // 
                    //                   // 1. IDLE: Wait start. Latch start_col.
                    //                   // 2. LOAD_ROW: Load 16 rows. (Use internal counter to track row index). Switch to CALC when done.
                    //                   // 3. CALCULATE: Process one step of DP (Row X -> X-1). Decrement row index.
                    //                   // 4. CHECK_DONE: If row index > 0, goto CALCULATE. Else goto FINISHED.
                    //                   // 
                    //                   // This fits the states if we use CHECK_DONE to loop.
                    //                   // 
                    //                   // Now, the "Start Column" input.
                    //                   // I will assume `start` signal comes with `grid_row_idx` as start column.
                    //                   // 
                    //                   // Let's refine the LOAD_ROW state.
                    //                   // We need to load 16 rows.
                    //                   // We use `current_row` as the row index to load.
                    //                   // We need a sub-counter for columns (0-15).
                    //                   // 
                    //                   // LOAD_ROW state logic:
                    //                   //   If `load_cnt` < 16:
                    //                   //     `load_row` = `current_row`.
                    //                   //     Wait for `grid_char` valid. (Assume valid every cycle).
                    //                   //     Store `grid_char` -> `grid_storage[current_row][load_cnt]`.
                    //                   //     Calculate `h_links[current_row][load_cnt]` -> `h_storage[current_row][load_cnt]`.
                    //                   //     `load_cnt`++.
                    //                   //   Else:
                    //                   //     `current_row`--.
                    //                   //     `load_cnt` = 0.
                    //                   //     If `current_row` < 0: Switch to CALCULATE.
                    //                   //     Else: Stay in LOAD_ROW (next row).
                    //                   // 
                    //                   // In CALCULATE state:
                    //                   //   This is tricky for 1 cycle per row.
                    //                   //   We need to:
                    //                   //    1. Horizontal propagation.
                    //                   //    2. Vertical propagation.
                    //                   //   If we do it in 1 cycle, we need combinational logic from `reachability_r` (Row X) to `next_reachability` (Row X-1).
                    //                   //   The combinational logic path will be long (16x16 lookups), but acceptable for "ASIC expert" sim.
                    //                   //   
                    //                   //   Logic:
                    //                   //    Input: `reachability_r` (Row X), `count_r` (Row X).
                    //                   //    Internal: `h_links[X][...]`, `grid_storage[X-1][...]`.
                    //                   //    Output: `next_reachability` (Row X-1), `next_count` (Row X-1).
                    //                   //    Also accumulate `result`.
                    //                   //   
                    //                   //   Wait, we need to access `h_links` for Row X (Source) and `grid_storage` for Row X-1 (Dest).
                    //                   //   We have `current_row` register. In CALCULATE state, `current_row` holds the index of the row we are transitioning FROM.
                    //                   //   So `h_links[current_row][c]` is valid.
                    //                   //   And `grid_storage[current_row - 1][c]` is valid.
                    //                   //   
                    //                   //   At the very end (Row 0 -> -1), `current_row` is 0.
                    //                   //   `grid_storage[-1]` is invalid.
                    //                   //   So in CALCULATE, if `current_row == 0`, we just check for '@' in Row 0 and update result.
                    //                   //   
                    //                   //   Update sequence:
                    //                   //   In CALCULATE (for Row `current_row`):
                    //                   //     // 1. Horizontal step on `reachability_r`.
                    //                   //     // 2. Vertical step to `next_reachability`.
                    //                   //     // 3. Update `reachability_r` and `count_r` to `next_reachability` and `next_count`.
                    //                   //     // 4. Accumulate `result`.
                    //                   //     // 5. `current_row`--.
                    //                   //   
                    //                   //   This logic runs in 1 cycle.
                    //                   //   CHECK_DONE then checks `current_row`.
                    //                   //   
                    //                   //   Wait, if we update `current_row` in CALCULATE, we don't need CHECK_DONE to loop.
                    //                   //   We can loop inside CALCULATE.
                    //                   //   But the states are defined as separate.
                    //                   //   So:
                    //                   //   CALCULATE: Perform one step (Row X -> X-1). 
                    //                   //   CHECK_DONE: Decrement `current_row`. If `current_row` >= 0 (and reachability != 0), go to CALCULATE.
                    //                   //                If `current_row` < 0 or reachability == 0, go to FINISHED.
                    //                   //   
                    //                   //   
                    //                   //   Let's write the code structure.
                    //                   //   
                    //                   //   We need to store `h_links` and `grid_storage`. 
                    //                   //   
                    //                   //   Let's implement.

    // Internal memory for Grid and Horizontal Links
    reg [7:0] grid_storage [0:15][0:15];
    reg [3:0] h_links [0:15][0:15];

    // Counters for loading
    reg [3:0] load_row_cnt; // Which row index we are loading
    reg [3:0] load_col_cnt; // Which column index we are loading
    
    // FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            load_row <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            result <= 24'd0;
            // Reset reachability/count
            reachability_r <= 16'b0;
            for (i = 0; i < 16; i = i + 1) count_r[i] <= 24'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    result <= 24'd0;
                    if (start) begin
                        // Latch start column from grid_row_idx (assumed usage)
                        reachability_r <= 16'b0;
                        reachability_r[grid_row_idx] <= 1'b1;
                        count_r[grid_row_idx] <= 24'd1;
                        
                        load_row_cnt <= 4'd15; // Start loading from row 15
                        load_col_cnt <= 4'd0;
                        current_row <= 4'd15; // Track current processing row (will be 15 initially)
                        
                        current_state <= LOAD_ROW;
                    end
                end

                LOAD_ROW: begin
                    // Assert load row request
                    load_row <= load_row_cnt;
                    
                    // We assume valid data arrives every cycle when load_row is asserted.
                    // Store data and calc links for the current column.
                    grid_storage[load_row_cnt][load_col_cnt] <= grid_char;
                    
                    // Pre-calculate horizontal link for this cell
                    if (grid_char == 8'h3C) begin // '<'
                        if (load_col_cnt > 0) h_links[load_row_cnt][load_col_cnt] <= load_col_cnt - 1;
                        else h_links[load_row_cnt][load_col_cnt] <= 4'hF;
                    end else if (grid_char == 8'h3E) begin // '>'
                        if (load_col_cnt < 15) h_links[load_row_cnt][load_col_cnt] <= load_col_cnt + 1;
                        else h_links[load_row_cnt][load_col_cnt] <= 4'hF;
                    end else begin
                        h_links[load_row_cnt][load_col_cnt] <= 4'hF;
                    end

                    // Increment column
                    if (load_col_cnt == 15) begin
                        // Finished this row
                        load_col_cnt <= 4'd0;
                        if (load_row_cnt == 0) begin
                            // Finished all rows. Switch to Calculation.
                            current_state <= CHECK_DONE;
                            // Reset current_row to 15 to start processing from top down (wait, we go from 15 to 0)
                            // We need to process Row 15 first.
                            // But we just loaded row 0. We have rows 0..15 stored.
                            // We should set current_row to 15 here.
                            current_row <= 4'd15;
                        end else begin
                            load_row_cnt <= load_row_cnt - 1;
                        end
                    end else begin
                        load_col_cnt <= load_col_cnt + 1;
                    end
                end

                CALCULATE: begin
                    // This state performs one DP step: Row current_row -> current_row - 1
                    // Input: reachability_r (for current_row), count_r (for current_row)
                    // Process:
                    // 1. Horizontal propagation on current_row
                    // 2. Vertical propagation to current_row - 1 (unless current_row == 0)
                    // 3. Update result if '@' found
                    
                    // We need combinational logic here. 
                    // To save space, let's do it sequentially in this block (takes 1 cycle)
                    // But that requires multiple assignments. 
                    // Let's rely on the comb logic block `calc_logic` to compute `next_reachability` etc.
                    // And we update registers here.
                    
                    // The combinational block calculates:
                    //  next_reachability_reg
                    //  next_count_reg
                    //  accumulated_result_add
                    
                    // Update registers
                    reachability_r <= next_reachability;
                    for (i = 0; i < 16; i = i + 1) begin
                        count_r[i] <= next_count[i];
                    end
                    
                    // Update result (accumulate)
                    result <= result + accumulated_result_add;
                    
                    // Decrement row counter to point to next source row? 
                    // No, `current_row` tracks the SOURCE row we just processed.
                    // After processing Row X, we want to process Row X-1.
                    // So we decrement `current_row`.
                    // In the next cycle (CHECK_DONE), we check if we should continue.
                    current_row <= current_row - 1;
                    
                    current_state <= CHECK_DONE;
                end

                CHECK_DONE: begin
                    // Check if we should continue
                    if (current_row == 15) begin
                        // Just finished LOAD_ROW. 
                        // Wait, we transitioned from LOAD_ROW to CHECK_DONE.
                        // So `current_row` is still 15 (set in LOAD_ROW exit).
                        // We need to start the DP.
                        // But we haven't processed anything yet.
                        // So we should go to CALCULATE.
                        current_state <= CALCULATE;
                    end else if (current_row < 15 && current_row != 0 && current_row != 15) begin
                        // Normal iteration.
                        // `current_row` was decremented in CALCULATE.
                        // If it is 14, we need to process Row 14.
                        // So we go to CALCULATE.
                        current_state <= CALCULATE;
                    end else if (current_row == 0) begin
                        // We just finished processing Row 1 -> 0.
                        // `current_row` is now 0.
                        // We need to process Row 0 (final check for '@').
                        // Row 0 doesn't propagate to -1.
                        // So we do a special CALCULATE step for Row 0.
                        // Or we handle it here? 
                        // Let's go to CALCULATE for the final step.
                        // But wait, CALCULATE expects to decrement current_row.
                        // If we go to CALCULATE with current_row = 0, it decrements to -1 (which is 15 in 4-bit wrap? No, signed check needed).
                        // Let's handle Row 0 logic in a separate state or modify CALCULATE.
                        // 
                        // Actually, the logic for Row 0 is:
                        // Horizontal move on Row 0.
                        // Check for '@' in Row 0.
                        // No vertical move.
                        // 
                        // Let's modify CALCULATE to handle current_row == 0 differently.
                        // 
                        // So, if we come to CHECK_DONE with `current_row` == 0 (meaning we just did Row 1 -> 0), 
                        // we need to do the final horizontal scan of Row 0.
                        // 
                        // Wait, the loop structure is:
                        // 1. Row 15 (Init Reachability).
                        // 2. Calc Row 15 -> 14.
                        // 3. Calc Row 14 -> 13.
                        // ...
                        // 15. Calc Row 1 -> 0.
                        // 16. Calc Row 0 -> Stop.
                        // 
                        // If `current_row` tracks the SOURCE row:
                        // After LOAD_ROW, `current_row` = 15.
                        // CHECK_DONE -> CALCULATE (process 15).
                        // CALCULATE decrements `current_row` to 14. -> CHECK_DONE.
                        // CHECK_DONE -> CALCULATE (process 14).
                        // ...
                        // When `current_row` is 1. CHECK_DONE -> CALCULATE (process 1).
                        // CALCULATE decrements `current_row` to 0. -> CHECK_DONE.
                        // Now `current_row` is 0. We still need to process Row 0.
                        // So CHECK_DONE should go to CALCULATE if `current_row` >= 0.
                        // But wait, when `current_row` is 0, what does CALCULATE do?
                        // It calculates transition to -1 (Row -1).
                        // 
                        // We need a special handling or a flag.
                        // Let's add a flag `final_row` or check in CALCULATE.
                        // Or, we can process Row 0 in CHECK_DONE.
                        // 
                        // Let's define:
                        // If `current_row` == 0 after decrement: 
                        //   Perform final horizontal check on Row 0 (accumulate '@').
                        //   Then Goto FINISHED.
                        // 
                        // But we are in CHECK_DONE. 
                        // We need to execute the logic. 
                        // Maybe we can reuse the CALCULATE combinational logic.
                        // 
                        // Let's change logic:
                        // If `current_row` < 15: go to CALCULATE.
                        // If `current_row` == 0: go to CALCULATE (special mode).
                        // 
                        // Wait, if we just finished LOAD_ROW, `current_row` is 15.
                        // So we go to CALCULATE.
                        // 
                        // Let's check the decrement logic.
                        // CALCULATE decrements `current_row`.
                        // So:
                        // Loop 1: `current_row`=15. Calc 15->14. Decrement to 14.
                        // Loop 2: `current_row`=14. Calc 14->13. Decrement to 13.
                        // ...
                        // Loop 15: `current_row`=1. Calc 1->0. Decrement to 0.
                        // Loop 16: `current_row`=0. Calc 0->-1 (ignore vertical). Decrement to -1 (15).
                        // 
                        // If `current_row` becomes 15 (from -1), we should stop.
                        // 
                        // So in CHECK_DONE:
                        // If `current_row` == 15 (and we didn't just start), we are done.
                        // 
                        // But we start at 15.
                        // 
                        // Let's use a `steps_completed` counter.
                        // We need to process 16 steps (Row 15 to 0).
                        // 
                        // Let's use a flag `started_calc`.
                        // 
                        // Better: use `current_row` as index 15..0.
                        // In CHECK_DONE:
                        //   If `current_row` < 15: 
                        //     If `current_row` != 0: Goto CALCULATE.
                        //     If `current_row` == 0: Goto CALCULATE (and finish after).
                        //   If `current_row` == 15 (first time) -> Goto CALCULATE.
                        //   If `current_row` == 15 (second time, wrapped?) -> Finish.
                        // 
                        // Let's use a separate counter `dp_step`.
                        // 
                        // Let's simplify. 
                        // 16 steps of calculation.
                        // We can just count 16 steps.
                        // 
                        // Let's go with: 
                        // CHECK_DONE:
                        //   If `current_row` == 15: 
                        //     (Means just finished load).
                        //     `current_row` stays 15.
                        //     Goto CALCULATE.
                        //   Else if `current_row` > 0:
                        //     `current_row` is already decremented.
                        //     Goto CALCULATE.
                        //   Else if `current_row` == 0:
                        //     Goto CALCULATE (Final step).
                        //   Else (if we decrement to 15...)
                        //     Wait, decrement 0 -> 15 (unsigned wrap). 
                        //     We need to prevent wrap.
                        //     So we check `current_row` == 0 before entering CALCULATE.
                        //     In CALCULATE, if `current_row` == 0, we don't decrement, we go to FINISHED.
                        //     
                        //     Revised:
                        //     CHECK_DONE:
                        //       If `current_row` == 15: Goto CALCULATE (Start).
                        //       Else if `current_row` != 0: Goto CALCULATE (Middle).
                        //       Else: Goto FINISHED (End).
                        //       
                        //     CALCULATE:
                        //       If `current_row` == 0:
                        //         // Final row processing (no vertical move)
                        //         // Accumulate '@'
                        //         result = result + sum_horizontal_at_row_0
                        //         // Then in sequential block, we set `current_row` to something non-zero to stop loop?
                        //         // Or just rely on CHECK_DONE to see 0.
                        //         // But CHECK_DONE sees 0 and goes to FINISHED.
                        //         // So CALCULATE for row 0 should not decrement `current_row`.
                        //         // 
                        //       Else:
                        //         // Normal transition
                        //         // Update result (accumulate '@' of Row X-1? No, accumulate at the landing row).
                        //         // Actually, accumulate if Row X-1 is '@'.
                        //         // Update reachability for Row X-1.
                        //         // Decrement `current_row`.
                        //         
                        //     Wait, we need to know when to accumulate.
                        //     When we transition from X to X-1, we land on Row X-1.
                        //     So we check Row X-1 for '@'.
                        //     If Row X-1 is '@', add the paths reaching it to `result`.
                        //     But we also need to continue paths that are not '@'?
                        //     "If a cell is '@', it is the target (valid path ends here)."
                        //     So paths reaching '@' stop.
                        //     So we should:
                        //       1. Calculate reachability of Row X-1.
                        //       2. Filter out columns where Row X-1 is '@'.
                        //       3. Add count of those columns to `result`.
                        //       4. Set reachability of those columns to 0 for next step.
                        //       
                        //     This is complex for 1 cycle.
                        //     Let's do:
                        //       - Accumulate result for '@' in the transition.
                        //       - Do NOT propagate from '@' (set reachability to 0).
                        //       
                        //     So the logic in CALCULATE (for Row X -> X-1)
                        //     1. Horizontal propagation on Row X.
                        //     2. Vertical propagation to Row X-1.
                        //       - If Row X-1 char == '#', block.
                        //       - If Row X-1 char == '@', add to `accumulated_result_add`, set reachable to 0 for next step.
                        //       - Else, keep reachable.
                        //       
                        //     This works.
                        //     
                        //     For Row 0 (Final):
                        //     We are in Row 0 (Source).
                        //     Horizontal propagation on Row 0.
                        //     We check if any column is '@'.
                        //     Add to result.
                        //     No vertical move.
                        //     Then Done.
                        //     
                        //     So in CHECK_DONE:
                        //       If `current_row` == 15 -> CALCULATE.
                        //       Else if `current_row` > 0 -> CALCULATE.
                        //       Else if `current_row` == 0 -> CALCULATE (but treat as final).
                        //       
                        //     How does CALCULATE know it's final? 
                        //     By `current_row` value.
                        //     
                        //     In CALCULATE sequential block:
                        //       if (current_row == 0):
                        //         // Just update result. (We already processed vertical move to 0 in the step 1->0).
                        //         // Actually, the transition 1->0 lands on 0. So we check for '@' in 0.
                        //         // Wait. 
                        //         // Step 15: current_row = 1. Transition 1->0. Check Row 0. Update reachability for Row 0.
                        //         // Step 16: current_row = 0. Transition 0->-1.
                        //         // 
                        //         // We need to check Row 0 for '@' in Step 15 (landing on 0).
                        //         // In Step 16 (Src 0), we need to check for '@' in Row 0 (paths starting at 0 or horizontal moves ending at 0).
                        //         // 
                        //         // So:
                        //         // Step 15 (Src 1): Update Reachability (Row 0). Add '@' counts to result. Mask '@' in reachability.
                        //         // Step 16 (Src 0): Horizontal Prop. Check '@' in Row 0. Add to result. Mask.
                        //         // Then Done.
                        //         // 
                        //         // So we need to run CALCULATE with `current_row` = 15, 14, ..., 0.
                        //         // Total 16 steps.
                        //         // 
                        //         // So CHECK_DONE loops until `current_row` reaches a terminal state.
                        //         // 
                        //         // Let's use a counter `step`.
                        //         // Actually, `current_row` is enough.
                        //         // We start at 15.
                        //         // We go down to 0.
                        //         // In CHECK_DONE:
                        //         //   If `current_row` == 15 (first call): Goto CALCULATE.
                        //         //   If `current_row` > 0: Decrement `current_row`? No, done in CALCULATE.
                        //         //   Wait, we decrement in CALCULATE.
                        //         //   So we just check if we should stop.
                        //         //   
                        //         //   If `current_row` becomes 0 in CALCULATE (after processing 1->0),
                        //         //   then CHECK_DONE sees 0. 
                        //         //   We still need to process Row 0 (Source).
                        //         //   So CHECK_DONE sees 0, goes to CALCULATE.
                        //         //   In CALCULATE, if `current_row` is 0, it does the final horizontal step and stops.
                        //         //   Then we need to set `current_row` to something to break the loop.
                        //         //   Let's set `current_row` to 16 (invalid) in CALCULATE after final step.
                        //         //   Then CHECK_DONE sees 16, goes to FINISHED.
                        //         // 
                        //         //   
                        //         //   Wait, we need to update `reachability_r` for Row 0 in the step 1->0.
                        //         //   Then in step 0->-1 (which we skip), we don't use it.
                        //         //   Actually, we need to process horizontal moves on Row 0.
                        //         //   Horizontal moves on Row 0 don't depend on Row -1.
                        //         //   So step 0->-1 is just horizontal propagation on Row 0.
                        //         //   
                        //         //   So we need 16 iterations of CALCULATE.
                        //         //   Index 15, 14, ..., 0.
                        //         //   
                        //         //   CHECK_DONE:
                        //         //     If `current_row` < 16: Goto CALCULATE.
                        //         //     Else: Goto FINISHED.
                        //         //   
                        //         //   In CALCULATE:
                        //         //     1. Horizontal Prop on Row `current_row` (using `reachability_r`).
                        //         //     2. If `current_row` > 0:
                        //         //        Vertical Prop to Row `current_row - 1`. 
                        //         //        Check Row `current_row - 1` for '#', '@'.
                        //         //        Update `next_reachability` for Row `current_row - 1`.
                        //         //     3. If `current_row` == 0:
                        //         //        Final Horizontal Prop Result is the result.
                        //         //        (But we also have accumulated results from previous steps).
                        //         //     4. Decrement `current_row`.
                        //         //        
                        //         //     Wait, `reachability_r` stores reachability for Row `current_row`.
                        //         //     After Calc, `reachability_r` becomes reachability for Row `current_row - 1` (if `current_row > 0`).
                        //         //     If `current_row` == 0, we are done.
                        //         //     
                        //         //     So:
                        //         //     CALCULATE:
                        //         //       Logic: (Comb logic)
                        //         //       In -> `reachability_r` (Row X).
                        //         //       Out -> `next_reachability` (Row X-1) or Final Result.
                        //         //       
                        //         //     Sequential in CALC:
                        //         //       if (current_row > 0):
                        //         //         reachability_r <= next_reachability;
                        //         //         result <= result + accumulated_at_X_minus_1;
                        //         //         current_row <= current_row - 1;
                        //         //       else:
                        //         //         // Final step for Row 0.
                        //         //         result <= result + accumulated_at_0;
                        //         //         current_row <= 16; // Terminate
                        //         //         
                        //         //     This works.
                        //         //     
                        //         //     CHECK_DONE:
                        //         //       if (current_row == 16) goto FINISHED.
                        //         //       else goto CALCULATE.
                        //         //       
                        //         //     Initial:
                        //         //       IDLE: current_row = 15. reachability_r = {start_col}.
                        //         //       goto LOAD_ROW? No, we loaded all in LOAD_ROW.
                        //         //       
                        //         //     Wait, we loaded all in LOAD_ROW.
                        //         //     So after LOAD_ROW, current_row = 15.
                        //         //     CHECK_DONE sees 15 (< 16). goto CALCULATE.
                        //         //     
                        //         //     This looks correct.
                        //         //     
                        //         //     Let's implement the combinational logic.

    // Combinational Logic for DP Transition
    // Computes: 
    //  1. Horizontal propagation of `reachability_r` and `count_r`.
    //  2. Vertical propagation to row-1 (if row > 0).
    //  3. Accumulated result.
    
    reg [15:0] temp_reach;
    reg [23:0] temp_count [0:15];
    reg [23:0] temp_acc_result;
    
    integer c;
    reg [3:0] link_dest;
    reg [7:0] dest_char;
    
    always @(*) begin
        // Default
        next_reachability = 16'b0;
        for (c = 0; c < 16; c = c + 1) next_count[c] = 24'd0;
        accumulated_result_add = 24'd0;
        
        // 1. Horizontal Propagation on Row X (current_row)
        // Initialize temp arrays
        temp_reach = 16'b0;
        for (c = 0; c < 16; c = c + 1) temp_count[c] = 24'd0;
        
        for (c = 0; c < 16; c = c + 1) begin
            if (reachability_r[c]) begin
                // Cell is reachable
                if (grid_storage[current_row][c] == 8'h23) begin
                    // Blocked. Do nothing.
                end else if (grid_storage[current_row][c] == 8'h3C || grid_storage[current_row][c] == 8'h3E) begin
                    // Current. Follow link.
                    link_dest = h_links[current_row][c];
                    if (link_dest != 4'hF) begin
                        temp_reach[link_dest] = 1'b1;
                        temp_count[link_dest] = temp_count[link_dest] + count_r[c];
                        if (temp_count[link_dest] >= MOD) temp_count[link_dest] = temp_count[link_dest] - MOD;
                    end
                end else begin
                    // Open or Castle. Stay.
                    temp_reach[c] = 1'b1;
                    temp_count[c] = temp_count[c] + count_r[c];
                    if (temp_count[c] >= MOD) temp_count[c] = temp_count[c] - MOD;
                end
            end
        end
        
        // 2. Vertical Propagation (or Final Accumulation)
        if (current_row > 0) begin
            // Propagate to Row current_row - 1
            for (c = 0; c < 16; c = c + 1) begin
                if (temp_reach[c]) begin
                    dest_char = grid_storage[current_row - 1][c];
                    if (dest_char == 8'h23) begin
                        // Blocked below. Do nothing.
                    end else if (dest_char == 8'h40) begin
                        // Castle '@'. Valid path ends here.
                        accumulated_result_add = accumulated_result_add + temp_count[c];
                        if (accumulated_result_add >= MOD) accumulated_result_add = accumulated_result_add - MOD;
                        // Do not propagate reachability.
                    end else begin
                        // Open, Current, or any other valid. Propagate.
                        next_reachability[c] = 1'b1;
                        next_count[c] = next_count[c] + temp_count[c];
                        if (next_count[c] >= MOD) next_count[c] = next_count[c] - MOD;
                    end
                end
            end
        end else begin
            // current_row == 0. Final horizontal check.
            for (c = 0; c < 16; c = c + 1) begin
                if (temp_reach[c]) begin
                    if (grid_storage[0][c] == 8'h40) begin
                        accumulated_result_add = accumulated_result_add + temp_count[c];
                        if (accumulated_result_add >= MOD) accumulated_result_add = accumulated_result_add - MOD;
                    end
                end
            end
            // No next_reachability. It stays zero.
        end
    end

                CHECK_DONE: begin
                    if (current_row < 16) begin // Valid state (15 down to 0)
                        current_state <= CALCULATE;
                    end else begin // current_row is 16 (finished flag)
                        current_state <= FINISHED;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    // Result already updated in CALCULATE
                    // Stay in FINISHED
                end
            endcase
        end
    end

endmodule
