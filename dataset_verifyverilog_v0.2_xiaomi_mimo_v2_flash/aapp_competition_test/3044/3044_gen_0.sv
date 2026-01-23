module robot_path_fixer(
    input clk,
    input rst_n,
    input start,
    input [1:0] grid [0:15],
    input [2:0] cmd_length,
    input [7:0] commands,
    output reg [2:0] min_edits,
    output reg done
);

    // State machine encoding
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        EXPLORE_STATE = 3'b001,
        CHECK_GOAL = 3'b010,
        UPDATE_QUEUE = 3'b011,
        DONE = 3'b100
    } state_t;
    
    state_t current_state, next_state;

    // State encoding: {pos_x[1:0], pos_y[1:0], cmd_idx[2:0], edits[1:0]} = 8 bits
    // pos: 0-3 (2 bits), idx: 0-7 (3 bits), edits: 0-3 (2 bits) -> total 7 bits? 
    // Wait: pos_x (2), pos_y (2), cmd_idx (3), edits (2) = 9 bits.
    // But spec says: {pos_x[1:0], pos_y[1:0], cmd_idx[2:0], edits[1:0]}
    // Total: 2+2+3+2 = 9 bits.
    // Visited array size: 512 bits -> 2^9. Correct.
    
    wire [8:0] current_state_val;
    assign current_state_val = {curr_pos_x, curr_pos_y, curr_idx, curr_edits};

    // Internal Registers
    reg [2:0] curr_pos_x;
    reg [2:0] curr_pos_y; // Using 3 bits for simplicity, top bit ignored for grid 0-3
    reg [2:0] curr_idx;
    reg [2:0] curr_edits;
    
    // Queue: 64 entries, 9 bits each
    reg [8:0] queue [0:63];
    reg [5:0] head; // Write pointer
    reg [5:0] tail; // Read pointer
    reg [5:0] next_head;
    reg [5:0] next_tail;
    
    // Visited array: 512 bits (2^9)
    reg [511:0] visited;
    reg [511:0] next_visited;
    
    // Temporary storage for exploration
    reg [2:0] temp_pos_x;
    reg [2:0] temp_pos_y;
    reg [2:0] temp_idx;
    reg [2:0] temp_edits;
    reg [2:0] cmd; // Current command being processed (if any)
    
    // Control signals
    reg load_start;
    reg explore_op;
    reg check_res;
    reg update_q;
    
    // Exploration iteration counter (0, 1, 2, 3, 4)
    // 0: Execute (if valid)
    // 1: Delete
    // 2: Insert U
    // 3: Insert D
    // 4: Insert L
    // 5: Insert R
    reg [2:0] expl_step;
    reg [2:0] next_expl_step;
    
    // Grid Access
    wire [1:0] grid_content;
    assign grid_content = grid[curr_pos_y * 4 + curr_pos_x];
    
    // Helper logic for command extraction
    wire [1:0] current_cmd;
    assign current_cmd = (curr_idx < cmd_length) ? 
                        (curr_idx == 0 ? commands[1:0] :
                         curr_idx == 1 ? commands[3:2] :
                         curr_idx == 2 ? commands[5:4] :
                         curr_idx == 3 ? commands[7:6] :
                         curr_idx == 4 ? commands[9:8] :
                         curr_idx == 5 ? commands[11:10] :
                         curr_idx == 6 ? commands[13:12] :
                         commands[15:14]) : 2'b00;

    // Move direction logic
    reg [2:0] new_x, new_y;
    always @(*) begin
        new_x = curr_pos_x;
        new_y = curr_pos_y;
        if (explore_op) begin
            if (expl_step == 3'd0) begin // Execute
                case(current_cmd)
                    2'b00: new_x = (curr_pos_x > 0) ? curr_pos_x - 1 : curr_pos_x; // L
                    2'b01: new_x = (curr_pos_x < 3) ? curr_pos_x + 1 : curr_pos_x; // R
                    2'b10: new_y = (curr_pos_y > 0) ? curr_pos_y - 1 : curr_pos_y; // U
                    2'b11: new_y = (curr_pos_y < 3) ? curr_pos_y + 1 : curr_pos_y; // D
                endcase
            end else if (expl_step >= 3'd2) begin // Insert (2:U, 3:D, 4:L, 5:R)
                case(expl_step)
                    3'd2: new_y = (curr_pos_y > 0) ? curr_pos_y - 1 : curr_pos_y; // U
                    3'd3: new_y = (curr_pos_y < 3) ? curr_pos_y + 1 : curr_pos_y; // D
                    3'd4: new_x = (curr_pos_x > 0) ? curr_pos_x - 1 : curr_pos_x; // L
                    3'd5: new_x = (curr_pos_x < 3) ? curr_pos_x + 1 : curr_pos_x; // R
                endcase
            end
        end
    end
    
    // Check if move is valid (not obstacle)
    wire move_valid;
    assign move_valid = (grid[new_y * 4 + new_x] != 2'b01); // 1 is obstacle
    
    // Check start and goal for debug/initialization
    wire [3:0] start_pos;
    wire [3:0] goal_pos;
    reg start_found;
    reg goal_found;
    
    // Search for Start and Goal positions in grid (combinational for init)
    // To be safe and synthesizable, we can do this in FSM or a simple loop.
    // Since we need it only at start, we'll do it in IDLE or an init state.
    // But let's assume we need to find start position to initialize queue.
    // We will do a sequential scan in IDLE state.
    
    reg [3:0] scan_idx;
    reg [2:0] found_start_x, found_start_y;
    
    // Update Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            visited <= 0;
            head <= 0;
            tail <= 0;
            min_edits <= 3'd4;
            done <= 0;
            expl_step <= 0;
            scan_idx <= 0;
            start_found <= 0;
            goal_found <= 0;
        end else begin
            // Default updates
            visited <= next_visited;
            head <= next_head;
            tail <= next_tail;
            expl_step <= next_expl_step;
            current_state <= next_state;
            
            // Update Scan logic
            if (current_state == IDLE && start) begin
                if (!start_found) begin
                    if (grid[scan_idx] == 2'b10) begin // Start
                        found_start_x <= scan_idx % 4;
                        found_start_y <= scan_idx / 4;
                        start_found <= 1'b1;
                    end
                    if (scan_idx < 15) scan_idx <= scan_idx + 1;
                    else scan_idx <= 0;
                end else if (start_found && !done && !start) begin
                    // Wait for start to go low to prevent re-triggering? 
                    // Actually, start is handled in transition logic.
                end
            end else if (current_state != IDLE) begin
                // Reset scan counters when active computation is happening
                // (Though we don't need to scan again)
            end
            
            // Update Queue Data
            if (update_q) begin
                // Queue write happens if valid new state found
                // Handled in combinational logic block below to drive signals
            end
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        // Defaults
        next_state = current_state;
        next_visited = visited;
        next_head = head;
        next_tail = tail;
        next_expl_step = expl_step;
        
        done = (current_state == DONE);
        
        // Control signals defaults
        load_start = 0;
        explore_op = 0;
        check_res = 0;
        update_q = 0;
        
        // Data defaults
        temp_pos_x = curr_pos_x;
        temp_pos_y = curr_pos_y;
        temp_idx = curr_idx;
        temp_edits = curr_edits;
        
        case (current_state)
            IDLE: begin
                if (start && start_found) begin
                    load_start = 1;
                    next_state = EXPLORE_STATE;
                    next_expl_step = 0;
                end else begin
                    next_state = IDLE;
                end
            end
            
            EXPLORE_STATE: begin
                explore_op = 1;
                // Check if we have finished exploring this state (all 5 ops)
                if (expl_step > 3'd4) begin // 0,1,2,3,4 processed (5 steps)
                    next_state = UPDATE_QUEUE;
                    next_expl_step = 0;
                end else begin
                    // Analyze current step
                    // Logic depends on step type
                    
                    // Step 0: Execute
                    if (expl_step == 3'd0) begin
                        if (curr_idx < cmd_length && move_valid) begin
                            // Valid execute: push new state
                            // We need to check visited in UPDATE_QUEUE or here.
                            // Let's prepare the candidate state in temp regs
                            temp_pos_x = new_x;
                            temp_pos_y = new_y;
                            temp_idx = curr_idx + 1;
                            temp_edits = curr_edits;
                            // Mark intent to update
                            update_q = 1; 
                            // Note: We need to ensure we don't skip next step.
                            // The FSM should move to next step immediately or wait?
                            // Since UPDATE_QUEUE is a separate state, let's transition there.
                            // Actually, spec says states: IDLE, EXPLORE, CHECK, UPDATE, DONE.
                            // Let's interpret CHECK_GOAL as: Check if candidate reaches goal.
                            
                            // Modification to spec interpretation: 
                            // 1. EXPLORE_STATE generates candidate.
                            // 2. CHECK_GOAL checks if candidate hits goal.
                            // 3. UPDATE_QUEUE adds to queue.
                            
                            next_state = CHECK_GOAL;
                        end else begin
                            // Invalid execute (blocked or end of cmd), try next operation
                            next_expl_step = expl_step + 1;
                        end
                    end
                    // Step 1: Delete
                    else if (expl_step == 3'd1) begin
                        if (curr_idx < cmd_length) begin
                            temp_idx = curr_idx + 1;
                            temp_edits = curr_edits + 1;
                            if (temp_edits <= 3'd4) begin // Max edits constraint
                                update_q = 1;
                                next_state = CHECK_GOAL;
                            end else begin
                                next_expl_step = expl_step + 1;
                            end
                        end else begin
                            next_expl_step = expl_step + 1;
                        end
                    end
                    // Step 2-5: Insert
                    else begin // 2, 3, 4, 5
                        if (curr_edits < 3'd4) begin // Can insert?
                            if (move_valid) begin
                                temp_edits = curr_edits + 1;
                                // idx stays same
                                temp_pos_x = new_x;
                                temp_pos_y = new_y;
                                update_q = 1;
                                next_state = CHECK_GOAL;
                            end else begin
                                next_expl_step = expl_step + 1;
                            end
                        end else begin
                            next_expl_step = expl_step + 1;
                        end
                    end
                end
            end
            
            CHECK_GOAL: begin
                // Check if temp_pos_x/y is goal
                check_res = 1;
                if (grid[temp_pos_y * 4 + temp_pos_x] == 2'b11) begin
                    // Goal reached
                    // Since we use BFS, the first time we reach goal is minimum edits
                    // However, we need to wait for all states with same edits to be processed?
                    // No, BFS goes level by level (edit distance). 
                    // If we find goal at current edits, it is the answer.
                    next_state = DONE;
                end else begin
                    next_state = UPDATE_QUEUE;
                end
            end
            
            UPDATE_QUEUE: begin
                // Add temp state to queue if not visited
                // Compute address for visited array
                // Address = {temp_pos_x, temp_pos_y, temp_idx, temp_edits}
                // Check bit in visited
                if (!visited[{temp_pos_x, temp_pos_y, temp_idx, temp_edits}]) begin
                    // Add to queue
                    // Need to handle wrap-around for queue size 64
                    // Assuming we can write to head
                    next_head = head + 1;
                    // Update visited (we need to set the bit)
                    next_visited = visited | (1'b1 << {temp_pos_x, temp_pos_y, temp_idx, temp_edits});
                end
                
                // Return to EXPLORE or DONE
                // If we found goal in previous state, we might have gone DONE directly.
                // So here we just increment step or finish.
                
                if (expl_step > 3'd4) begin
                    // Should not happen (caught in EXPLORE)
                    // But if we finished processing current queue element:
                    // Move to next element in queue
                    if (tail == head) begin
                        // Queue empty
                        next_state = DONE;
                        // min_edits should be 4 (default) or updated
                    end else begin
                        // Dequeue
                        next_tail = tail + 1;
                        // Load state into curr registers
                        // This logic is tricky in combinational block without explicit wires.
                        // We need to transfer 'queue[tail]' to 'curr_pos_x' etc.
                        // Since we are in UPDATE_QUEUE (after processing one candidate)
                        // we actually need to fetch the NEXT state to explore.
                        
                        // Let's redesign the flow slightly to be safe for synthesis.
                        // EXPLORE_STATE: Reads curr_*, generates candidates.
                        // UPDATE_QUEUE: Writes candidate to queue (or marks visited).
                        // Then returns to EXPLORE_STATE to generate next candidate.
                        // But when all candidates generated, we need to pop next state.
                        
                        // Wait, we are in a loop over expl_step (0..4).
                        // When expl_step hits 5, we go to UPDATE_QUEUE (via EXPLORE).
                        // Wait, EXPLORE jumps to CHECK_GOAL.
                        
                        // Let's simplify the flow in code:
                        // 1. EXPLORE: If expl_step < 5, generate candidate -> CHECK_GOAL.
                        // 2. CHECK_GOAL: If goal -> DONE. Else -> UPDATE_QUEUE.
                        // 3. UPDATE_QUEUE: Push if valid. Then -> EXPLORE.
                        // 4. EXPLORE: If expl_step reaches 5, -> EXHAUSTED (New state).
                        
                        // Wait, if expl_step reaches 5, we are done with current state.
                        // We need to pop next state from queue.
                        
                        // Let's add an EXHAUSTED state or logic.
                        // We will check expl_step in UPDATE_QUEUE to decide.
                        // Actually, let's handle the pop in UPDATE_QUEUE.
                        
                        if (expl_step > 3'd4) begin
                             // We have finished the loop for the current state.
                             // Check if queue empty.
                             if (tail == head) begin
                                 next_state = DONE;
                             end else begin
                                 // Pop next state from queue
                                 // Need to wait one cycle to read memory? 
                                 // FPGA block ram is synchronous. 
                                 // We need to register the popped value.
                                 
                                 // Let's change: UPDATE_QUEUE sets signal to pop.
                                 // Then we go to a state LOAD_STATE.
                                 // Let's modify the plan:
                                 // UPDATE_QUEUE (step done) -> IDLE? No.
                                 // Let's add a state FETCH_STATE.
                                 
                                 // But spec said specific states. 
                                 // Can we do it in UPDATE_QUEUE? 
                                 // If we output the next state from queue combinationaly to 'next_curr' regs,
                                 // then update them on clock edge.
                                 
                                 // Let's assume we can read queue[tail] and assign to temp.
                                 // Then on clock edge, curr = temp.
                                 
                                 temp_pos_x = queue[tail][8:7];
                                 temp_pos_y = queue[tail][6:5];
                                 temp_idx = queue[tail][4:2];
                                 temp_edits = queue[tail][1:0];
                                 
                                 // Note: We are writing to 'temp' vars which are used to update curr_* 
                                 // only if we are in a specific loading mode.
                                 // Since we don't have explicit load state, let's use UPDATE_QUEUE.
                                 // When expl_step > 4, we are fetching new state.
                                 
                                 // But 'update_q' implies writing. 
                                 // Let's distinguish: 
                                 // When expl_step > 4: We are doing POP. 
                                 // We need to transfer queue[tail] to curr registers.
                                 
                                 // Special handling: If we are done with steps, we pop.
                                 // We'll check 'expl_step' in the clocked block to update curr_*.
                                 
                                 next_tail = tail + 1;
                                 next_expl_step = 0; // Reset step for new state
                                 next_state = EXPLORE_STATE;
                             end
                        end else begin
                            // We pushed a candidate (or failed). Continue exploring current state.
                            next_expl_step = expl_step + 1;
                            next_state = EXPLORE_STATE;
                        end
                    end
                end
            end
            
            DONE: begin
                // Hold state
                next_state = DONE;
            end
        endcase
        
        // Special case for CHECK_GOAL finding goal: Force DONE
        if (current_state == CHECK_GOAL && grid[temp_pos_y * 4 + temp_pos_x] == 2'b11) begin
            next_state = DONE;
        end
    end

    // Sequential Logic Part 2: Register Updates (Populating from Queue)
    // We need to handle the 'Load from Queue' action which happens in UPDATE_QUEUE when expl_step > 4
    // But the combinational logic above sets next_expl_step = 0 etc.
    // We need to update curr_* values.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_pos_x <= 0;
            curr_pos_y <= 0;
            curr_idx <= 0;
            curr_edits <= 0;
            min_edits <= 4;
        end else begin
            if (current_state == IDLE && start && start_found) begin
                curr_pos_x <= found_start_x;
                curr_pos_y <= found_start_y;
                curr_idx <= 0;
                curr_edits <= 0;
            end
            else if (current_state == DONE) begin
                // Update min_edits if we found goal
                if (grid[temp_pos_y * 4 + temp_pos_x] == 2'b11 && current_state != DONE) begin
                   // This check is redundant if we transition to DONE properly
                   min_edits <= temp_edits;
                end else if (current_state == CHECK_GOAL && grid[temp_pos_y * 4 + temp_pos_x] == 2'b11) begin
                   min_edits <= temp_edits;
                end
                // If queue exhausted, min_edits remains 4 (default max)
            end
            else if (current_state == UPDATE_QUEUE && expl_step > 3'd4) begin
                // We are popping a new state from the queue
                // Update curr registers
                curr_pos_x <= queue[tail][8:7];
                curr_pos_y <= queue[tail][6:5];
                curr_idx <= queue[tail][4:2];
                curr_edits <= queue[tail][1:0];
            end
            else if (current_state == CHECK_GOAL && grid[temp_pos_y * 4 + temp_pos_x] == 2'b11) begin
                // Goal reached. Capture edits.
                min_edits <= temp_edits;
            end
        end
    end
    
    // Queue Write Logic
    // We need to write 'temp' state to 'queue[head]' when update_q is high.
    // And write popped state to 'queue[tail]' logic is read-only.
    always @(posedge clk) begin
        if (update_q) begin
            // Only write if not visited (checked in combinational logic, but good to gate)
            // The combinational next_visited logic sets the bit. 
            // We assume update_q is only high when valid.
            queue[head] <= {temp_pos_x[1:0], temp_pos_y[1:0], temp_idx, temp_edits};
        end
    end

endmodule
