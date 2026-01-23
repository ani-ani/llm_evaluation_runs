module three_states_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_flat [0:15],
    output reg [7:0] min_cost,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam BFS1 = 3'b001;
    localparam BFS2 = 3'b010;
    localparam BFS3 = 3'b011;
    localparam CALCULATE = 3'b100;
    localparam DONE_STATE = 3'b101;

    reg [2:0] state;
    
    // Grid RAMs for distance storage (16 entries, 8-bit depth)
    // Using 3 separate RAMs for distances from '1', '2', '3'
    reg [7:0] dist1 [0:15];
    reg [7:0] dist2 [0:15];
    reg [7:0] dist3 [0:15];
    
    // RAM read/write interfaces
    reg [3:0] ram_addr;
    reg [7:0] ram_wr_data;
    reg ram_wr_en;
    reg [2:0] ram_select; // 1=dist1, 2=dist2, 3=dist3
    
    // BFS registers
    reg [3:0] q [0:15]; // Queue storage (depth 16)
    reg [3:0] q_head;
    reg [3:0] q_tail;
    reg [3:0] q_count;
    reg q_pop;
    reg q_push;
    reg [3:0] q_push_data;
    
    // BFS current cell and step counters
    reg [3:0] curr_idx;
    reg [3:0] step_counter;
    reg bfs_start_pulse;
    
    // Calculation stage registers
    reg [3:0] calc_idx;
    reg [7:0] current_sum;
    reg [7:0] best_cost;
    
    // Helper wires for grid access
    wire [7:0] grid_char = grid_flat[ram_addr]; // Used to check neighbors
    
    // Neighbor offsets (up, down, left, right)
    reg [3:0] neighbor_offset;
    reg [3:0] neighbor_idx;
    reg neighbor_valid;
    
    // Internal status flags
    reg bfs_done;
    reg [7:0] start_pos; // Encoded position of the current state
    reg [7:0] dist_val;  // Value to write to RAM
    reg [7:0] temp_dist; // For reading distances
    reg [7:0] neighbor_dist; // Neighbor distance for comparison
    
    integer i;

    // --- Sequential Logic ---
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_cost <= 0;
            ram_wr_en <= 0;
            q_head <= 0;
            q_tail <= 0;
            q_count <= 0;
            step_counter <= 0;
            bfs_start_pulse <= 0;
            calc_idx <= 0;
            best_cost <= 8'hFF;
            done <= 0;
        end else begin
            ram_wr_en <= 0; // Default no write
            q_pop <= 0;
            q_push <= 0;
            bfs_start_pulse <= 0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= BFS1;
                        bfs_start_pulse <= 1;
                        done <= 0;
                        best_cost <= 8'hFF;
                        calc_idx <= 0;
                    end
                end
                
                BFS1: begin
                    if (bfs_done) begin
                        state <= BFS2;
                        bfs_start_pulse <= 1;
                    end
                end
                
                BFS2: begin
                    if (bfs_done) begin
                        state <= BFS3;
                        bfs_start_pulse <= 1;
                    end
                end
                
                BFS3: begin
                    if (bfs_done) begin
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    // Iterate through all 16 cells to find min(dist1 + dist2 + dist3)
                    // Reads are handled by combinational logic based on calc_idx
                    // We accumulate 3 cycles per index to read all 3 distances sequentially in this state machine
                    // Simplification: Assume we can read all 3 dist values in a cycle or pipeline it.
                    // Here we update best_cost and move to next index.
                    // Cycle 0: Read dist1[calc_idx]
                    // Cycle 1: Read dist2[calc_idx]
                    // Cycle 2: Read dist3[calc_idx] -> Accumulate
                    
                    // To strictly follow the "sequential module" and state machine req, let's step through.
                    // Let's treat CALCULATE as a process that iterates 16 times.
                    // We need to access dist arrays. 
                    // Let's use a sub-step counter for CALCULATE state.
                    // Sub-step 0: Read dist1
                    // Sub-step 1: Read dist2
                    // Sub-step 2: Read dist3, check validity, update best_cost, increment calc_idx
                    
                    step_counter <= step_counter + 1;
                    
                    if (step_counter == 3'd0) begin
                        // Read dist1 (happens via ram_addr assignment)
                        // We need to store it temporarily
                        current_sum <= dist1[calc_idx]; // Assuming dist1 is accessible directly or via RAM logic
                    end else if (step_counter == 3'd1) begin
                        current_sum <= current_sum + dist2[calc_idx];
                    end else if (step_counter == 3'd2) begin
                        current_sum <= current_sum + dist3[calc_idx];
                        if (dist1[calc_idx] != 8'hFF && dist2[calc_idx] != 8'hFF && dist3[calc_idx] != 8'hFF) begin
                            if (current_sum + dist3[calc_idx] < best_cost)
                                best_cost <= current_sum + dist3[calc_idx];
                        end
                    end else if (step_counter == 3'd3) begin
                        // Move to next index
                        step_counter <= 0;
                        if (calc_idx == 15) begin
                            min_cost <= best_cost;
                            state <= DONE_STATE;
                        end else begin
                            calc_idx <= calc_idx + 1;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1;
                    if (!start) state <= IDLE; // Wait for start to go low to reset
                end
            endcase
            
            // --- BFS Engine Logic (Sequential) ---
            // This logic runs in parallel or interleaved with state transitions.
            // Since the requirement says "Use state machine: IDLE, BFS1..." and "BFS must be implemented as a state machine",
            // we will run the BFS steps within the active BFS state.
            
            if (state == BFS1 || state == BFS2 || state == BFS3) begin
                // Initialization on start_pulse
                if (bfs_start_pulse) begin
                    // Reset Queue
                    q_head <= 0;
                    q_tail <= 0;
                    q_count <= 0;
                    step_counter <= 0;
                    
                    // Find start position and initialize RAM
                    // Scan grid to find '1', '2', or '3'
                    // Since we can't iterate 16 cycles easily in one start pulse without state sub-states,
                    // we will assume we search for the position in the first few cycles of the BFS state.
                    // Or simpler: The grid is static. We can hardcode lookup or use a small helper state.
                    // Let's use a lookup approach. We will iterate `curr_idx` from 0 to 15 to find the start char.
                    curr_idx <= 0;
                    
                    // Special handling: We need to initialize the start node dist to 0 and push to queue.
                    // To do this cleanly, we enter a sub-state or use the first cycle.
                    // Let's use `step_counter` as a flag: 0=Searching for start, 1=BFS loop.
                end else begin
                    if (step_counter == 0) begin
                        // Searching for start node
                        if (curr_idx < 16) begin
                            if ((state == BFS1 && grid_flat[curr_idx] == 8'd49) || // '1'
                                (state == BFS2 && grid_flat[curr_idx] == 8'd50) || // '2'
                                (state == BFS3 && grid_flat[curr_idx] == 8'd51)) begin // '3'
                                
                                // Found start node
                                // Write 0 to corresponding RAM
                                ram_addr <= curr_idx;
                                ram_wr_data <= 0;
                                if (state == BFS1) begin
                                    dist1[curr_idx] <= 0;
                                    ram_select <= 1;
                                end else if (state == BFS2) begin
                                    dist2[curr_idx] <= 0;
                                    ram_select <= 2;
                                end else begin
                                    dist3[curr_idx] <= 0;
                                    ram_select <= 3;
                                end
                                ram_wr_en <= 1;
                                
                                // Push to queue
                                q_push <= 1;
                                q_push_data <= curr_idx;
                                q_count <= 1;
                                
                                step_counter <= 1; // Switch to expansion
                                curr_idx <= curr_idx + 1; // Prepare for next search if needed (though we break)
                                // Actually, we found it, we should stop searching. 
                                // We need a flag to stop. 
                                // Let's set curr_idx to 16 to stop search loop.
                                curr_idx <= 16;
                            end else begin
                                curr_idx <= curr_idx + 1;
                            end
                        end else begin
                            // Should not happen if start is valid, but handle case where state was entered without start node
                            // Force finish BFS
                            bfs_done <= 1;
                        end
                    end else begin
                        // BFS Expansion: Queue is not empty
                        if (q_count > 0) begin
                            // Pop from queue (Read current node)
                            // The actual pop happens on next cycle, we read q[head]
                            // But Verilog queue logic is tricky without array indexing on LHS.
                            // Let's process the popped item in the next cycle.
                            // Cycle logic: 
                            // 1. Read q[head], set curr_idx = q[head], decrement count, increment head.
                            // 2. Read RAM for curr_idx (distance). (Actually we already know it, it's the frontier).
                            // 3. Check 4 neighbors.
                            // 4. Update neighbors and push.
                            
                            // Optimization: Since we have limited cycles and grid is tiny, we can do 1 neighbor per cycle or all.
                            // Requirement: "fixed maximum number of steps (e.g., 16 cycles per BFS step)"
                            // This implies we should be slow or performant. Let's process 1 neighbor per cycle to match small step count.
                            
                            // Sub-cycle logic for expansion:
                            // We need a secondary counter for neighbor ID (0-3).
                            // Let's use bits of step_counter or a new register `exp_phase`.
                            // Let's use `step_counter` high bits for phase.
                            // Phase 1: Pop (Step 1)
                            // Phase 2-5: Process Neighbors (Steps 2-5)
                            // Phase 6: Done with this node, continue queue
                            
                            // Actually, simpler approach for "BFS state machine with 16 cycles max per BFS":
                            // Since the grid has 16 cells, the total work is bounded.
                            // Let's implement the BFS logic sequentially in a single block.
                            // We need a register to track current queue head and tail.
                            
                            // To stay within the JSON format and complexity limit, let's implement a robust but compact logic.
                            // We will process one neighbor per clock cycle.
                            // Registers needed: current_node (popped), neighbor_id (0-3).
                            
                            // Define internal states for the expansion phase:
                            // EXP_POP: Read from queue, get distance.
                            // EXP_CHECK_0..3: Check neighbors.
                            
                            // Let's add a specific register for the expansion sub-state.
                            // Since we can't easily add more top-level states without clutter, we use a variable.
                            reg [2:0] exp_state;
                            
                            // Note: In SystemVerilog, we can define always_ff blocks, but sticking to always @(...) for compat.
                            // We need to declare exp_state outside the always block or use a generally scoped variable.
                            // Let's assume we declare it inside but that requires synthesizable handling (must be registered).
                            // I will declare it as a reg before the always block conceptually, but putting it inside requires care.
                            // Let's use the existing `curr_idx` and `step_counter` cleverly.
                            // `step_counter` [3:2] = sub-phase (0=Pop, 1-4=Neighbors)
                            // `step_counter` [1:0] = neighbor index 0-3.
                            
                            // Refined BFS Logic:
                            // If `step_counter` == 1: Pop from Queue (q_head, q_count).
                            //   - Set `curr_idx` to q[q_head].
                            //   - Read distance of `curr_idx` from RAM (async read, so it's ready next cycle).
                            // If `step_counter` >= 2 and <= 5: Neighbor checks.
                            //   - Identify neighbor coordinates.
                            //   - Check bounds.
                            //   - Read neighbor distance.
                            //   - If valid (grid '.' or state) and new dist < old dist, write to RAM and push to Q.
                            // If `step_counter` == 6: Increment head, check queue count.
                            
                            // Due to Verilog scope, let's implement the logic directly in the main FSM block using
                            // a few helper registers: `curr_node`, `curr_dist`, `neighbor_ptr`.
                            
                            // --- BFS Implementation Detail ---
                            // We need to handle the queue operations. 
                            // The RAM read is asynchronous. 
                            // 
                            // Let's add explicit logic here for the BFS expansion:
                            
                            // We need a separate counter for the expansion steps to avoid conflict with state transitions.
                            // Let's call it `bfs_phase`. 
                            // 0: Init (already handled above).
                            // 1: Pop front. (Set address to q[q_head]).
                            // 2: Read dist. Start neighbor 0.
                            // 3: Neighbor 1.
                            // 4: Neighbor 2.
                            // 5: Neighbor 3.
                            // 6: Update Queue Head/Count. If count > 0, go to 1. Else done.
                            
                            // To implement this in one always block without sub-modules, we use `expansion_step` register.
                            // Since we cannot easily define local variables in always block for synthesis without registering them,
                            // we will use the existing registers creatively.
                            // `step_counter` will be our expansion_step (0-6). 
                            // `curr_idx` holds the node currently being expanded (popped from Q).
                            // `neighbor_offset` tracks which neighbor (0-3).
                            
                            // Wait, `step_counter` is also used in CALCULATE. We need to be careful with resetting.
                            // We can use a separate `exp_step` reg.
                            reg [2:0] exp_step;
                            // Let's declare it outside for synthesis safety, but here I'll simulate the logic.
                            // Assuming `exp_step` is a registered variable.
                            
                            // Correction: To keep the code clean and synthesizable within the single-block constraint,
                            // I will add `exp_step` as a register.
                        end else begin
                            // Queue empty, BFS finished for this state
                            bfs_done <= 1;
                        end
                    end
                end
            end else begin
                bfs_done <= 0;
            end
        end
    end

    // --- Helper Logic & Registers for BFS (Separate block for clarity) ---
    reg [2:0] exp_step;
    reg [3:0] popped_node;
    reg [7:0] popped_dist;
    reg [3:0] neighbor_ptr; // 0,1,2,3 -> up,down,left,right
    
    // Neighbor calculation combinational logic
    wire [3:0] n_row = popped_node / 4;
    wire [3:0] n_col = popped_node % 4;
    wire [3:0] n_idx_up = (n_row > 0) ? (popped_node - 4) : 16;
    wire [3:0] n_idx_down = (n_row < 3) ? (popped_node + 4) : 16;
    wire [3:0] n_idx_left = (n_col > 0) ? (popped_node - 1) : 16;
    wire [3:0] n_idx_right = (n_col < 3) ? (popped_node + 1) : 16;
    
    wire [3:0] active_neighbor = (neighbor_ptr == 0) ? n_idx_up :
                                  (neighbor_ptr == 1) ? n_idx_down :
                                  (neighbor_ptr == 2) ? n_idx_left :
                                  n_idx_right;

    // Access grid for active neighbor (comb logic)
    wire [7:0] active_neighbor_char = (active_neighbor < 16) ? grid_flat[active_neighbor] : 8'h00;
    wire neighbor_is_valid = (active_neighbor < 16) && (active_neighbor_char != 8'h23); // Not '#'
    
    // Read distance of active neighbor from correct RAM
    wire [7:0] active_neighbor_dist = (ram_select == 1) ? dist1[active_neighbor] : 
                                       (ram_select == 2) ? dist2[active_neighbor] : 
                                       dist3[active_neighbor];
    
    // Main sequential logic for BFS (Split out to handle complexity)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_step <= 0;
            q_head <= 0;
            q_tail <= 0;
            q_count <= 0;
            ram_wr_en <= 0;
        end else begin
            ram_wr_en <= 0;
            q_push <= 0;
            q_pop <= 0;
            
            // Only run BFS logic if we are in a BFS state
            if (state == BFS1 || state == BFS2 || state == BFS3) begin
                // Handle Init from the previous logic (Start Pulse)
                if (bfs_start_pulse) begin
                    exp_step <= 0;
                    q_count <= 0;
                    q_head <= 0;
                    q_tail <= 0;
                    // We will search for start in the main FSM block (step_counter == 0). 
                    // Once found, we pushed to queue. 
                    // So we check if q_count > 0 to proceed to expansion.
                    // However, the search is sequential in the main block. 
                    // Let's integrate the "Search" phase into `exp_step` to keep it clean.
                    // 0: Search Start Node (Iterate 0-15)
                    // 1: Pop
                    // 2..5: Neighbors
                    // 6: Loop Check
                    
                    exp_step <= 0;
                    curr_idx <= 0;
                end else begin
                    case (exp_step)
                        0: begin // Search for Start Node
                            if (q_count > 0) begin
                                // Start node already found and pushed (handled by start_pulse logic in main block? 
                                // Actually main block sets step_counter=0 for search. Let's sync them.
                                // To avoid conflict, let's assume main block sets step_counter=0 and we handle it here.
                                // Wait, main block already has logic for `step_counter == 0`. 
                                // Let's remove that logic from main block and put it here to avoid double-writing.
                                // But we can't easily edit previous text. 
                                // Strategy: The main block sets up `curr_idx` and `step_counter`. 
                                // We will override the BFS logic in the main block by using `exp_step` effectively.
                                // Actually, let's assume the logic in main block is correct for *finding* the node.
                                // We just need to handle expansion.
                                // The main block sets `step_counter = 1` once found. 
                                // So here, we check `step_counter`. 
                                if (step_counter == 1) begin
                                    exp_step <= 1; // Start expansion phase
                                end
                            end
                        end
                        
                        1: begin // Pop from Queue
                            if (q_count > 0) begin
                                popped_node <= q[q_head];
                                q_head <= q_head + 1;
                                q_count <= q_count - 1;
                                exp_step <= 2; // Go to neighbors
                                neighbor_ptr <= 0;
                            end else begin
                                // Should not happen if we entered here correctly
                                exp_step <= 0; // Retry search or finish
                            end
                        end
                        
                        2, 3, 4, 5: begin // Process Neighbor 0, 1, 2, 3
                            // neighbor_ptr is 0 to 3. exp_step maps to neighbor_ptr + 2.
                            // Wait, exp_step is 2,3,4,5. neighbor_ptr is 0,1,2,3.
                            neighbor_ptr <= exp_step - 2;
                            
                            // Check valid and not visited (dist == 255)
                            if (active_neighbor < 16 && active_neighbor_char != 8'h23 && active_neighbor_dist == 8'hFF) begin
                                // Update distance: popped_dist + 1 (if grid is '.')
                                // Note: Requirement says "number of '.' cells". 
                                // If neighbor is a state ('1','2','3'), is it counted? "Distance... to every reachable cell". 
                                // Usually in MST/Mesh problems, only roads cost. States are terminals.
                                // If we are connecting states, we usually don't count the state cells themselves as cost.
                                // However, connecting '1' to '2' directly: path goes through '.' cells. 
                                // If neighbor is a state, we treat it as free (cost same as current) or check termination.
                                // The problem says "minimum number of '.' cells needed to connect".
                                // So '.' = cost +1, '1','2','3' = cost +0 (but usually we stop if we hit another state? 
                                // "iterates through grid cells to find minimum sum of distances" implies we calculate distances 
                                // from each state to every cell. Then we sum them at meeting points.
                                // So if neighbor is a state, we still want to reach it to know the distance.
                                // So: Update dist = popped_dist + (grid_char == '.' ? 1 : 0).
                                
                                // Wait, `grid_char` is `grid_flat[ram_addr]`. We need `grid_flat[active_neighbor]`.
                                // `active_neighbor_char` is available.
                                
                                reg [7:0] new_dist;
                                new_dist = popped_dist + ((active_neighbor_char == 8'd46) ? 1 : 0);
                                
                                // Update RAM
                                if (state == BFS1) dist1[active_neighbor] <= new_dist;
                                else if (state == BFS2) dist2[active_neighbor] <= new_dist;
                                else dist3[active_neighbor] <= new_dist;
                                
                                // Push to Queue
                                q[q_tail] <= active_neighbor;
                                q_tail <= q_tail + 1;
                                q_count <= q_count + 1;
                            end
                            
                            if (exp_step == 5) exp_step <= 6;
                            else exp_step <= exp_step + 1;
                        end
                        
                        6: begin // Check if queue empty
                            if (q_count > 0) begin
                                exp_step <= 1; // Continue BFS
                            end else begin
                                // BFS Done
                                // We need to signal the main FSM.
                                // In the main FSM, we check `bfs_done`. 
                                // We can set `bfs_done` high here.
                                // But `bfs_done` is in the main block. 
                                // We can drive `bfs_done` from this block if it is a wire, 
                                // but it was defined as reg in main.
                                // Let's add `bfs_done` as an output of this sub-logic.
                                // Or simply, the main FSM checks `q_count` in its `BFSx` state.
                                // Let's make `bfs_done` an internal wire driven here.
                                // Since `bfs_done` was assigned in the main block, we'll replace that logic.
                                // We will rely on `q_count` check in the main block, or introduce a `bfs_finished_signal`.
                                // Actually, to keep it clean: The main block transition logic:
                                // `if (bfs_done) state <= next`. 
                                // I will modify the main block's `bfs_done` logic to be `exp_step == 6 && q_count == 0`.
                                // To do this, I'll expose `exp_step` from this logic to the main block.
                                // Since code blocks are concatenated, `exp_step` is visible.
                                
                                // But `q_count` is modified here. 
                                // So `bfs_done` in main block will be `exp_step == 6 && q_count == 0`.
                                // Let's reset `exp_step` to 0 here to prevent re-triggering? No, state will change.
                            end
                        end
                    endcase
                end
            end else begin
                exp_step <= 0;
            end
        end
    end

    // Combinational logic to drive bfs_done signal for the main FSM
    always @(*) begin
        if ((state == BFS1 || state == BFS2 || state == BFS3) && exp_step == 3'd6 && q_count == 0 && !bfs_start_pulse) begin
            bfs_done = 1;
        end else begin
            bfs_done = 0;
        end
    end

    // Fix for "dist1[curr_idx] <= 0" in main block vs RAM logic:
    // In the main block, I wrote directly to `dist1[curr_idx]`. 
    // In the sub-block, I also write to `dist1[active_neighbor]`.
    // This causes multiple drivers for the RAM array.
    // In Verilog, array multi-driver is not standard for synthesis.
    // We must consolidate RAM writes.
    
    // CORRECTIVE LOGIC: Single Source of Truth for RAM Writes
    // We will use the signals `ram_wr_en`, `ram_addr`, `ram_wr_data` from the main block 
    // and handle ALL writes (initialization and BFS updates) through this mechanism.
    
    // Let's redefine the sequential logic to be cleaner regarding RAM.
    // I will provide the final, corrected code structure below.
    // The previous 'always' blocks inside the response are a bit messy due to the 'no comments' restriction style.
    // I will generate a clean, synthesizable Verilog block now.

    // --- Final Corrected Module Logic ---
    // We need to overwrite the previous logic with a clean version.
    // I will use the `code` block to write the final clean version.

    // Since I need to output the code, I will construct the string carefully.
    // The user asked for "sequential Verilog module".
    // I will provide the code that implements the logic described: 
    // 1. Search for start node (0-15 cycles).
    // 2. BFS Loop: Pop -> Process 4 neighbors -> Repeat.
    // 3. Calculation loop.

    // I will rewrite the module body to be correct and synthesizable.
    // See the "code" key in the JSON for the final implementation.
    // The logic above serves as thought process; the JSON value will be the clean code.

endmodule

// Re-writing the module for the JSON output to ensure correctness and meet requirements.
// I will create a synthesizable module with a single always block for state/control and separate logic for RAM.

module three_states_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_flat [0:15],
    output reg [7:0] min_cost,
    output reg done
);

    // State definition
    localparam S_IDLE = 3'd0;
    localparam S_FIND_START = 3'd1;
    localparam S_BFS_LOOP = 3'd2;
    localparam S_CALC = 3'd3;
    localparam S_DONE = 3'd4;

    reg [2:0] state;
    reg [3:0] idx; // General index for iterating cells
    reg [3:0] start_idx; // Stores position of current state (1, 2, or 3)
    reg [2:0] bfs_state; // 0=Find, 1=Pop, 2=Expand
    reg [2:0] neighbor_cnt; // 0 to 3
    
    // Distance RAMs (0 to 15 cells). 255 = infinity
    reg [7:0] d1 [0:15];
    reg [7:0] d2 [0:15];
    reg [7:0] d3 [0:15];
    
    // Queues for BFS
    reg [3:0] q [0:15];
    reg [3:0] q_head, q_tail, q_cnt;
    reg [3:0] curr_node;
    reg [7:0] curr_dist;
    
    // Helper vars
    reg [7:0] temp_dist;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            min_cost <= 0;
            // Reset RAMs
            for (i = 0; i < 16; i = i + 1) begin
                d1[i] <= 255;
                d2[i] <= 255;
                d3[i] <= 255;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_FIND_START;
                        idx <= 0;
                        bfs_state <= 0; // Ready to find state '1'
                    end
                end

                // --- Find Start Phase ---
                // Iterates through grid to find '1', then '2', then '3'
                S_FIND_START: begin
                    // We need to run BFS for 3 states sequentially.
                    // We can reuse S_FIND_START and S_BFS_LOOP.
                    // Let's use idx to track which state we are on (0=1, 1=2, 2=3)
                    // Let's map: 0->State '1', 1->State '2', 2->State '3'
                    
                    // Scan grid to find the current target state
                    if (grid_flat[idx] == 8'd49 + bfs_state) begin // 49='1', 50='2', etc.
                        start_idx <= idx;
                        // Initialize distance RAM for this state
                        if (bfs_state == 0) d1[idx] <= 0;
                        else if (bfs_state == 1) d2[idx] <= 0;
                        else d3[idx] <= 0;
                        
                        // Initialize Queue
                        q[0] <= idx;
                        q_head <= 0;
                        q_tail <= 1;
                        q_cnt <= 1;
                        
                        // Move to BFS expansion
                        state <= S_BFS_LOOP;
                        curr_node <= idx;
                    end else begin
                        if (idx == 15) begin
                            // End of grid, state not found (impossible connection)
                            // Should ideally handle this, but assuming valid input per problem spec
                            // If strict, jump to DONE with 255. 
                            // For now, let's assume we find it. If not, we might hang.
                            // Let's force advance state if not found to avoid lock.
                            if (bfs_state < 2) begin
                                bfs_state <= bfs_state + 1;
                                idx <= 0;
                            end else begin
                                state <= S_CALC; // Should have found all 3
                            end
                        end else begin
                            idx <= idx + 1;
                        end
                    end
                end

                // --- BFS Loop Phase ---
                S_BFS_LOOP: begin
                    if (q_cnt == 0) begin
                        // Queue empty, BFS finished for this state
                        if (bfs_state < 2) begin
                            bfs_state <= bfs_state + 1;
                            state <= S_FIND_START;
                            idx <= 0;
                        end else begin
                            state <= S_CALC;
                            idx <= 0; // Reset for calculation phase
                        end
                    end else begin
                        // Pop from Queue
                        if (bfs_state != 3'd4) begin // Sub-state 4 is processing neighbors
                            curr_node <= q[q_head];
                            q_head <= q_head + 1;
                            q_cnt <= q_cnt - 1;
                            // Read distance of current node
                            if (bfs_state == 0) curr_dist <= d1[curr_node];
                            else if (bfs_state == 1) curr_dist <= d2[curr_node];
                            else curr_dist <= d3[curr_node];
                            neighbor_cnt <= 0;
                            bfs_state <= 4; // Enter neighbor expansion sub-state
                        end else begin
                            // Process neighbor `neighbor_cnt`
                            if (neighbor_cnt < 4) begin
                                // Determine neighbor index (Up, Down, Left, Right)
                                reg [3:0] n_idx;
                                reg [3:0] r, c;
                                r = curr_node / 4;
                                c = curr_node % 4;
                                
                                case (neighbor_cnt)
                                    0: n_idx = (r > 0) ? (curr_node - 4) : 16;
                                    1: n_idx = (r < 3) ? (curr_node + 4) : 16;
                                    2: n_idx = (c > 0) ? (curr_node - 1) : 16;
                                    3: n_idx = (c < 3) ? (curr_node + 1) : 16;
                                endcase
                                
                                // Check bounds and obstacle
                                if (n_idx < 16 && grid_flat[n_idx] != 8'h23) begin // Not '#'
                                    // Check if this neighbor needs update (dist > new_dist)
                                    // We need to read the neighbor's current distance
                                    reg [7:0] old_dist;
                                    reg [7:0] new_dist;
                                    
                                    if (bfs_state == 4'd0) old_dist = d1[n_idx];
                                    else if (bfs_state == 4'd1) old_dist = d2[n_idx];
                                    else old_dist = d3[n_idx];
                                    
                                    // Cost calculation: '.' adds 1, '1','2','3' add 0 (standard for connection problems)
                                    new_dist = curr_dist + ((grid_flat[n_idx] == 8'd46) ? 1 : 0);
                                    
                                    if (old_dist > new_dist) begin
                                        // Update RAM
                                        if (bfs_state == 0) d1[n_idx] <= new_dist;
                                        else if (bfs_state == 1) d2[n_idx] <= new_dist;
                                        else d3[n_idx] <= new_dist;
                                        
                                        // Push to Queue
                                        q[q_tail] <= n_idx;
                                        q_tail <= q_tail + 1;
                                        q_cnt <= q_cnt + 1;
                                    end
                                end
                                
                                neighbor_cnt <= neighbor_cnt + 1;
                            end else begin
                                // Finished all neighbors, get next node from queue
                                bfs_state <= 0; // Back to Pop phase (actually value 0/1/2 is handled by the check above, but we used a flag)
                                // Correction: bfs_state 4 was used to process. 
                                // To prevent re-popping immediately, we stay in S_BFS_LOOP.
                                // The `if (bfs_state != 4)` check handles it.
                                bfs_state <= 0; // Reset sub-state to pop next iteration
                            end
                        end
                    end
                end

                // --- Calculation Phase ---
                // Iterate 0-15, sum d1[i]+d2[i]+d3[i], find min
                S_CALC: begin
                    if (idx < 16) begin
                        // We need to read d1, d2, d3 for idx.
                        // In combinational logic we can read arrays, but here we are sequential.
                        // We can pipeline the sum. 
                        // Cycle 1: Read d1, wait
                        // Cycle 2: Read d2, add d1
                        // Cycle 3: Read d3, add d2, compare
                        
                        // To do this in one state, we use a sub-counter or just use combinational logic.
                        // Since RAMs are readable, we can do:
                        if (d1[idx] != 255 && d2[idx] != 255 && d3[idx] != 255) begin
                            reg [7:0] sum;
                            sum = d1[idx] + d2[idx] + d3[idx];
                            if (idx == 0) min_cost <= sum;
                            else if (sum < min_cost) min_cost <= sum;
                        end
                        idx <= idx + 1;
                    end else begin
                        // Check if we found a valid connection (min_cost not initialized to 255?)
                        // If min_cost was never updated (e.g. all 255), we should return 255.
                        // The initial min_cost in IDLE is 0. We should initialize it to 255 at start of CALC.
                        // Let's fix that: modify the transition to S_CALC to set min_cost = 255.
                        // Since I can't modify previous lines easily, I'll add logic here.
                        // If idx==0, we are just starting. But we need to compare sequentially.
                        // Actually, better to reset min_cost to 255 in the transition *to* CALC.
                        // Since I missed that, let's do this: 
                        // If we are here and min_cost is 0 (from reset), but we haven't updated it yet (idx < 16), it's tricky.
                        // Let's just check if we are done.
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done <= 1;
                    if (!start) state <= S_IDLE;
                end
            endcase
        end
    end

    // --- Combinational fix for S_CALC ---
    // The S_CALC logic above needs a way to initialize min_cost to 255.
    // We can detect entry into S_CALC.
    reg calc_started;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) calc_started <= 0;
        else begin
            if (state == S_CALC && $past(state) != S_CALC) begin
                min_cost <= 255;
                calc_started <= 1;
            end
        end
    end
    // The sequential block above already handles the comparison, but min_cost needs to be initialized.
    // Since `min_cost <= 255` needs to happen exactly on the cycle `state` becomes S_CALC.
    // We can add a condition in the S_CALC block.
    // Rewriting S_CALC block logic inside the always block (conceptual) to be correct:
    /*
    S_CALC: begin
        if (idx == 0 && !calc_done_flag) begin
            min_cost <= 255;
            calc_done_flag <= 1; // internal flag
        end
        ... // comparison logic
    end
    */
    // Given the complexity of sequential-only and the single-block restriction, 
    // the code provided in the `code` key below is a consolidated, cleaner version 
    // that handles these edge cases properly.

endmodule

// Note to User: The code above is the thought process. 
// The actual synthesizable code is in the JSON block below.
// I will include the fix for initialization in the final code block.

// Final clean version for JSON:
module three_states_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_flat [0:15],
    output reg [7:0] min_cost,
    output reg done
);

    localparam IDLE = 0, FIND_START = 1, BFS = 2, CALC = 3, DONE_ST = 4;
    reg [2:0] state;
    
    // RAMs
    reg [7:0] d1 [0:15];
    reg [7:0] d2 [0:15];
    reg [7:0] d3 [0:15];
    
    // Queue
    reg [3:0] q [0:15];
    reg [3:0] head, tail, count;
    
    // Counters
    reg [3:0] i; // grid index
    reg [1:0] state_idx; // 0,1,2 for 1,2,3
    reg [2:0] sub_step; // 0=pop, 1-4=neighbors
    reg [3:0] node; // current node in BFS
    reg [7:0] node_dist; // current dist
    reg found_start; // flag to ensure we found the char
    
    // Neighbors
    wire [3:0] n_up = (node/4 > 0) ? node-4 : 16;
    wire [3:0] n_down = (node/4 < 3) ? node+4 : 16;
    wire [3:0] n_left = (node%4 > 0) ? node-1 : 16;
    wire [3:0] n_right = (node%4 < 3) ? node+1 : 16;
    wire [3:0] neighbor = (sub_step==1) ? n_up : (sub_step==2) ? n_down : (sub_step==3) ? n_left : n_right;
    wire [7:0] neigh_char = grid_flat[neighbor];
    
    integer k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_cost <= 0;
            // Reset RAMs
            for (k=0; k<16; k=k+1) begin d1[k]<=255; d2[k]<=255; d3[k]<=255; end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= FIND_START;
                        i <= 0;
                        state_idx <= 0;
                        found_start <= 0;
                    end
                end
                
                FIND_START: begin
                    // Search for current state (0->'1', 1->'2', 2->'3')
                    if (!found_start) begin
                        if (i < 16) begin
                            if (grid_flat[i] == 8'd49 + state_idx) begin
                                // Found it
                                // Init RAM
                                if (state_idx == 0) d1[i] <= 0;
                                else if (state_idx == 1) d2[i] <= 0;
                                else d3[i] <= 0;
                                // Init Queue
                                q[0] <= i;
                                head <= 0;
                                tail <= 1;
                                count <= 1;
                                node <= i;
                                found_start <= 1;
                                sub_step <= 0;
                                state <= BFS;
                            end else begin
                                i <= i + 1;
                            end
                        end else begin
                            // State not found, invalid input. Jump to DONE with 255? 
                            // Or assume valid. If not found, connection impossible.
                            // For robustness, if not found, we consider this state done (or fail).
                            // Let's assume valid input. If not found, we might loop. 
                            // Let's skip to next state if not found in grid.
                            if (state_idx < 2) begin
                                state_idx <= state_idx + 1;
                                i <= 0;
                            end else begin
                                state <= DONE_ST; // Impossible
                                min_cost <= 255;
                            end
                        end
                    end
                end
                
                BFS: begin
                    if (count == 0) begin
                        // Queue empty, this BFS done
                        if (state_idx < 2) begin
                            state_idx <= state_idx + 1;
                            i <= 0;
                            found_start <= 0;
                            state <= FIND_START;
                        end else begin
                            state <= CALC;
                            i <= 0;
                            min_cost <= 255;
                        end
                    end else begin
                        if (sub_step == 0) begin // Pop
                            node <= q[head];
                            // Read dist of popped node based on current state_idx
                            if (state_idx == 0) node_dist <= d1[q[head]];
                            else if (state_idx == 1) node_dist <= d2[q[head]];
                            else node_dist <= d3[q[head]];
                            head <= head + 1;
                            count <= count - 1;
                            sub_step <= 1;
                        end else if (sub_step <= 4) begin // Neighbors 1-4
                            if (neighbor < 16 && neigh_char != 8'h23) begin
                                // Check distance
                                reg [7:0] old_d;
                                reg [7:0] new_d;
                                if (state_idx == 0) old_d = d1[neighbor];
                                else if (state_idx == 1) old_d = d2[neighbor];
                                else old_d = d3[neighbor];
                                
                                new_d = node_dist + ((neigh_char == 8'd46) ? 1 : 0);
                                
                                if (old_d > new_d) begin
                                    // Update RAM
                                    if (state_idx == 0) d1[neighbor] <= new_d;
                                    else if (state_idx == 1) d2[neighbor] <= new_d;
                                    else d3[neighbor] <= new_d;
                                    // Push
                                    q[tail] <= neighbor;
                                    tail <= tail + 1;
                                    count <= count + 1;
                                end
                            end
                            sub_step <= sub_step + 1;
                        end else begin // Done with neighbors
                            sub_step <= 0;
                        end
                    end
                end
                
                CALC: begin
                    if (i < 16) begin
                        if (d1[i] != 255 && d2[i] != 255 && d3[i] != 255) begin
                            reg [7:0] sum; // Temporary sum for this cycle
                            sum = d1[i] + d2[i] + d3[i];
                            if (sum < min_cost) min_cost <= sum;
                        end
                        i <= i + 1;
                    end else begin
                        state <= DONE_ST;
                    end
                end
                
                DONE_ST: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule
