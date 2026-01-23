module treasure_island(
    input clk,
    input rst_n,
    input start,
    input [3:0] grid_in,
    input grid_wr,
    input [1:0] row_idx,
    input [1:0] col_idx,
    output reg [1:0] result,
    output reg done,
    output reg valid
);

    // 4x4 Grid Storage - Each bit represents a cell (0=free, 1=forest)
    reg [3:0] grid [0:3];
    
    // DP Arrays for path counting
    reg [7:0] fwd_dp [0:3][0:3]; // Max paths in 4x4 is C(6,3)=20, 8 bits sufficient
    reg [7:0] bwd_dp [0:3][0:3];
    reg [7:0] total_paths;
    
    // Iteration counters
    reg [1:0] i, j; // Generic loop variables
    reg [1:0] k, l; // Nested loop variables
    
    // State Machine Definition
    localparam IDLE = 3'b000;
    localparam LOAD_GRID = 3'b001;
    localparam FIND_PATH = 3'b010;
    localparam COUNT_CRITICAL = 3'b011;
    localparam COMPUTE_RESULT = 3'b100;
    localparam DONE_STATE = 3'b101;
    
    reg [2:0] current_state, next_state;
    
    // Temporary storage for critical check
    reg is_critical;
    reg [7:0] product;
    
    // State Transition and Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 2'b0;
            // Reset Grid
            grid[0] <= 4'b0; grid[1] <= 4'b0; grid[2] <= 4'b0; grid[3] <= 4'b0;
        end else begin
            current_state <= next_state;
            
            // Default control signals
            done <= (next_state == DONE_STATE) ? 1'b1 : 1'b0;
            valid <= (next_state == DONE_STATE) ? 1'b1 : 1'b0;
            
            // Grid Loading Logic
            if (current_state == LOAD_GRID && grid_wr) begin
                grid[row_idx][col_idx] <= grid_in[0];
            end
            
            // FSM Operation Logic
            case (current_state)
                IDLE: begin
                    // Reset results
                    result <= 2'b0;
                    // Transition to LOAD_GRID when start is asserted
                    if (start) begin
                        // Clear DP arrays for clean start (optional but good practice)
                        fwd_dp[0][0] <= 8'b0; fwd_dp[0][1] <= 8'b0; fwd_dp[0][2] <= 8'b0; fwd_dp[0][3] <= 8'b0;
                        fwd_dp[1][0] <= 8'b0; fwd_dp[1][1] <= 8'b0; fwd_dp[1][2] <= 8'b0; fwd_dp[1][3] <= 8'b0;
                        fwd_dp[2][0] <= 8'b0; fwd_dp[2][1] <= 8'b0; fwd_dp[2][2] <= 8'b0; fwd_dp[2][3] <= 8'b0;
                        fwd_dp[3][0] <= 8'b0; fwd_dp[3][1] <= 8'b0; fwd_dp[3][2] <= 8'b0; fwd_dp[3][3] <= 8'b0;
                        
                        bwd_dp[0][0] <= 8'b0; bwd_dp[0][1] <= 8'b0; bwd_dp[0][2] <= 8'b0; bwd_dp[0][3] <= 8'b0;
                        bwd_dp[1][0] <= 8'b0; bwd_dp[1][1] <= 8'b0; bwd_dp[1][2] <= 8'b0; bwd_dp[1][3] <= 8'b0;
                        bwd_dp[2][0] <= 8'b0; bwd_dp[2][1] <= 8'b0; bwd_dp[2][2] <= 8'b0; bwd_dp[2][3] <= 8'b0;
                        bwd_dp[3][0] <= 8'b0; bwd_dp[3][1] <= 8'b0; bwd_dp[3][2] <= 8'b0; bwd_dp[3][3] <= 8'b0;
                    end
                end
                
                FIND_PATH: begin
                    // Performing DP calculations iteratively
                    // Forward DP: fwd_dp[i][j] = fwd_dp[i-1][j] + fwd_dp[i][j-1]
                    // Only proceed if cell is free (grid[i][j] == 0)
                    
                    if (i == 0 && j == 0) begin
                        if (!grid[0][0]) fwd_dp[0][0] <= 8'd1;
                        else fwd_dp[0][0] <= 8'd0;
                    end else begin
                        if (!grid[i][j]) begin
                            fwd_dp[i][j] <= ((j > 0 ? fwd_dp[i][j-1] : 8'd0) + 
                                             (i > 0 ? fwd_dp[i-1][j] : 8'd0));
                        end else begin
                            fwd_dp[i][j] <= 8'd0;
                        end
                    end
                    
                    // Backward DP: bwd_dp[i][j] = bwd_dp[i+1][j] + bwd_dp[i][j+1]
                    // We calculate in reverse: iterating i from 3 to 0, j from 3 to 0
                    // Since i/j are counters, we can detect "reverse" iteration based on a flag or state sub-states.
                    // However, the instruction implies using i, j for iteration.
                    // To keep it simple and within single state, we'll rely on the loop logic structure.
                    // Actually, standard single-state iterative DP is tricky for both forward and backward simultaneously without sub-states.
                    // Let's implement the loop logic in the combinational next_state logic or separate the forward/backward passes.
                    
                    // Correction: To fit the "40-50 cycles" constraint, we process cells sequentially.
                    // Iteration 0..15 handles Forward. Iteration 16..31 handles Backward (mapped to reverse indices).
                    // To make this synthesizable and clean, let's rely on the counters `i` and `j` managed in the combinational block.
                end
                
                COUNT_CRITICAL: begin
                    // Check if fwd_dp[i][j] * bwd_dp[i][j] == total_paths
                    // Check exclusion of start (0,0) and end (3,3)
                    // Store result in a flag
                    if (i == 0 && j == 0) is_critical <= 1'b0;
                    else if (i == 3 && j == 3) is_critical <= 1'b0;
                    else if (product == total_paths && !grid[i][j]) is_critical <= 1'b1;
                    else is_critical <= 1'b0;
                end
                
                COMPUTE_RESULT: begin
                    // Accumulate result: 0=none, 1=critical exists, 2=needs 2
                    if (is_critical) begin
                        result <= 2'd1;
                    end else if (result != 2'd1 && result != 2'd2) begin
                        // If we haven't found a critical cell yet, check if we need 2
                        // Note: If total_paths > 0, result stays 0 until a critical is found.
                        // If no critical is found by end of loop, result becomes 2.
                        // But result is a register. If loop finishes and result is still 0, and total_paths > 0, we want 2.
                        // We'll handle the "2" update in the loop logic or here.
                        // Actually, if we are in the loop, we update result in the loop.
                        // Let's rely on the loop logic to set result to 2 if it iterates through all without finding critical.
                        // Wait, the requirement says: Answer = 1 if critical exists, else 2 (if path exists).
                        // So we can initialize result to 0. If we find a critical, set to 1.
                        // If loop finishes and result is still 0 but total_paths > 0, set to 2.
                        // But `COMPUTE_RESULT` state is entered after the loop? Or during? 
                        // Let's say `COMPUTE_RESULT` is the state where we finalize the result.
                        if (total_paths == 0) result <= 2'd0;
                        else if (result == 2'd0) result <= 2'd2; // No critical found yet (or at all)
                        // If result was set to 1 in previous cycles, it stays 1.
                    end
                end
                
                DONE_STATE: begin
                    // Hold done high until reset or start low (optional, but good for handshaking)
                    // Logic handled by done <= 1 assignment above
                end
            endcase
        end
    end

    // Combinational Next State and Counter Logic
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_GRID;
                else next_state = IDLE;
            end
            
            LOAD_GRID: begin
                // We need to iterate through the grid or just wait for external writes.
                // The inputs `grid_wr`, `row_idx`, `col_idx` are external.
                // We need to know when loading is done.
                // Since we don't have a "load_done" input, we have 2 options:
                // 1. Assume a fixed number of cycles (e.g., 16).
                // 2. Check a specific condition.
                // For this design, let's assume the user asserts start and then drives grid_wr.
                // To make it deterministic, we will cycle through 16 states internally, OR
                // we can rely on a counter. Let's use a counter to wait for 16 cycles after start.
                // Actually, the interface `grid_wr` suggests the external logic writes to us.
                // Let's check if the grid is full. Or simply wait 16 cycles from start.
                // Let's use `i` as a cycle counter for loading. 
                // If i < 16, stay in LOAD. If i == 15 (or 16), go to FIND_PATH.
                // BUT, `grid_wr` might be used to gate the wait. 
                // Let's rely on a counter. 4x4=16 cells. 16 cycles is safe.
                // Wait, the instructions say: "Load 4x4 grid... via grid_in, row_idx, col_idx, grid_wr".
                // It implies the user controls the address. 
                // We will use a simple counter. Once counter reaches 16, we move to FIND_PATH.
                // We will increment the counter every cycle.
                if (i < 4'd15) next_state = LOAD_GRID;
                else next_state = FIND_PATH;
            end
            
            FIND_PATH: begin
                // We need to iterate 16 cells for Forward DP (indices 0..3, 0..3)
                // Then iterate 16 cells for Backward DP (indices 3..0, 3..0)
                // We can use `i` to track total steps.
                // 0-15: Forward. 16-31: Backward.
                // The combinational logic updates registers based on counters.
                // We need 32 cycles for DP.
                if (i < 5'd31) next_state = FIND_PATH;
                else next_state = COUNT_CRITICAL;
            end
            
            COUNT_CRITICAL: begin
                // Check 16 cells. 
                // If i < 15 (0..15 for indices 0..3, 0..3), stay.
                // If i == 15, check last cell, then go to COMPUTE_RESULT.
                // But wait, we need to combine the critical check result.
                // If we find a critical cell, we want to set result to 1.
                // If we are in COUNT_CRITICAL, we iterate. 
                // If i < 15, stay. If i == 15, next_state = COMPUTE_RESULT.
                // BUT, how do we update `result` (which is 0, 1, or 2) during the loop?
                // The instruction says: "Answer = 1 if any critical cell exists".
                // This implies an OR operation.
                // In the sequential block, we can do: if (is_critical) result <= 1.
                // But we need to know when to stop iterating.
                // So we iterate i from 0 to 15.
                if (i < 4'd15) next_state = COUNT_CRITICAL;
                else next_state = COMPUTE_RESULT;
            end
            
            COMPUTE_RESULT: begin
                // Just 1 cycle to finalize logic (check total_paths)
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                // Stay here until start goes low (reset required for new run)
                if (!start) next_state = IDLE;
                else next_state = DONE_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath Update Logic (Counters and DP Arrays)
    // This handles the iteration and calculations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 2'd0;
            j <= 2'd0;
            k <= 2'd0;
            l <= 2'd0;
            total_paths <= 8'd0;
            product <= 16'd0; // Expanded width for multiplication result
        end else begin
            
            case (current_state)
                IDLE: begin
                    i <= 2'd0; j <= 2'd0;
                    k <= 2'd0; l <= 2'd0;
                    total_paths <= 8'd0;
                end
                
                LOAD_GRID: begin
                    // Note: Actual grid writing is in the sequential block for `grid`
                    // Here we just iterate counter to know when we are done
                    // We use {k, l} to generate linear index 0-15, or just a cycle counter
                    // Let's use a temporary cycle counter.
                    if ({i, j} < 4'b1111) {i, j} <= {i, j} + 1;
                    else {i, j} <= 2'd0; // Reset for next stage if needed, or separate counters
                    // Actually, let's use `i` as the main cycle counter for simplicity
                    // Reset i at start of IDLE. Increment here.
                end
                
                FIND_PATH: begin
                    // We need to track Forward and Backward iterations.
                    // Let's use `i` as a 5-bit counter (0..31).
                    // We'll map `i` to (x,y) coordinates internally.
                    
                    if (i < 5'd16) begin
                        // Forward Pass: i = 0..15
                        // Map linear index to (x, y). Standard iteration: 0,0 -> 0,1 -> ... -> 3,3
                        // Let's do row-major: i = r*4 + c
                        // r = i[3:2], c = i[1:0]
                        // Calculation done in the sequential block based on these indices.
                        
                        // We must update fwd_dp[r][c] here.
                        // Since we are in sequential block, we can write directly.
                        
                        // Get indices
                        k <= i[3:2]; // row
                        l <= i[1:0]; // col
                        
                        // Compute DP logic for forward
                        if (i[3:2] == 0 && i[1:0] == 0) begin
                            fwd_dp[0][0] <= (!grid[0][0]) ? 8'd1 : 8'd0;
                        end else begin
                            if (!grid[i[3:2]][i[1:0]]) begin
                                // Sum of Top and Left
                                // Note: accessing fwd_dp from previous cycles. 
                                // Since fwd_dp is a register array, we need to ensure we are reading "old" values
                                // or handling the pipelining correctly. 
                                // However, since i increments sequentially, the Top and Left cells (if exist) were processed in previous cycles.
                                // So accessing fwd_dp[k][l-1] and fwd_dp[k-1][l] works fine.
                                // But wait, Vivado might infer distributed RAM with read latency 1? No, registers are fine.
                                fwd_dp[i[3:2]][i[1:0]] <= 
                                    (i[1:0] > 0 ? fwd_dp[i[3:2]][i[1:0]-1] : 8'd0) +
                                    (i[3:2] > 0 ? fwd_dp[i[3:2]-1][i[1:0]] : 8'd0);
                            end else begin
                                fwd_dp[i[3:2]][i[1:0]] <= 8'd0;
                            end
                        end
                        
                        // Increment cycle counter
                        i <= i + 1;
                        
                    end else if (i < 5'd32) begin
                        // Backward Pass: i = 16..31
                        // Map i to reverse coordinates: 
                        // Let offset = i - 16. Range 0..15.
                        // We want to iterate (3,3) -> (3,2) -> ... -> (0,0).
                        // Or simply: row = 3 - (offset / 4), col = 3 - (offset % 4)
                        // Let's define r_rev = 3 - ( (i-16) >> 2 )
                        // Let's define c_rev = 3 - ( (i-16) & 2'b11 )
                        
                        // To avoid subtractors in critical path, let's just use a reverse index variable.
                        // Let's just iterate i from 0 to 15 again but use a flag to indicate "backward pass"? 
                        // No, the previous state logic `FIND_PATH` uses i < 31. 
                        // We need to update bwd_dp.
                        
                        // Let's compute the reverse indices manually:
                        // offset = i - 16
                        // Since i is 5-bit, i - 16 = i + 16 (2's complement) = i & 5'b01111 effectively if we just mask bits? No.
                        // Let's just use the current i.
                        // If i=16 (01000), offset=0. Target (3,3)
                        // If i=17 (01001), offset=1. Target (3,2)
                        // ...
                        // If i=31 (01111), offset=15. Target (0,0)
                        
                        // Calculate indices for backward pass:
                        // k = 3 - ( (i - 16) >> 2 )
                        // l = 3 - ( (i - 16) & 3 )
                        // Since i >= 16, we can use i[3:2] and i[1:0] but shifted.
                        // i[3:2] is 01 or 10 or 11 for range 16-31? No, 16-31 is 10000 to 11111.
                        // i[4] is 1. i[3:2] goes 00, 01, 10, 11 for ranges 0-3, 4-7, 8-11, 12-15 in lower bits... this is getting complicated.
                        // Let's use a separate index counter for backward.
                        
                        // Actually, simpler approach: Inside FIND_PATH state, we use a state machine inside the sequential block.
                        // But we need to be in FIND_PATH for 32 cycles.
                        // Let's use `k` as the backward iteration index (0..15).
                        // When `k` < 16, we are processing backward pass.
                        
                        // Re-implementation of FIND_PATH datapath:
                        if (k < 4'd16) begin
                            // Backward Calculation
                            // k iterates 0..15. 
                            // Row = 3 - (k / 4), Col = 3 - (k % 4)
                            // Let's decode k directly:
                            // k: 0->(3,3), 1->(3,2), 2->(3,1), 3->(3,0)
                            // k: 4->(2,3), 5->(2,2), ...
                            // So row = 3 - k[3:2]; col = 3 - k[1:0];
                            
                            // Indices:
                            // row_b = 3 - k[3:2]
                            // col_b = 3 - k[1:0]
                            
                            // Wait, we need to compute bwd_dp[x][y] = bwd_dp[x+1][y] + bwd_dp[x][y+1]
                            // We are iterating in reverse (k increases, x decreases, y decreases).
                            // When k=0 (x=3,y=3): bwd_dp[3][3] = 1
                            // When k=1 (x=3,y=2): bwd_dp[3][2] = bwd_dp[3][3] + bwd_dp[4][2](0)
                            // When k=4 (x=2,y=3): bwd_dp[2][3] = bwd_dp[3][3] + bwd_dp[2][4](0)
                            
                            // We need to access bwd_dp[x+1][y] and bwd_dp[x][y+1].
                            // Since x decreases, x+1 was processed in previous k iteration.
                            // Since y decreases, y+1 was processed in previous k iteration (if same row).
                            // This works.
                            
                            // Let's define current backward coords:
                            // y = 3 - k[1:0]
                            // x = 3 - k[3:2]
                            
                            // However, we need to ensure we handle the correct order.
                            // We are using `k` to count backward steps.
                            // We need to check if the cell is free.
                            
                            // Let's calculate coords:
                            // x = 3 - k[3:2];
                            // y = 3 - k[1:0];
                            // Note: `k` increments from 0 to 15. 
                            // k=0: x=3, y=3
                            // k=1: x=3, y=2
                            // k=2: x=3, y=1
                            // k=3: x=3, y=0
                            // k=4: x=2, y=3
                            // ... correct.
                            
                            // Now, update bwd_dp[x][y]
                            // Need to check if grid[x][y] is free.
                            // We need to access grid[x][y]. Since x and y are calculated from k, we need to map back to grid indices.
                            // But `grid` is indexed by [row][col]. Let's assume x is row, y is col.
                            // Wait, usually row is x (vertical), col is y (horizontal). Let's stick to grid[row][col].
                            // So row = 3 - k[3:2], col = 3 - k[1:0].
                            
                            // To minimize logic, let's just use k to index.
                            // But we need to know x+1 and y+1.
                            // x+1 = 3 - (k+4)[3:2] ? No.
                            // Let's use a flag to control Forward vs Backward pass inside FIND_PATH.
                            // We'll split FIND_PATH into two parts:
                            // Part 1: Forward (i=0..15)
                            // Part 2: Backward (i=16..31)
                            // We use `i` for both, just different logic.
                            
                            // Let's refine the FIND_PATH state logic:
                            // We want to use `i` (0..31).
                            // If i < 16: Forward Logic.
                            // If i >= 16: Backward Logic.
                            
                            // Backward Logic:
                            // Define row_b = 3 - ( (i - 16) >> 2 )
                            // Define col_b = 3 - ( (i - 16) & 2'b11 )
                            // Since i >= 16, i - 16 is just taking the lower 4 bits of i (since 16 is 10000).
                            // Actually, i[4] is 1 for 16-31. i[3:2] and i[1:0] are the counter values.
                            // Wait, 16 is 10000. i[4]=1, i[3:2]=00, i[1:0]=00.
                            // We want offset = i - 16. Offset range 0..15.
                            // Offset[3:2] = i[3:2]; Offset[1:0] = i[1:0]; 
                            // Because 16 binary is 10000, subtraction is just stripping bit 4.
                            // So Offset = {i[3:0]}.
                            // So Row_b = 3 - i[3:2]; Col_b = 3 - i[1:0];
                            
                            if (grid[3 - i[3:2]][3 - i[1:0]] == 0) begin
                                // bwd_dp[3 - i[3:2]][3 - i[1:0]] = 
                                //   bwd_dp[3 - i[3:2] + 1][3 - i[1:0]] + bwd_dp[3 - i[3:2]][3 - i[1:0] + 1]
                                // Note: i[3:2] goes 0,1,2,3. So 3-i[3:2] goes 3,2,1,0.
                                // When i[3:2] is 0, row=3. neighbor down (row+1) is 4 (invalid). neighbor right (col+1) is 3+1 (if i[1:0]=0).
                                // We need to read bwd_dp from previous cycles.
                                // Previous cycles had i[3:2] smaller (e.g. 0 -> 1 -> 2 -> 3).
                                // Since i[3:2] increments, 3-i[3:2] decrements. 
                                // So (3 - i[3:2]) + 1 corresponds to a previous row index.
                                // Wait, if i[3:2]=0 (row=3), neighbor is row=4? No, down is row+1. 
                                // If row=3, down is 4 (invalid). If row=2 (i[3:2]=1), down is 3 (processed in previous i).
                                // So we need to read bwd_dp[row+1][col].
                                
                                // Let's check indices carefully.
                                // Iteration order: i=16..31.
                                // i=16: 3-i[3:2]=3-0=3. row=3. col=3-0=3.
                                // bwd_dp[3][3] = 1 (boundary).
                                // i=17: 3-0=3. row=3. col=3-1=2. 
                                // bwd_dp[3][2] = bwd_dp[4][2](0) + bwd_dp[3][3](1).
                                // i=18: row=3, col=1. bwd_dp[3][1] = bwd_dp[3][2](prev).
                                // i=20 (i[3:2]=1): row=2, col=3.
                                // bwd_dp[2][3] = bwd_dp[3][3] + bwd_dp[2][4].
                                
                                // We need to map current indices to array indices.
                                // Current Row = 3 - i[3:2]
                                // Current Col = 3 - i[1:0]
                                // Down Neighbor Row = Current Row + 1
                                // Right Neighbor Col = Current Col + 1
                                
                                // We need to read bwd_dp[Current Row + 1][Current Col] and bwd_dp[Current Row][Current Col + 1].
                                // Since Current Row decreases, Current Row + 1 was processed in previous outer loop (lower i).
                                // Since Current Col decreases (within inner loop), Current Col + 1 was processed in previous inner step (lower i).
                                // Wait, i increments 0..15. i[3:2] increments slowly, i[1:0] increments quickly.
                                // i=16: (3,3)
                                // i=17: (3,2)
                                // i=18: (3,1)
                                // i=19: (3,0)
                                // i=20: (2,3) -> Here, neighbor down (3,3) was processed at i=16. Neighbor right (2,4) invalid.
                                
                                // So we can read bwd_dp directly.
                                
                                // Target: bwd_dp[r][c]
                                // r = 3 - i[3:2]
                                // c = 3 - i[1:0]
                                
                                // Neighbor Down: bwd_dp[r+1][c] (r+1 = 4 - i[3:2])
                                // Neighbor Right: bwd_dp[r][c+1] (c+1 = 4 - i[1:0])
                                
                                // We need to index the array. 
                                // Since i[3:2] is 0..3, r is 3..0. r+1 is 4..1. 
                                // When r=3 (i[3:2]=0), r+1=4 (invalid). We need to handle the boundary.
                                
                                // Let's define indices explicitly to avoid confusion.
                                // row_idx_b = 3 - i[3:2];
                                // col_idx_b = 3 - i[1:0];
                                
                                // access_down = (row_idx_b < 3) ? bwd_dp[row_idx_b+1][col_idx_b] : 0;
                                // access_right = (col_idx_b < 3) ? bwd_dp[row_idx_b][col_idx_b+1] : 0;
                                
                                // This requires conditionals. Let's try to simplify.
                                // Since i[3:2] increases from 0 to 3:
                                // i[3:2]=0 -> row=3, down valid? No.
                                // i[3:2]=1 -> row=2, down valid? Yes, row=3 (processed at i[3:2]=0).
                                // i[3:2]=2 -> row=1, down valid? Yes, row=2.
                                // i[3:2]=3 -> row=0, down valid? Yes, row=1.
                                // So down valid if i[3:2] > 0.
                                
                                // Since i[1:0] increases from 0 to 3:
                                // i[1:0]=0 -> col=3, right valid? No.
                                // i[1:0]=1 -> col=2, right valid? Yes, col=3 (processed at i[1:0]=0).
                                // i[1:0]=2 -> col=1, right valid? Yes, col=2.
                                // i[1:0]=3 -> col=0, right valid? Yes, col=1.
                                // So right valid if i[1:0] > 0.
                                
                                // Now, we need to read bwd_dp values.
                                // Down value: bwd_dp[4 - i[3:2]]? No, down is row+1.
                                // Row index for down neighbor = (3 - i[3:2]) + 1 = 4 - i[3:2].
                                // Right neighbor col = (3 - i[1:0]) + 1 = 4 - i[1:0].
                                
                                // We have to be careful. i[3:2] is 2 bits. 4 - i[3:2] is 4, 3, 2, 1.
                                // If i[3:2]=0 (Row 3), Down is Row 4 (Invalid). We treat as 0.
                                // If i[3:2]=1 (Row 2), Down is Row 3. Index 3.
                                // If i[3:2]=2 (Row 1), Down is Row 2. Index 2.
                                // If i[3:2]=3 (Row 0), Down is Row 1. Index 1.
                                // So we need to access bwd_dp[4-i[3:2]][...] but only if i[3:2] != 0.
                                // Similarly for right: 4 - i[1:0].
                                
                                // This is complex. Let's use a register to store the sum.
                                // But we need the values *now* to write to the register.
                                // Since this is combinational logic inside an always block triggered by clock, the read happens immediately.
                                // We can use `if` statements to select the value.
                                
                                // Let's write the logic cleanly:
                                // val_down = 0;
                                // if (i[3:2] != 0) val_down = bwd_dp[4 - i[3:2]][3 - i[1:0]];
                                // val_right = 0;
                                // if (i[1:0] != 0) val_right = bwd_dp[3 - i[3:2]][4 - i[1:0]];
                                // bwd_dp[3-i[3:2]][3-i[1:0]] = val_down + val_right;
                                
                                // Note: array indices must be constant or variable. This is fine.
                                // However, synthesis might struggle with `4 - i[3:2]`. 
                                // `i[3:2]` is 00, 01, 10, 11.
                                // 4 - 00 = 100 (4) -> 4'd4. (Out of range 0-3). We mask? No, we use conditional.
                                // 4 - 01 = 3
                                // 4 - 10 = 2
                                // 4 - 11 = 1
                                // So effectively: if i[3:2]==0, don't read. Else read index = 4 - i[3:2].
                                // 4 - i[3:2] is equivalent to ~i[3:2] + 1 (2-bit inverse + 1).
                                // 0->~00+1=11+1=100(4)
                                // 1->~01+1=10+1=11(3)
                                // 2->~10+1=01+1=10(2)
                                // 3->~11+1=00+1=01(1)
                                // So the index is {1'b0, ~i[3:2] + 1}. Or just compute 4 - i[3:2].
                                // Let's use a helper variable.
                                
                                // Given the complexity and latency requirement (40-50 cycles), we can afford 
                                // 1 cycle for Forward (16 cells) and 1 cycle for Backward (16 cells).
                                // The code above handles this.
                                
                                // Let's implement the update:
                                if (!grid[3 - i[3:2]][3 - i[1:0]]) begin
                                    bwd_dp[3 - i[3:2]][3 - i[1:0]] <= 
                                        ((i[3:2] != 0) ? bwd_dp[4 - i[3:2]][3 - i[1:0]] : 8'd0) +
                                        ((i[1:0] != 0) ? bwd_dp[3 - i[3:2]][4 - i[1:0]] : 8'd0);
                                end else begin
                                    bwd_dp[3 - i[3:2]][3 - i[1:0]] <= 8'd0;
                                end
                            end
                            
                            // Update total_paths at the very end of backward pass (i=31)
                            if (i == 5'd31) begin
                                total_paths <= fwd_dp[3][3]; // Save total paths from forward pass
                            end
                            
                            i <= i + 1;
                        end
                    end
                end
                
                COUNT_CRITICAL: begin
                    // We need to iterate 0..15 again.
                    // Let's use `i` as the counter 0..15.
                    // i = 0: (0,0), i=1: (0,1)...
                    // i = r*4 + c
                    // r = i[3:2], c = i[1:0]
                    
                    // Update product for combinational check
                    // product = fwd_dp[r][c] * bwd_dp[r][c]
                    // Multiplication in hardware. Let's assume it's a small integer multiplication.
                    // fwd_dp and bwd_dp are 8 bits. Product is 16 bits.
                    product <= fwd_dp[i[3:2]][i[1:0]] * bwd_dp[i[3:2]][i[1:0]];
                    
                    // Update result register (accumulate OR)
                    // Check `is_critical` which is updated from previous cycle's product check.
                    // Note: product update happens this cycle. is_critical check happens in sequential block for current cycle.
                    // Wait, if we do product <= ... in sequential block, then `product` is updated AFTER clock edge.
                    // So the check `product == total_paths` uses OLD product.
                    // To fix this, we should calculate product combinationally.
                    // But in a standard FSM, we use registered logic.
                    // Let's rely on the combinational `is_critical` signal which reads the current fwd/bwd values.
                    // The sequential block updates `result`.
                    
                    // Let's use the combinational `is_critical` defined in the always @(*) block.
                    // But `is_critical` depends on `product`.
                    // Let's make `product` combinational or calculate it inside the sequential block using immediate values.
                    
                    // Let's calculate product immediately in the sequential block to avoid latency issues.
                    // Actually, we can check the condition directly.
                    
                    // Let's refine COUNT_CRITICAL:
                    // We check if (fwd_dp[r][c] * bwd_dp[r][c] == total_paths)
                    
                    // We will use `product` as a combinational output of the multiplication.
                    // But `product` needs to be a reg if assigned in always block.
                    // Let's declare `wire [15:0] mult_out = fwd_dp[r][c] * bwd_dp[r][c];` and use that.
                    // But we need to know r, c. We have i.
                    
                    // Let's stick to the registered `product` but fix the flow.
                    // We need to evaluate the *current* cell to decide if we set result=1.
                    // So we should do the multiplication combinationally or use immediate values.
                    
                    // Let's do this:
                    if (i[3:2] != 0 || i[1:0] != 0) begin // Exclude start
                        if (i[3:2] != 3 || i[1:0] != 3) begin // Exclude end
                            if ((fwd_dp[i[3:2]][i[1:0]] * bwd_dp[i[3:2]][i[1:0]]) == total_paths) begin
                                if (total_paths != 0) result <= 2'd1;
                            end
                        end
                    end
                    
                    // Increment i
                    if (i < 4'd15) i <= i + 1;
                    else i <= 4'd0; // Reset i for next stage
                    
                    // Handle result transition 0 -> 2 if no critical found yet.
                    // We can't know if we are the last cell until we get there.
                    // So we handle the "else result=2" in the COMPUTE_RESULT state.
                    // Just set result to 1 here if found.
                    
                    // Note: If result was already 1 from previous iteration, `result <= 2'd1` keeps it 1.
                end
                
                COMPUTE_RESULT: begin
                    // If we are here, we finished the loop.
                    // If result is 0, check total_paths.
                    // If total_paths == 0, result stays 0.
                    // If total_paths > 0 and result == 0, then result = 2.
                    if (total_paths == 0) result <= 2'd0;
                    else if (result == 2'd0) result <= 2'd2;
                end
                
                default: begin
                    // Reset counters for IDLE/DONE
                    i <= 2'd0;
                    j <= 2'd0;
                end
            endcase
        end
    end

    // Combinational Logic for critical check in COUNT_CRITICAL state
    // This is needed to update `result` immediately or to drive `is_critical` if used.
    // Actually, we simplified the sequential logic to do the update directly.
    // However, we need to handle the `is_critical` flag for the sequential block logic if we use it.
    // Since we are updating `result` directly in the sequential block, we don't strictly need `is_critical`.
    // But the requirement says "Use DP to count paths... A cell is critical if...".
    // Let's use `is_critical` as a debug/status indicator if needed, but logic is already in sequential block.
    
    // However, the sequential block logic for `COUNT_CRITICAL` needs to know the product.
    // Since `product` is a reg, it has a delay. To avoid delay, we use the values directly in the if condition.
    // The code in `COUNT_CRITICAL` section of sequential block does this:
    // `if ((fwd_dp[i][j] * bwd_dp[i][j]) == total_paths)`
    // This is a combinational expression inside a sequential block. This is valid Verilog.
    // It creates combinational logic for multiplication and comparison, then the result latches into `result`.

    // We need to define `i` and `j` for the LOAD_GRID state correctly.
    // In LOAD_GRID, we used `{i,j}`. Let's make sure i and j are sized correctly.
    // i is 2 bits, j is 2 bits. `{i,j}` is 4 bits. OK.
    
    // Fix: In LOAD_GRID, we must distinguish between the loop counter and the DP indices.
    // Let's use `l` as the load cycle counter.
    // Let's reset `l` in IDLE. Increment `l` in LOAD_GRID.
    // When l == 15, next_state = FIND_PATH.
    
    // Revising LOAD_GRID logic in sequential block:
    // Remove logic for i,j in FIND_PATH.
    // Use `l` for LOAD_GRID.
    // Use `i` for FIND_PATH (0..31).
    // Use `i` for COUNT_CRITICAL (0..15).
    
    // Let's update the sequential block to be cleaner:
    
    // --- Revised Sequential Logic for LOAD_GRID ---
    // In IDLE: l <= 0;
    // In LOAD_GRID: 
    //    if (grid_wr) begin 
    //       grid[row_idx][col_idx] <= grid_in[0]; 
    //    end
    //    if (l < 15) l <= l + 1; else l <= 0; // This is problematic if user writes slower.
    //    Wait, the prompt implies `grid_wr` is valid. 
    //    The prompt says: "Load 4x4 grid... via grid_in, row_idx, col_idx, grid_wr".
    //    This suggests we don't control the write address. We just wait.
    //    To satisfy "Latency: 40-50 cycles", we must have a deterministic flow.
    //    Let's assume the user writes 16 words consecutively, 1 cycle each.
    //    Or we force a 16 cycle wait.
    //    Let's use a 4-bit counter `load_cnt`.

endmodule

// Helper module or logic for the multiplication result? No, done inline.
// The previous code had `product` logic. Let's refine it to be robust.

// RE-WRITING THE DATAPATH ALWAYS BLOCK FOR CLARITY AND CORRECTNESS
// We will use separate variables for clarity.

module treasure_island(
    input clk,
    input rst_n,
    input start,
    input [3:0] grid_in,
    input grid_wr,
    input [1:0] row_idx,
    input [1:0] col_idx,
    output reg [1:0] result,
    output reg done,
    output reg valid
);

    // Grid storage
    reg [3:0] grid [0:3];
    
    // DP arrays
    reg [7:0] fwd_dp [0:3][0:3];
    reg [7:0] bwd_dp [0:3][0:3];
    reg [7:0] total_paths;
    
    // FSM State
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam CALC_PATHS = 3'b010;
    localparam CHECK_CRITICAL = 3'b011;
    localparam FINALIZE = 3'b100;
    localparam FINISH = 3'b101;
    
    reg [2:0] state;
    
    // Iteration counters
    reg [3:0] cnt; // 0-15 for grid cells, or 0-31 for paths
    reg [1:0] r, c; // Row and Col for current operation
    
    // Intermediate signals
    wire [15:0] prod_calc = fwd_dp[cnt[3:2]][cnt[1:0]] * bwd_dp[cnt[3:2]][cnt[1:0]];
    
    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            result <= 0;
            cnt <= 0;
            total_paths <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        cnt <= 0;
                        result <= 0;
                        done <= 0;
                        valid <= 0;
                    end
                end
                
                LOAD: begin
                    // Wait for 16 cycles OR user inputs. 
                    // To be deterministic and simple: Wait 16 cycles.
                    // We assume user puts valid data on grid_in during these cycles.
                    // Or we can use grid_wr as a handshake. 
                    // Let's use the counter. If grid_wr is low, we might skip.
                    // To be safe, let's just increment cnt. If user drives data, it works.
                    if (cnt < 15) begin
                        cnt <= cnt + 1;
                        // Store data if write enable is high
                        if (grid_wr) grid[row_idx][col_idx] <= grid_in[0];
                    end else begin
                        state <= CALC_PATHS;
                        cnt <= 0;
                    end
                    // Handle last write
                    if (cnt == 15 && grid_wr) grid[row_idx][col_idx] <= grid_in[0];
                end
                
                CALC_PATHS: begin
                    // Forward pass (0..15) and Backward pass (16..31)
                    if (cnt < 31) begin
                        cnt <= cnt + 1;
                        
                        if (cnt < 16) begin
                            // Forward: cnt = 0..15
                            // r = cnt[3:2], c = cnt[1:0]
                            if (!grid[cnt[3:2]][cnt[1:0]]) begin
                                if (cnt == 0) fwd_dp[0][0] <= 1;
                                else begin
                                    fwd_dp[cnt[3:2]][cnt[1:0]] <= 
                                        (cnt[1:0] > 0 ? fwd_dp[cnt[3:2]][cnt[1:0]-1] : 0) +
                                        (cnt[3:2] > 0 ? fwd_dp[cnt[3:2]-1][cnt[1:0]] : 0);
                                end
                            end else begin
                                fwd_dp[cnt[3:2]][cnt[1:0]] <= 0;
                            end
                        end else begin
                            // Backward: cnt = 16..31 (logic for 0..15 reverse)
                            // cnt offset = cnt - 16 = cnt[3:0]
                            // We map 0..15 to (3,3)..(0,0)
                            // Let k = cnt[3:0] (0..15)
                            // r = 3 - k[3:2], c = 3 - k[1:0]
                            
                            // Wait, cnt is 16..31. cnt[3:0] is 0..15. Good.
                            // r_idx = 3 - cnt[3:2], c_idx = 3 - cnt[1:0]
                            
                            // Check boundary: if (r_idx, c_idx) is free
                            // r_idx = 3 - cnt[3:2]
                            // c_idx = 3 - cnt[1:0]
                            
                            if (!grid[3 - cnt[3:2]][3 - cnt[1:0]]) begin
                                // bwd_dp[r][c] = bwd_dp[r+1][c] + bwd_dp[r][c+1]
                                // r+1 = 4 - cnt[3:2]. Valid if cnt[3:2] != 0 (i.e., r != 3)
                                // c+1 = 4 - cnt[1:0]. Valid if cnt[1:0] != 0 (i.e., c != 3)
                                
                                bwd_dp[3 - cnt[3:2]][3 - cnt[1:0]] <= 
                                    ((cnt[3:2] != 0) ? bwd_dp[4 - cnt[3:2]][3 - cnt[1:0]] : 0) +
                                    ((cnt[1:0] != 0) ? bwd_dp[3 - cnt[3:2]][4 - cnt[1:0]] : 0);
                            end else begin
                                bwd_dp[3 - cnt[3:2]][3 - cnt[1:0]] <= 0;
                            end
                        end
                    end else begin
                        // End of CALC_PATHS
                        state <= CHECK_CRITICAL;
                        cnt <= 0;
                        total_paths <= fwd_dp[3][3];
                        // Initialize result for critical check
                        // result is used as accumulator. Keep it 0 for now.
                    end
                end
                
                CHECK_CRITICAL: begin
                    // Check 0..15
                    // Check if fwd_dp[r][c] * bwd_dp[r][c] == total_paths
                    // Exclude (0,0) and (3,3)
                    
                    if (cnt < 15) begin
                        cnt <= cnt + 1;
                    end else begin
                        state <= FINALIZE;
                    end
                    
                    // Check logic
                    // We need to evaluate the cell corresponding to current cnt.
                    // But wait, this block executes sequentially.
                    // The `prod_calc` wire is combinational based on `cnt`.
                    // So if `cnt` updates, `prod_calc` updates.
                    // We need to latch the check result into `result`.
                    
                    // To avoid combinational loops or latch inference, we do:
                    if (cnt[3:2] != 0 || cnt[1:0] != 0) begin // Exclude start
                        if (cnt[3:2] != 3 || cnt[1:0] != 3) begin // Exclude end
                            if (prod_calc == total_paths && total_paths != 0) begin
                                result <= 2'd1; // Found a critical cell
                            end
                        end
                    end
                    // Note: result accumulates. If we find one, result becomes 1.
                    // If we find another, result stays 1.
                    // If we never find one, result stays 0.
                end
                
                FINALIZE: begin
                    // Determine result if not 1
                    if (result == 0) begin
                        if (total_paths == 0) result <= 2'd0;
                        else result <= 2'd2;
                    end
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1;
                    valid <= 1;
                    if (!start) state <= IDLE; // Wait for start low to reset
                    else state <= FINISH;
                end
            endcase
        end
    end

endmodule