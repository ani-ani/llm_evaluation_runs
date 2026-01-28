module TreasureHunt (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:255],
    input wire [7:0] K,
    output reg [7:0] result,
    output reg done
);
    // Terrain costs
    localparam [7:0] COST_PLAIN = 8'd1;
    localparam [7:0] COST_FOREST = 8'd2;
    localparam [7:0] COST_MOUNTAIN = 8'd3;
    localparam [7:0] COST_RIVER = 8'd255; // Blocked
    localparam [7:0] VAL_RIVER = 8'd3;
    localparam [7:0] VAL_GOAL = 8'd5;
    
    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_GOAL = 3'd1;
    localparam [2:0] EXPAND_NEIGHBORS = 3'd2;
    localparam [2:0] CALCULATE_NEXT = 3'd3;
    localparam [2:0] UPDATE_VISITED_PUSH = 3'd4;
    localparam [2:0] DONE = 3'd5;
    localparam [2:0] IMPOSSIBLE = 3'd6;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] current_row;
    reg [7:0] current_col;
    reg [7:0] current_stamina;
    reg [7:0] current_days;
    
    // Neighbor expansion control
    reg [1:0] neighbor_dir; // 0: Up, 1: Down, 2: Left, 3: Right
    reg [7:0] next_row;
    reg [7:0] next_col;
    reg [7:0] terrain_cost;
    reg [7:0] new_stamina;
    reg [7:0] new_days;
    
    // Visited array: 16x16, stores max stamina remaining (8-bit)
    reg [7:0] visited [0:15][0:15];
    
    // FIFO Queue: 1024 entries max
    localparam FIFO_DEPTH = 1024;
    localparam FIFO_ADDR_WIDTH = 10;
    reg [7:0] queue_row [0:FIFO_DEPTH-1];
    reg [7:0] queue_col [0:FIFO_DEPTH-1];
    reg [7:0] queue_stamina [0:FIFO_DEPTH-1];
    reg [7:0] queue_days [0:FIFO_DEPTH-1];
    
    reg [FIFO_ADDR_WIDTH-1:0] wr_ptr;
    reg [FIFO_ADDR_WIDTH-1:0] rd_ptr;
    reg [FIFO_ADDR_WIDTH-1:0] item_count;
    reg queue_empty;
    reg queue_full;
    
    // Cycle counter to prevent infinite loops
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd4096; // Large enough for BFS on 16x16

    // Helper: Get cost from terrain value
    wire [7:0] calc_cost;
    assign calc_cost = (grid[next_row * 16 + next_col] == VAL_RIVER) ? COST_RIVER :
                       (grid[next_row * 16 + next_col] == 8'd1) ? COST_FOREST :
                       (grid[next_row * 16 + next_col] == 8'd2) ? COST_MOUNTAIN :
                       COST_PLAIN;

    // Update status flags
    always @(*) begin
        queue_empty = (item_count == 8'd0);
        queue_full = (item_count == FIFO_DEPTH[9:0]);
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            wr_ptr <= 10'd0;
            rd_ptr <= 10'd0;
            item_count <= 10'd0;
            // Initialize visited array (manual loop)
            for (int i = 0; i < 16; i = i + 1) begin
                for (int j = 0; j < 16; j = j + 1) begin
                    visited[i][j] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        // Reset queue pointers
                        wr_ptr <= 10'd0;
                        rd_ptr <= 10'd0;
                        item_count <= 10'd0;
                        
                        // Reset visited (manual loop)
                        for (int i = 0; i < 16; i = i + 1) begin
                            for (int j = 0; j < 16; j = j + 1) begin
                                visited[i][j] <= 8'd0;
                            end
                        end
                        
                        // Find Start (S=4) and Goal (G=5)
                        // S is effectively plain. Start at max stamina K.
                        // Push S to queue.
                        // Note: Grid scanning is combinational or requires state.
                        // We assume S is at a known location or we search.
                        // Since S is a specific value, we need to find it.
                        // We'll just scan in IDLE or a dedicated state.
                        // For simplicity, let's assume we have a small block to find S.
                        // Here, we push the first found S (row 0, col 0 loop).
                        
                        // Actually, let's just push the start node logic here.
                        // But we need to know S position.
                        // Let's add a sub-state or assume S is at (0,0) for hardware efficiency if not specified.
                        // The prompt implies S is in the grid.
                        // We will search for S in the IDLE state.
                        
                        // Re-queue logic for S:
                        // We iterate row 0-15, col 0-15 in separate cycles to avoid huge logic.
                        // Or just find S immediately.
                        // For this implementation, let's search for S in IDLE state logic.
                        // But Verilog doesn't like loops with delays easily without state.
                        // Let's assume we have a 'start_search' signal to find S.
                        // We will modify IDLE to search for S. Since N, M <= 16, 256 checks is fast.
                        // To keep it 1-cycle start, we'll do the search in a separate 'INIT' state or inside IDLE with a counter.
                        
                        state <= CHECK_GOAL; // Using CHECK_GOAL phase to actually find Start node initially
                        neighbor_dir <= 2'd0; // Reset dir
                        // Reset visited for S specifically is handled in CHECK_GOAL logic for Start
                    end
                end
                
                // This state handles finding Start initially, or checking current node for Goal
                CHECK_GOAL: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // If we are just starting (rd_ptr == wr_ptr), find Start
                    if (item_count == 10'd0 && !start) begin
                        // This implies we are initializing or running.
                        // If item_count is 0 and state is CHECK_GOAL, it means queue is empty.
                        // We need to find the Start node 'S' (value 4).
                        // Since we need to scan, we can do it here or have a dedicated scanner.
                        // Let's use a specific counter for initialization if needed.
                        // Actually, 'start' pulse is 1 cycle. We need to handle initialization.
                        // Let's add an INIT state to find S and push it.
                        // Revising FSM to add INIT.
                    end else begin
                        // Normal BFS Check
                        // If queue empty, impossible
                        if (queue_empty) begin
                            result <= 8'd255;
                            state <= DONE;
                        end else begin
                            // Peek current node
                            // Check if it is Goal
                            // Grid index = current_row * 16 + current_col
                            if (grid[current_row * 16 + current_col] == VAL_GOAL) begin
                                result <= current_days;
                                state <= DONE;
                            end else begin
                                // Not goal, expand neighbors
                                neighbor_dir <= 2'd0;
                                state <= EXPAND_NEIGHBORS;
                            end
                        end
                    end
                end
                
                EXPAND_NEIGHBORS: begin
                    // Calculate neighbor coordinates based on direction
                    case (neighbor_dir)
                        2'd0: begin // Up
                            next_row = (current_row > 0) ? current_row - 8'd1 : 8'd16; // Invalid if 16
                            next_col = current_col;
                        end
                        2'd1: begin // Down
                            next_row = (current_row < 15) ? current_row + 8'd1 : 8'd16;
                            next_col = current_col;
                        end
                        2'd2: begin // Left
                            next_row = current_row;
                            next_col = (current_col > 0) ? current_col - 8'd1 : 8'd16;
                        end
                        2'd3: begin // Right
                            next_row = current_row;
                            next_col = (current_col < 15) ? current_col + 8'd1 : 8'd16;
                        end
                        default: begin
                            next_row = 8'd16;
                            next_col = 8'd16;
                        end
                    endcase
                    
                    state <= CALCULATE_NEXT;
                end
                
                CALCULATE_NEXT: begin
                    // Check bounds and river
                    if (next_row < 16 && next_col < 16) begin
                        terrain_cost <= calc_cost;
                        
                        // Check visited later, but calculate new values now
                        if (current_stamina >= calc_cost) begin
                            new_stamina <= current_stamina - calc_cost;
                            new_days <= current_days;
                        end else begin
                            if (K >= calc_cost) begin
                                new_stamina <= K - calc_cost;
                                new_days <= current_days + 8'd1;
                            end else begin
                                // Stamina too low even after rest
                                new_stamina <= 8'd255; // Mark invalid
                            end
                        end
                        
                        state <= UPDATE_VISITED_PUSH;
                    end else begin
                        // Out of bounds, skip to next neighbor
                        if (neighbor_dir == 2'd3) begin
                            // Pop next item from queue
                            state <= POP_QUEUE;
                        end else begin
                            neighbor_dir <= neighbor_dir + 2'd1;
                            state <= EXPAND_NEIGHBORS;
                        end
                    end
                end
                
                UPDATE_VISITED_PUSH: begin
                    // Only proceed if valid stamina calculation
                    if (new_stamina < 8'd255 && calc_cost != COST_RIVER) begin
                        // Check visited
                        if (new_stamina > visited[next_row][next_col]) begin
                            // Update visited
                            visited[next_row][next_col] <= new_stamina;
                            
                            // Push to FIFO if not full
                            if (!queue_full) begin
                                queue_row[wr_ptr] <= next_row;
                                queue_col[wr_ptr] <= next_col;
                                queue_stamina[wr_ptr] <= new_stamina;
                                queue_days[wr_ptr] <= new_days;
                                wr_ptr <= wr_ptr + 10'd1;
                                item_count <= item_count + 10'd1;
                            end
                        end
                    end
                    
                    if (neighbor_dir == 2'd3) begin
                        state <= POP_QUEUE;
                    end else begin
                        neighbor_dir <= neighbor_dir + 2'd1;
                        state <= EXPAND_NEIGHBORS;
                    end
                end
                
                POP_QUEUE: begin
                    if (!queue_empty) begin
                        current_row <= queue_row[rd_ptr];
                        current_col <= queue_col[rd_ptr];
                        current_stamina <= queue_stamina[rd_ptr];
                        current_days <= queue_days[rd_ptr];
                        rd_ptr <= rd_ptr + 10'd1;
                        item_count <= item_count - 10'd1;
                    end
                    state <= CHECK_GOAL;
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Safety timeout
            if (cycle_count > MAX_CYCLES && state != IDLE && state != DONE) begin
                result <= 8'd255;
                state <= DONE;
            end
        end
    end
    
    // Special logic to handle Start node initialization
    // We need to inject the Start node 'S' into the queue when start is asserted.
    // Since start is a single pulse, we handle it in IDLE or a separate block.
    // The logic above expects the queue to have items. Let's add a dedicated Start Finder block.
    // Actually, let's modify the FSM to include an INIT state that finds S.
    
    // Rewriting the logic slightly to ensure Start is found and pushed correctly on 'start' pulse.
    // The previous FSM logic didn't account for the initial 'S' scan properly.
    // Let's stick to the previous logic but change IDLE behavior.
    
    // Correction: The above FSM has a flaw in IDLE. It sets state to CHECK_GOAL but doesn't push S.
    // We need to handle the 'start' signal effectively.
    // Let's replace IDLE with a proper Init sequence.
    
    // Reset Logic override (part 2)
    // We will use the cycle_count as a temporary index to find S in the first 256 cycles after start.
    
endmodule

// Re-implementation with correct Start Handling and single block
treasure_hunt_module my_treasure_hunt (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .grid(grid),
    .K(K),
    .result(result),
    .done(done)
);

endmodule

// Corrected Single Module Implementation
module treasure_hunt_module (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:255],
    input wire [7:0] K,
    output reg [7:0] result,
    output reg done
);
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FIND_START = 3'd1;
    localparam [2:0] CHECK_GOAL_POP = 3'd2;
    localparam [2:0] EXPAND = 3'd3;
    localparam [2:0] PROCESS_NEIGHBOR = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    localparam [2:0] IMPOSSIBLE_STATE = 3'd6;

    localparam [7:0] VAL_RIVER = 8'd3;
    localparam [7:0] VAL_GOAL = 8'd5;
    localparam [7:0] VAL_START = 8'd4;
    localparam [7:0] COST_PLAIN = 8'd1;
    localparam [7:0] COST_FOREST = 8'd2;
    localparam [7:0] COST_MOUNTAIN = 8'd3;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] current_row;
    reg [7:0] current_col;
    reg [7:0] current_stamina;
    reg [7:0] current_days;

    // Neighbor expansion
    reg [1:0] dir;
    reg [7:0] next_r;
    reg [7:0] next_c;
    reg [7:0] cost;
    reg [7:0] calc_stamina;
    reg [7:0] calc_days;

    // Visited array 16x16
    reg [7:0] visited [0:15][0:15];

    // FIFO 1024 deep
    localparam FIFO_DEPTH = 1024;
    localparam ADDR_W = 10;
    reg [7:0] q_row [0:FIFO_DEPTH-1];
    reg [7:0] q_col [0:FIFO_DEPTH-1];
    reg [7:0] q_stam [0:FIFO_DEPTH-1];
    reg [7:0] q_days [0:FIFO_DEPTH-1];
    reg [ADDR_W-1:0] wr_ptr, rd_ptr, count;
    wire empty, full;
    
    assign empty = (count == 0);
    assign full = (count == FIFO_DEPTH);

    // Timer
    reg [15:0] timeout;
    localparam MAX_TIMEOUT = 16'd4096;

    // Helper for cost
    wire [7:0] terrain_val;
    assign terrain_val = grid[next_r * 16 + next_c];

    always @(*) begin
        if (terrain_val == VAL_RIVER) cost = 8'd255;
        else if (terrain_val == 8'd1) cost = COST_FOREST;
        else if (terrain_val == 8'd2) cost = COST_MOUNTAIN;
        else cost = COST_PLAIN;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
            timeout <= 0;
            // Reset visited
            for (int i = 0; i < 16; i = i + 1)
                for (int j = 0; j < 16; j = j + 1)
                    visited[i][j] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    timeout <= 0;
                    wr_ptr <= 0;
                    rd_ptr <= 0;
                    count <= 0;
                    // Reset visited
                    for (int i = 0; i < 16; i = i + 1)
                        for (int j = 0; j < 16; j = j + 1)
                            visited[i][j] <= 8'd0;
                    
                    if (start) begin
                        state <= FIND_START;
                    end
                end

                FIND_START: begin
                    // We need to scan grid to find S (val 4).
                    // We can use 'timeout' as a scanning index.
                    if (timeout < 16'd256) begin
                        if (grid[timeout] == VAL_START) begin
                            // Found S. Convert index to row/col.
                            current_row <= timeout[7:4]; // 4 bits for 0-15
                            current_col <= timeout[3:0];
                            current_stamina <= K;
                            current_days <= 0;
                            // Push to FIFO (simulating the start node)
                            // Actually, we can just start processing from here,
                            // but for consistency, let's push it and jump to POP.
                            // Or simply set current node and go to CHECK_GOAL.
                            // Let's set current node directly.
                            state <= CHECK_GOAL_POP;
                            timeout <= 0; // Reset timeout for BFS execution
                        end else begin
                            timeout <= timeout + 1;
                        end
                    end else begin
                        // S not found (or grid empty)
                        state <= IMPOSSIBLE_STATE;
                    end
                end

                CHECK_GOAL_POP: begin
                    // Check if current node is Goal
                    if (grid[current_row * 16 + current_col] == VAL_GOAL) begin
                        result <= current_days;
                        state <= FINISH;
                    end else begin
                        // Check if we need to pop from queue (if current node is done)
                        // We process the current node (already popped or start node).
                        // We expand neighbors.
                        dir <= 0;
                        state <= EXPAND;
                    end
                    timeout <= timeout + 1;
                    if (timeout > MAX_TIMEOUT) state <= IMPOSSIBLE_STATE;
                end

                EXPAND: begin
                    // Calculate next coordinates
                    case (dir)
                        2'd0: begin next_r = (current_row > 0) ? current_row - 1 : 16; next_c = current_col; end
                        2'd1: begin next_r = (current_row < 15) ? current_row + 1 : 16; next_c = current_col; end
                        2'd2: begin next_r = current_row; next_c = (current_col > 0) ? current_col - 1 : 16; end
                        2'd3: begin next_r = current_row; next_c = (current_col < 15) ? current_col + 1 : 16; end
                    endcase
                    state <= PROCESS_NEIGHBOR;
                end

                PROCESS_NEIGHBOR: begin
                    // Default to next dir
                    if (dir == 3) begin
                        // Finished neighbors, get next from queue
                        if (!empty) begin
                            current_row <= q_row[rd_ptr];
                            current_col <= q_col[rd_ptr];
                            current_stamina <= q_stam[rd_ptr];
                            current_days <= q_days[rd_ptr];
                            rd_ptr <= rd_ptr + 1;
                            count <= count - 1;
                            state <= CHECK_GOAL_POP;
                        end else begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end else begin
                        dir <= dir + 1;
                        state <= EXPAND;
                    end

                    // Logic for the neighbor (next_r, next_c)
                    if (next_r < 16 && next_c < 16) begin
                        // Check cost
                        // Note: cost is combinational based on next_r/c
                        if (cost != 8'd255) begin // Not River
                            if (current_stamina >= cost) begin
                                calc_stamina <= current_stamina - cost;
                                calc_days <= current_days;
                            end else begin
                                if (K >= cost) begin
                                    calc_stamina <= K - cost;
                                    calc_days <= current_days + 1;
                                end else begin
                                    calc_stamina <= 8'd255; // Invalid
                                end
                            end
                            
                            // Check visited after calculating
                            if (calc_stamina != 8'd255) begin
                                // We need a state to update visited/push to handle the synchronous update properly
                                // But we are in PROCESS_NEIGHBOR. 
                                // Let's separate the update logic.
                                // Re-routing: PROCESS_NEIGHBOR calculates, then goes to PUSH state.
                                // But we want to continue expansion in parallel if possible.
                                // For simplicity: Calculate in PROCESS_NEIGHBOR, Update in a separate state or inline.
                                // Let's inline it but handle the push carefully.
                                
                                if (calc_stamina > visited[next_r][next_c]) begin
                                    visited[next_r][next_c] <= calc_stamina;
                                    if (!full) begin
                                        q_row[wr_ptr] <= next_r;
                                        q_col[wr_ptr] <= next_c;
                                        q_stam[wr_ptr] <= calc_stamina;
                                        q_days[wr_ptr] <= calc_days;
                                        wr_ptr <= wr_ptr + 1;
                                        count <= count + 1;
                                    end
                                end
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                IMPOSSIBLE_STATE: begin
                    result <= 8'd255;
                    state <= FINISH;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule