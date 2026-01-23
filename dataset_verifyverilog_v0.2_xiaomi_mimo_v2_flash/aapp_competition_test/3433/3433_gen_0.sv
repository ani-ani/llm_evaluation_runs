module maze_escape(
    input clk,
    input rst_n,
    input start,
    input [7:0] row_data,
    input [2:0] row_index,
    input load,
    output reg result,
    output reg [5:0] escape_time,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam LOADING = 2'b01;
    localparam SIMULATING = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;

    // Grid storage: 8x8, 2 bits per cell
    // 00: empty (.)
    // 01: wall (#)
    // 10: fire (F)
    // 11: Joe (J)
    reg [1:0] grid [0:7][0:7];
    reg [2:0] load_row_cnt;
    reg [2:0] sim_row_cnt;
    reg [2:0] sim_col_cnt;

    // Joe's position
    reg [2:0] joe_x, joe_y;
    reg [2:0] next_joe_x, next_joe_y;

    // Fire spread queue (FIFO)
    // Depth 16 to handle max 64 cells, though max concurrent fire might be less
    // Using simplified circular buffer
    reg [5:0] fire_queue [0:15]; // {y[2:0], x[2:0]}
    reg [4:0] fire_head, fire_tail; // Pointers, 5 bits for 16 slots (full check)
    reg [4:0] next_fire_head, next_fire_tail;
    reg [5:0] current_fire_pos;

    // Simulation counters
    reg [5:0] cycle_count;
    reg [5:0] next_cycle_count;
    reg found_escape;
    reg [5:0] escape_cycle;
    reg collision_detected;

    // Temp variables for BFS logic
    reg [2:0] temp_x, temp_y;
    reg [1:0] cell_val;
    reg [2:0] new_x, new_y;
    reg can_move;
    reg fire_spread_to_boundary;

    integer i, j;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_row_cnt <= 0;
            sim_row_cnt <= 0;
            sim_col_cnt <= 0;
            joe_x <= 0;
            joe_y <= 0;
            fire_head <= 0;
            fire_tail <= 0;
            cycle_count <= 0;
            result <= 0;
            escape_time <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            
            // Loading Counter
            if (state == LOADING && load) begin
                // Load row data into grid
                for (i = 0; i < 8; i = i + 1) begin
                    case (row_data[i*8 +: 8])
                        8'h23: grid[row_index][i] <= 2'b01; // #
                        8'h46: grid[row_index][i] <= 2'b10; // F
                        8'h4A: begin
                            // Joe J - Joe is not stored in grid, but we record position
                            // We clear the grid cell so Joe doesn't block fire? 
                            // Actually, Joe is on the cell. If Joe leaves, it becomes empty.
                            // Let's store Joe's position separately and clear the grid cell.
                            // Or keep J in grid and treat it as Empty for fire spread? 
                            // Let's store J in grid as 11 to mark it, but for fire logic we need to treat it as Passable initially? 
                            // No, Joe is an entity.
                            // Let's store 00 in grid for Joe's position to allow fire spread logic to work naturally (if Joe leaves, fire enters).
                            // But we need to know where Joe is.
                            // So:
                            // 1. Update `joe_x`, `joe_y`.
                            // 2. Set `grid[row_index][i]` to 00 (Empty).
                            //    Why? Because in the simulation, if Joe leaves, the cell becomes Empty.
                            //    And Fire logic checks neighbors for Empty.
                            //    If Joe is there, he is an entity on top.
                            //    Wait, if Joe is at (1,1) and Fire at (1,2):
                            //    `grid[1][1] = 00`.
                            //    `grid[1][2] = 10`.
                            //    Fire spread: checks neighbors of (1,2). Sees (1,1) is 00. Spreads to (1,1) in `temp_grid`.
                            //    Loss check: `temp_grid[1][1]` is 10 -> Lose. Correct.
                            //    
                            //    So storing 00 for Joe's cell in `grid` is correct for fire logic.
                            //    But wait, if Joe is in a cell, can Fire spread there? 
                            //    "Fire spreads to adjacent '.' or 'J' cells".
                            //    So Fire CAN enter Joe's cell.
                            //    So `grid` should be 00 (Empty/Passable) where Joe is.
                            //    Yes.
                            grid[row_index][i] <= 2'b00;
                            joe_x <= i;
                            joe_y <= row_index;
                        end
                        default: grid[row_index][i] <= 2'b00; // .
                    endcase
                end
                load_row_cnt <= load_row_cnt + 1;
            end else if (state == IDLE) begin
                load_row_cnt <= 0;
            end

            // Simulation Loop Logic
            if (state == SIMULATING) begin
                // Cycle 0: Initialization
                if (cycle_count == 0) begin
                    // Find Joe and Fire in Grid
                    // We perform this scan using sim_row_cnt/sim_col_cnt in cycle 0
                    // But for single cycle init, we assume we scan grid in 0-63 or use combinational logic.
                    // To keep strictly sequential logic for synthesis without large combinational loops:
                    // We will scan the grid for initialization in the first 64 cycles or use a dedicated init state.
                    // However, problem implies cycle-accurate simulation starting after load.
                    // Let's do initialization in cycle 0 based on loaded grid.
                    // Since we need to scan 64 cells, we can do it in the first cycle if we use unrolled logic,
                    // or we can use sim_row_cnt/sim_col_cnt to scan in the first 64 cycles (cascading delay).
                    // Optimization: Use combinational find for J and F to start simulation immediately.
                    // Let's assume combinational extraction of Joe/Fire for cycle 0.
                end

                // Update Fire Spread (BFS)
                // Logic: Pop from queue, check neighbors, push valid neighbors
                if (cycle_count > 0) begin
                    // Spread logic happens based on queue content from previous cycle
                    // We process the queue content to generate NEXT cycle's queue
                    // This implies a delay. To be truly parallel with Joe:
                    // 1. Process Fire Queue (Spread to adjacent)
                    // 2. Check Joe Safety
                    // 3. Move Joe
                end
            end

            // Update Joe/Fire Registers
            if (state == SIMULATING) begin
                if (cycle_count > 0) begin
                   // Logic moved to combinational block below, updated here
                   joe_x <= next_joe_x;
                   joe_y <= next_joe_y;
                   fire_head <= next_fire_head;
                   fire_tail <= next_fire_tail;
                   cycle_count <= next_cycle_count;
                end else begin
                    // Initialize Cycle 0 Logic (Load Queue, Find Joe)
                    // We use the sim counters to scan the grid in one go before starting simulation steps
                    // To avoid complexity, let's assume we do a 64-cycle scan for init, 
                    // BUT requirement says max 64 cycles simulation.
                    // Let's optimize: We will find Joe/Fire using combinational logic at the end of LOADING state.
                end
            end

            // Done Logic
            if (found_escape || collision_detected || (cycle_count >= 64 && !found_escape && !collision_detected)) begin
                 // Note: if cycle_count >= 64, we check bounds. If Joe is at boundary at cycle 64, he wins.
                 // If not, he loses (time out).
                 // But we check bounds every cycle.
                 // If we reach cycle 64, we set done.
                 if (state == SIMULATING) begin
                    result <= found_escape;
                    escape_time <= escape_cycle;
                    done <= 1;
                    state <= DONE;
                 end
            end
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOADING;
            LOADING: if (load_row_cnt == 8) next_state = SIMULATING; // Wait for 8 rows
            SIMULATING: begin
                if (found_escape || collision_detected || cycle_count >= 64)
                    next_state = DONE;
                else
                    next_state = SIMULATING;
            end
            DONE: next_state = IDLE; // Self-reset or wait for external reset
        endcase
    end

    // Combinational Logic for Simulation
    always @(*) begin
        // Defaults for simulation state
        next_joe_x = joe_x;
        next_joe_y = joe_y;
        next_cycle_count = cycle_count;
        next_fire_head = fire_head; // Not strictly used in Grid-scan method, but keeping for compatibility
        next_fire_tail = fire_tail;
        found_escape = 0;
        collision_detected = 0;
        
        // Defaults for temp_grid (Copy current grid)
        for (int r = 0; r < 8; r = r + 1) begin
            for (int c = 0; c < 8; c = c + 1) begin
                temp_grid[r][c] = grid[r][c];
            end
        end

        // Fire Spread (Update temp_grid)
        // This logic runs continuously. In SIMULATING state, we use this to update the register.
        // To be strictly correct, we should only spread fire when we are actually in the simulation step.
        // But since temp_grid is only used in SIMULATING, it is okay.
        for (int r = 0; r < 8; r = r + 1) begin
            for (int c = 0; c < 8; c = c + 1) begin
                if (grid[r][c] == 2'b10) begin // If current cell is Fire
                    // Spread to adjacent passable cells (Empty)
                    if (r > 0 && grid[r-1][c] == 2'b00) temp_grid[r-1][c] = 2'b10;
                    if (r < 7 && grid[r+1][c] == 2'b00) temp_grid[r+1][c] = 2'b10;
                    if (c > 0 && grid[r][c-1] == 2'b00) temp_grid[r][c-1] = 2'b10;
                    if (c < 7 && grid[r][c+1] == 2'b00) temp_grid[r][c+1] = 2'b10;
                end
            end
        end

        // Logic specific to SIMULATING state
        if (state == SIMULATING) begin
            // Check Win Condition (Joe is at boundary at start of cycle)
            if (joe_x == 0 || joe_x == 7 || joe_y == 0 || joe_y == 7) begin
                found_escape = 1;
            end
            
            // Check Loss Condition (Joe is on Fire in the *next* state grid, i.e. after spread)
            if (temp_grid[joe_y][joe_x] == 2'b10) begin
                collision_detected = 1;
            end
            
            // Joe Movement Logic (only if not already won/lost)
            if (!found_escape && !collision_detected) begin
                // Greedy movement: Up, Down, Left, Right
                // Check if the cell is Empty (00) in the Post-Spread Grid (temp_grid)
                // Joe cannot move into Walls or Fire.
                
                // Try Up
                if (joe_y > 0 && temp_grid[joe_y - 1][joe_x] == 2'b00) begin
                    next_joe_y = joe_y - 1;
                end
                // Try Down
                else if (joe_y < 7 && temp_grid[joe_y + 1][joe_x] == 2'b00) begin
                    next_joe_y = joe_y + 1;
                end
                // Try Left
                else if (joe_x > 0 && temp_grid[joe_y][joe_x - 1] == 2'b00) begin
                    next_joe_x = joe_x - 1;
                end
                // Try Right
                else if (joe_x < 7 && temp_grid[joe_y][joe_x + 1] == 2'b00) begin
                    next_joe_x = joe_x + 1;
                end
                // Else stay put
            end
            
            // Check Win Condition again (Did Joe move to a boundary?)
            // We check next_joe_x/y because we haven't updated registers yet.
            if (!found_escape && !collision_detected) begin
                if (next_joe_x == 0 || next_joe_x == 7 || next_joe_y == 0 || next_joe_y == 7) begin
                    found_escape = 1;
                end
            end
            
            // Determine Next State and Cycle Count
            if (found_escape || collision_detected || cycle_count >= 63) begin
                next_state = DONE;
                next_cycle_count = cycle_count; // Keep count for record
            end else begin
                next_state = SIMULATING;
                next_cycle_count = cycle_count + 1;
            end
        end else begin
            // Default for non-simulating states
            next_state = state;
        end
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_row_cnt <= 0;
            cycle_count <= 0;
            done <= 0;
            result <= 0;
            escape_time <= 0;
            // Reset grid (optional but good practice)
            for (int i = 0; i < 8; i = i + 1) begin
                for (int j = 0; j < 8; j = j + 1) begin
                    grid[i][j] <= 2'b00;
                end
            end
            joe_x <= 0;
            joe_y <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOADING;
                        load_row_cnt <= 0;
                        done <= 0;
                    end
                end
                
                LOADING: begin
                    if (load) begin
                        load_row_cnt <= load_row_cnt + 1;
                        // Parse and Load Row Data
                        for (int i = 0; i < 8; i = i + 1) begin
                            case (row_data[i*8 +: 8])
                                8'h23: grid[row_index][i] <= 2'b01; // Wall #
                                8'h46: grid[row_index][i] <= 2'b10; // Fire F
                                8'h4A: begin 
                                    // Joe J - Joe is not stored in grid, but we record position
                                    // We clear the grid cell so Joe doesn't block fire? 
                                    // Actually, Joe is on the cell. If Joe leaves, it becomes empty.
                                    // Let's store Joe's position separately and clear the grid cell.
                                    // Or keep J in grid and treat it as Empty for fire spread? 
                                    // Let's store J in grid as 11 to mark it, but for fire logic we need to treat it as Passable initially? 
                                    // No, Joe is an entity. 
                                    // Let's store 00 in grid for Joe's position to allow fire spread logic to work naturally (if Joe leaves, fire enters).
                                    // But we need to know where Joe is.
                                    // So: 
                                    // 1. Update `joe_x`, `joe_y`.
                                    // 2. Set `grid[row_index][i]` to 00 (Empty).
                                    //    Why? Because in the simulation, if Joe leaves, the cell becomes Empty.
                                    //    And Fire logic checks neighbors for Empty.
                                    //    If Joe is there, he is an entity on top. 
                                    //    Wait, if Joe is at (1,1) and Fire at (1,2):
                                    //    `grid[1][1] = 00`.
                                    //    `grid[1][2] = 10`.
                                    //    Fire spread: checks neighbors of (1,2). Sees (1,1) is 00. Spreads to (1,1) in `temp_grid`.
                                    //    Loss check: `temp_grid[1][1]` is 10 -> Lose. Correct.
                                    //    
                                    //    So storing 00 for Joe's cell in `grid` is correct for fire logic.
                                    //    But wait, if Joe is in a cell, can Fire spread there? 
                                    //    "Fire spreads to adjacent '.' or 'J' cells".
                                    //    So Fire CAN enter Joe's cell.
                                    //    So `grid` should be 00 (Empty/Passable) where Joe is.
                                    //    Yes.
                                    grid[row_index][i] <= 2'b00;
                                    joe_x <= i;
                                    joe_y <= row_index;
                                end
                                default: grid[row_index][i] <= 2'b00; // Empty .
                            endcase
                        end
                    end
                    if (load_row_cnt == 7 && load) begin // 8th row loaded (indices 0-7, count 1-8)
                        state <= SIMULATING;
                        cycle_count <= 0;
                    end
                end
                
                SIMULATING: begin
                    if (found_escape) begin
                        result <= 1;
                        escape_time <= cycle_count + 1; // Time taken (1-based)
                        done <= 1;
                        state <= DONE;
                    end else if (collision_detected) begin
                        result <= 0;
                        done <= 1;
                        state <= DONE;
                    end else if (cycle_count >= 63) begin // Time out
                        result <= 0;
                        done <= 1;
                        state <= DONE;
                    end else begin
                        // Update Grid with Fire Spread
                        grid <= temp_grid;
                        // Update Joe Position
                        joe_x <= next_joe_x;
                        joe_y <= next_joe_y;
                        // Increment Cycle
                        cycle_count <= next_cycle_count;
                    end
                end
                
                DONE: begin
                    // Hold state until reset or start again? 
                    // Usually done stays high until reset.
                    // If we want to restart on start, we might clear done here.
                    // Let's clear done if start is asserted (restart).
                    if (start) begin
                        done <= 0;
                        state <= LOADING; // Or IDLE, let's go to IDLE to wait for start
                        state <= IDLE;
                        load_row_cnt <= 0;
                    end
                end
            endcase
        end
    end

endmodule