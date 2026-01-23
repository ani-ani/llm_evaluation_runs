module bureaucrat_stamp(
    input clk,
    input rst_n,
    input start,
    input [0:7][0:7] paper_grid,
    output reg [7:0] min_nubs,
    output reg done
);

    // State definitions
    localparam IDLE = 0;
    localparam INIT = 1;
    localparam CALC_OFFSET = 2;
    localparam COMPUTE_STAMP = 3;
    localparam MIN_UPDATE = 4;
    localparam NEXT_OFFSET = 5;
    localparam DONE = 6;

    // Registers for state machine
    reg [2:0] state;
    reg [2:0] next_state;

    // Offset counters (9-bit signed)
    reg signed [8:0] dx;
    reg signed [8:0] dy;

    // Current minimum and temporary calculation
    reg [7:0] current_min;
    reg [7:0] temp_size;

    // Grid mapping logic for chain tracing
    // We treat the 8x8 grid as a linear array of 64 bits for easier iteration
    // paper_grid[row][col] -> index = row * 8 + col
    wire [63:0] p_flat;
    genvar r, c;
    generate
        for (r = 0; r < 8; r = r + 1) begin : gen_flat
            for (c = 0; c < 8; c = c + 1) begin : gen_col
                // paper_grid is defined as [0:7][0:7], so paper_grid[row][col]
                assign p_flat[r*8 + c] = paper_grid[r][c];
            end
        end
    endgenerate

    // Chain tracing registers and logic
    reg [63:0] visited;       // Tracks visited '#' in current offset computation
    reg [63:0] local_grid;    // Stores grid bits for current offset check
    reg [63:0] current_chain_mask; // Mask of current chain being traced
    reg signed [8:0] curr_dx; // Stored dx for chain tracing
    reg signed [8:0] curr_dy; // Stored dy for chain tracing
    
    reg [2:0] compute_step;   // Sub-state for COMPUTE_STAMP
    reg [5:0] scan_idx;       // Index for scanning grid
    
    // Chain tracing temp variables
    reg signed [8:0] fwd_dx, fwd_dy;
    reg signed [8:0] bwd_dx, bwd_dy;
    reg [5:0] curr_idx;
    reg [3:0] fwd_count;
    reg [3:0] bwd_count;
    reg signed [8:0] next_x, next_y;
    reg signed [8:0] prev_x, prev_y;
    
    // Bounds checking registers
    reg signed [8:0] min_row, max_row, min_col, max_col;
    reg signed [8:0] min_row_shift, max_row_shift, min_col_shift, max_col_shift;
    reg bounds_valid;

    // State transition logic
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
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = CALC_OFFSET;
            CALC_OFFSET: next_state = bounds_valid ? COMPUTE_STAMP : NEXT_OFFSET;
            COMPUTE_STAMP: begin
                // Logic for Compute step progression
                // We use compute_step to handle the nested loops logic
                // Step 0: Init scan, Step 1: Find Start, Step 2: Trace, Step 3: Add
                if (compute_step == 3'd3)
                    next_state = MIN_UPDATE;
                else
                    next_state = COMPUTE_STAMP;
            end
            MIN_UPDATE: next_state = NEXT_OFFSET;
            NEXT_OFFSET: begin
                // Check if done with all offsets inside NEXT_OFFSET block logic
                // Here we just return to CALC_OFFSET to re-evaluate the check
                next_state = CALC_OFFSET;
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
        
        // Override for finish condition in NEXT_OFFSET logic which is handled in sequential block
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_nubs <= 8'd0;
            done <= 1'b0;
            current_min <= 8'd255;
            temp_size <= 8'd0;
            dx <= -8'sd8;
            dy <= -8'sd8;
            compute_step <= 3'd0;
            visited <= 64'd0;
            scan_idx <= 6'd0;
            fwd_count <= 4'd0;
            bwd_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Resetting happens in INIT usually, but we ensure clean slate
                    end
                end

                INIT: begin
                    // Initialize offset counters and min
                    dx <= -8'sd8;
                    dy <= -8'sd8;
                    current_min <= 8'd255; // Max possible nubs (8x8 full)
                    temp_size <= 8'd0;
                    // Prepare local copy of grid flattened
                    // Since input is wire, we just read p_flat when needed, 
                    // but for visited clearing we do it in CALC_OFFSET or COMPUTE_STAMP start
                end

                CALC_OFFSET: begin
                    // Check bounds validity
                    // We calculate bounds here or rely on pre-calc. Since we need to check validity:
                    // Valid if: 
                    // 1. All '#' in paper_grid are in [0,7] (always true)
                    // 2. All '#' + (dx, dy) are in [0,7]
                    // To do this efficiently in hardware without checking all 64 bits every time is hard.
                    // We will check all 64 bits. 
                    // However, doing this in 1 cycle is heavy. 
                    // Let's split bounds checking. Or, we can do it in a loop.
                    // For this architecture, we will assume a single cycle check or pre-calc.
                    // Given the instruction "Optimize by pre-computing", but we are in sequential logic.
                    // Let's implement the bounds check logic here.
                    
                    // To keep it fast, we can check bits 0-63 incrementally or do a big combinational check.
                    // Given the 10k cycle budget, we can take multiple cycles for bounds check if needed.
                    // But CALC_OFFSET is a state. Let's do the check here.
                    // We will use a 'helper' block or assume valid initially.
                    // Wait, the state machine description says "If yes, go to COMPUTE_STAMP, else go to NEXT_OFFSET".
                    // This implies it's a decision point. 
                    
                    // Optimization: Check if (dx, dy) fits. 
                    // Min Row of '#' in paper. Max Row, Min Col, Max Col.
                    // Pre-calculate min/max of the static paper_grid? 
                    // Since the grid changes with start, we can't pre-calc once.
                    // Let's pre-calc bounds of '#' in IDLE/INIT using a counter.
                    // But we have no sub-states in INIT.
                    // Let's do the bounds check iteratively during NEXT_OFFSET or CALC_OFFSET.
                    // Actually, let's do it iteratively in CALC_OFFSET using a counter.
                    // But to keep state machine simple as per description, let's assume we can do it or delegate to logic.
                    
                    // Revised approach for bounds:
                    // We will implement a separate counter `bound_check_idx` if needed, but for simplicity,
                    // we will do the check in the NEXT_OFFSET logic or a helper always block.
                    // Let's use the `bounds_valid` signal generated by a combinational block.
                end

                COMPUTE_STAMP: begin
                    case (compute_step)
                        3'd0: begin // Initialize for chain trace
                            visited <= 64'd0;
                            scan_idx <= 6'd0;
                            temp_size <= 8'd0;
                            curr_dx <= dx;
                            curr_dy <= dy;
                            compute_step <= 3'd1;
                        end
                        3'd1: begin // Find next unvisited '#'
                            // Look for '#' in local_grid (paper_grid) that is not in visited
                            if (scan_idx < 64) begin
                                if (p_flat[scan_idx] && !visited[scan_idx]) begin
                                    // Found start of chain
                                    visited[scan_idx] <= 1'b1;
                                    fwd_count <= 4'd1; // Count itself
                                    bwd_count <= 4'd0;
                                    curr_idx <= scan_idx;
                                    compute_step <= 3'd2; // Trace forward
                                end else begin
                                    scan_idx <= scan_idx + 1;
                                end
                            end else begin
                                // Done scanning all positions
                                compute_step <= 3'd3; // Finish up
                            end
                        end
                        3'd2: begin // Trace Chain
                            // 2a: Trace Forward (Fwd direction)
                            // 2b: Trace Backward (Bwd direction)
                            // We need to handle two directions. Let's do forward first then backward.
                            // Let's split step 2 into sub-sub-steps or do it in one go with counters.
                            // Let's use a flag to distinguish fwd vs bwd.
                            // Actually, let's do forward tracing in step 2.
                            // Then transition to a new step for backward.
                            
                            // Forward Tracing Logic
                            // Calculate next index based on curr_dx, curr_dy
                            // If curr_idx is row*8+col. row=idx/8, col=idx%8.
                            // Next row = row + dy, Next col = col + dx.
                            // Check bounds [0,7]. Check if '1' in paper_grid and not visited.
                            // If yes: update curr_idx, increment fwd_count, mark visited.
                            // If no: stop forward.
                            
                            // Let's do forward trace first.
                            // We need to know if we are doing fwd or bwd. Let's use a register.
                            // I'll use `bwd_count` as a flag. If 0, we are in fwd. If 1, we are in bwd.
                            // No, `bwd_count` is counter. 
                            // Let's add `trace_dir` register (0=fwd, 1=bwd).
                            // Or, just do Fwd in Step 2, then Step 3 Backward.
                            // Let's add a step 4 for Finalize chain.
                            // Steps: 0:Init, 1:FindStart, 2:FwdTrace, 3:BwdTrace, 4:AddSize, 5:NextScan
                            // Update state machine logic above if changing steps.
                            // Keeping it simple: We trace forward until dead end. Then we need to start over for backward from the original start.
                            // But we need the original start index. 
                            // Let's keep `start_idx` register.
                            // Let's do:
                            // Step 2: Trace Forward from start_idx. Update `fwd_count`. Mark visited.
                            // Step 3: Trace Backward from start_idx. Update `bwd_count`. Mark visited.
                            // Step 4: Add to temp_size.
                        end
                    endcase
                    
                    // Refactoring the compute steps for clarity in implementation
                end
                
                MIN_UPDATE: begin
                    if (temp_size < current_min) begin
                        current_min <= temp_size;
                    end
                end
                
                NEXT_OFFSET: begin
                    // Increment logic
                    if (dy < 8'sd7) begin
                        dy <= dy + 1;
                    end else begin
                        dy <= -8'sd8;
                        if (dx < 8'sd7) begin
                            dx <= dx + 1;
                        end else begin
                            // Done with all offsets, go to DONE
                            // Need to signal this to next_state logic, but next_state is already set to CALC_OFFSET.
                            // We need to override next_state here or check condition in CALC_OFFSET.
                            // Let's add a check here for the loop termination.
                            // We can set a flag or just force state transition.
                        end
                    end
                end
                
                DONE: begin
                    min_nubs <= current_min;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Logic for NEXT_OFFSET termination and Bounds Check
    // We need to inject logic to check if dx > 7 in NEXT_OFFSET to go to DONE.
    // Also need Bounds Check for CALC_OFFSET.
    // Since we can't change next_state from the always block easily after assigning it, 
    // let's handle the loop termination in the NEXT_OFFSET block logic.
    
    // Re-evaluating NEXT_OFFSET in sequential block for loop termination:
    always @(posedge clk or negedge rst_n) begin
        if (rst_n && state == NEXT_OFFSET) begin
            // If we just finished incrementing and dx > 7, we are done.
            // But we increment in this block.
            // If dx was 7 and dy was 7, we increment dy to 8 (which becomes -8), then dx to 8.
            // Wait, dx > 7 check should happen *after* increment.
            // If dx becomes 8, we go to DONE.
            if (dx == 8'sd8) begin
                // We have looped past the end.
                // Force state to DONE in next cycle? No, state has already transitioned to CALC_OFFSET (from next_state logic).
                // This is tricky with the provided state machine description.
                // The description says: "If dx > 7, go to DONE" inside NEXT_OFFSET.
                // So NEXT_OFFSET should transition to DONE if done.
                // And to CALC_OFFSET otherwise.
                // So `next_state` logic needs to see the updated dx/dy or future values.
                // Since we update dx/dy in NEXT_OFFSET block, and next_state is evaluated combinationaly before the block executes.
                // We need to compute `next_state` based on the *result* of the increment.
                // This requires combinational logic on dx, dy or sequential logic.
            end
        end
    end

    // Correct approach for termination: 
    // In NEXT_OFFSET state:
    // 1. Increment counters.
    // 2. If incremented dx > 7, next_state = DONE.
    // 3. Else next_state = CALC_OFFSET.
    // But we are updating registers in the clocked block.
    // So we need to check the *current* values in the combinational block for next_state.
    // But current values are pre-increment.
    // Solution: Check if (dx == 7 && dy == 7) *before* increment. 
    // If so, increment is the last one.
    // If (dx == 7 && dy == 7), after increment dy=-8, dx=8. 
    // So we need to detect this edge.
    // Let's modify the NEXT_OFFSET state logic in the combinational block.

    // Redefining NEXT_OFFSET transition:
    // If we are at the last offset (dx=7, dy=7), we increment to dx=8, dy=-8.
    // So we need to transition to DONE if we *have* reached dx=8.
    // But combinational block sees dx as is (pre-increment).
    // We can calculate the *next* dx/dy in the combinational block.
    
    // Helper combinational logic for Next Offset State
    reg [2:0] next_dx_calc;
    reg [2:0] next_dy_calc;
    reg       will_finish;

    always @(*) begin
        // Predict next offset
        if (dy < 8'sd7) begin
            next_dy_calc = dy + 1;
            next_dx_calc = dx;
        end else begin
            next_dy_calc = -8'sd8;
            if (dx < 8'sd7) begin
                next_dx_calc = dx + 1;
            end else begin
                next_dx_calc = dx + 1; // This will be 8
            end
        end
        will_finish = (next_dx_calc > 8'sd7);
    end

    // Update Next State Logic for NEXT_OFFSET
    // We need to inject this into the main next_state logic.
    // Since we defined it once, let's overwrite or just ensure the combinational logic is correct.
    // Actually, let's rewrite the `always @(*)` for `next_state` to include this logic explicitly.

    always @(*) begin
        case (state)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = CALC_OFFSET;
            
            CALC_OFFSET: begin
                if (bounds_valid)
                    next_state = COMPUTE_STAMP;
                else
                    next_state = NEXT_OFFSET;
            end
            
            COMPUTE_STAMP: begin
                // Detailed step handling
                if (compute_step == 3'd0) next_state = COMPUTE_STAMP;
                else if (compute_step == 3'd1) next_state = COMPUTE_STAMP;
                else if (compute_step == 3'd2) next_state = COMPUTE_STAMP; // Forward Trace
                else if (compute_step == 3'd3) next_state = COMPUTE_STAMP; // Backward Trace
                else if (compute_step == 3'd4) next_state = MIN_UPDATE;    // Add Size (clean up)
                else next_state = COMPUTE_STAMP;
                // Note: We need to refine `compute_step` to cover Fwd, Bwd, Add.
            end
            
            MIN_UPDATE: next_state = NEXT_OFFSET;
            
            NEXT_OFFSET: begin
                if (will_finish) 
                    next_state = DONE;
                else 
                    next_state = CALC_OFFSET;
            end
            
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Bounds Check Logic (Combinational)
    // Calculate min/max row/col of '#' in paper_grid.
    // Then check if shifted grid fits.
    // We can optimize by checking the condition on the fly.
    // Since paper_grid is input, we can compute bounds in the combinational block.
    // Or we can compute them once in INIT and store them.
    // Given the sequential nature, let's compute them in a combinational block for CALC_OFFSET.
    // Since inputs are `reg` (per instructions, inputs are assumed reg unless specified), 
    // actually inputs are wires. We can use them directly.
    
    integer i, j;
    reg signed [8:0] p_min_row, p_max_row, p_min_col, p_max_col;
    reg has_pixel;

    always @(*) begin
        p_min_row = 9'sd8;
        p_max_row = -9'sd1;
        p_min_col = 9'sd8;
        p_max_col = -9'sd1;
        has_pixel = 1'b0;

        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (paper_grid[i][j]) begin
                    has_pixel = 1'b1;
                    if (i < p_min_row) p_min_row = i;
                    if (i > p_max_row) p_max_row = i;
                    if (j < p_min_col) p_min_col = j;
                    if (j > p_max_col) p_max_col = j;
                end
            end
        end
        
        // If no pixels, validity doesn't matter much, but assume valid
        if (!has_pixel) begin
            p_min_row = 0; p_max_row = 0; p_min_col = 0; p_max_col = 0;
        end
    end

    always @(*) begin
        // Stamp 1: fits in [0,7]x[0,7] (Input constraint implies this, but check anyway)
        // Stamp 2: Shifted by (dx, dy).
        // We require: 0 <= p_min_row + dy <= 7 AND 0 <= p_max_row + dy <= 7
        // AND 0 <= p_min_col + dx <= 7 AND 0 <= p_max_col + dx <= 7
        
        if (has_pixel) begin
            if ( (p_min_row + dy >= 0) && (p_max_row + dy <= 7) &&
                 (p_min_col + dx >= 0) && (p_max_col + dx <= 7) ) begin
                bounds_valid = 1'b1;
            end else begin
                bounds_valid = 1'b0;
            end
        end else begin
            // Empty grid is valid for any offset (though no nubs needed)
            bounds_valid = 1'b1;
        end
    end

    // COMPUTE_STAMP Sub-states Logic
    // We need to add `trace_dir` or similar to handle Fwd/Bwd.
    // Let's define `compute_step` usage:
    // 0: Init (reset scan_idx, visited, temp_size)
    // 1: Find Unvisited Start (scan)
    // 2: Trace Forward (from start_idx)
    // 3: Trace Backward (from start_idx)
    // 4: Update Size
    
    reg [5:0] start_idx; // Store start of current chain
    
    // Helper signals for tracing
    wire signed [8:0] cur_row = curr_idx / 8;
    wire signed [8:0] cur_col = curr_idx % 8;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compute_step <= 0;
        end else if (state == COMPUTE_STAMP) begin
            case (compute_step)
                3'd0: begin // Init
                    visited <= 64'd0;
                    scan_idx <= 6'd0;
                    temp_size <= 8'd0;
                    curr_dx <= dx;
                    curr_dy <= dy;
                    compute_step <= 3'd1;
                end
                
                3'd1: begin // Find Start
                    if (scan_idx < 64) begin
                        if (p_flat[scan_idx] && !visited[scan_idx]) begin
                            start_idx <= scan_idx;
                            curr_idx <= scan_idx; // Current head of trace
                            visited[scan_idx] <= 1'b1;
                            fwd_count <= 1; // Count start node
                            bwd_count <= 0;
                            compute_step <= 3'd2; // Go to Forward trace
                        end else begin
                            scan_idx <= scan_idx + 1;
                        end
                    end else begin
                        // Finished scanning grid, go to finalize (step 4) which adds size
                        compute_step <= 3'd4; 
                    end
                end
                
                3'd2: begin // Trace Forward
                    // Try to move from curr_idx to next_idx in fwd direction
                    // Next = (cur_row + dy, cur_col + dx)
                    if ((cur_row + curr_dy >= 0) && (cur_row + curr_dy < 8) &&
                        (cur_col + curr_dx >= 0) && (cur_col + curr_dx < 8)) begin
                        
                        // Calculate flat index
                        // Check if that bit is set in paper_grid AND not visited
                        // Optimization: Calculate next index math
                        reg [5:0] next_idx;
                        next_idx = (cur_row + curr_dy) * 8 + (cur_col + curr_dx);
                        
                        if (p_flat[next_idx] && !visited[next_idx]) begin
                            // Move forward
                            curr_idx <= next_idx;
                            visited[next_idx] <= 1'b1;
                            fwd_count <= fwd_count + 1;
                            // Stay in this step
                        end else begin
                            // Dead end forward, go to Backward trace
                            curr_idx <= start_idx; // Reset to start
                            compute_step <= 3'd3;
                        end
                    end else begin
                        // Out of bounds, go to Backward trace
                        curr_idx <= start_idx;
                        compute_step <= 3'd3;
                    end
                end
                
                3'd3: begin // Trace Backward
                    // Try to move from curr_idx to next_idx in bwd direction (-dx, -dy)
                    if ((cur_row - curr_dy >= 0) && (cur_row - curr_dy < 8) &&
                        (cur_col - curr_dx >= 0) && (cur_col - curr_dx < 8)) begin
                        
                        reg [5:0] next_idx;
                        next_idx = (cur_row - curr_dy) * 8 + (cur_col - curr_dx);
                        
                        if (p_flat[next_idx] && !visited[next_idx]) begin
                            // Move backward
                            curr_idx <= next_idx;
                            visited[next_idx] <= 1'b1;
                            bwd_count <= bwd_count + 1;
                            // Stay in this step
                        end else begin
                            // Dead end backward, go to Add Size
                            compute_step <= 3'd4;
                        end
                    end else begin
                        // Out of bounds, go to Add Size
                        compute_step <= 3'd4;
                    end
                end
                
                3'd4: begin // Add Size
                    // Calculate ceil((fwd + bwd + 1)/2)
                    // (L + 1) >> 1
                    // L = fwd_count + bwd_count + 1
                    // Note: fwd_count included start node. bwd_count excludes start.
                    // Wait, logic: Start node counted in fwd_count=1.
                    // Fwd traces from start.
                    // Bwd traces from start.
                    // Total L = fwd_count + bwd_count.
                    // Wait, start node is counted in fwd. If we trace backward, we don't count start again.
                    // So L = fwd_count (incl start) + bwd_count (exclusive start).
                    // Example: Single node. Fwd=1, Bwd=0. L=1.
                    // Example: Chain of 2. Start -> Next. Fwd=2. Bwd=0 (if unidirectional). L=2.
                    // Example: Bidirectional. Start <-> Next. 
                    // Fwd: Start->Next (Fwd=2). Bwd: Start->Prev (Bwd=1). 
                    // L = 2 + 1 - 1? No, overlapping at start.
                    // Correct L calculation: 
                    // Trace forward. Count steps (including start). FwdLen.
                    // Trace backward. Count steps. BwdLen.
                    // Total unique nodes = FwdLen + BwdLen - 1 (since start counted twice).
                    // Wait, `bwd_count` in my logic starts at 0 and increments moving backwards.
                    // So if we move 1 step back, bwd_count=1.
                    // Total nodes = FwdLen + BwdLen.
                    // Let's verify: 
                    // Single node. Fwd: no move (Fwd=1). Bwd: no move (Bwd=0). Total=1. Correct.
                    // 2 nodes (Start->Next). Fwd: move to Next (Fwd=2). Bwd: no move (Bwd=0). Total=2. Correct.
                    // 3 nodes (Prev<->Start<->Next). 
                    // Fwd: Start->Next (Fwd=2). Bwd: Start->Prev (Bwd=1). Total=3. Correct.
                    // So L = fwd_count + bwd_count.
                    
                    // Add to temp_size: ceil(L/2) = (L+1)/2 (integer division)
                    // Need 4 bits max for L (max 8 nodes), sum is 4 bits. 
                    // Let's do math:
                    // L = fwd_count + bwd_count
                    // ceil = (L + 1) >> 1
                    temp_size <= temp_size + ((fwd_count + bwd_count + 1) >> 1);
                    
                    // Go back to Find Start
                    compute_step <= 3'd1;
                    scan_idx <= scan_idx + 1; // Advance scan past current start to avoid re-finding
                end
            endcase
        end else begin
            // Reset compute step if leaving state
            compute_step <= 3'd0;
        end
    end

endmodule
