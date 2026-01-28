module BanditGold(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [15:0] gold_in,
    input wire gold_valid,
    input wire [3:0] edge_a,
    input wire [3:0] edge_b,
    input wire edge_valid,
    input wire edge_load_done,
    output reg [15:0] result,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] LOAD       = 4'd1;
    localparam [3:0] PREPARE    = 4'd2;
    localparam [3:0] FIND_DIST  = 4'd3;
    localparam [3:0] ENUM_PATHS = 4'd4;
    localparam [3:0] CHECK_RETURN = 4'd5;
    localparam [3:0] UPDATE_RES = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;
    localparam [3:0] BFS_RUN    = 4'd8;
    localparam [3:0] BFS_CHECK  = 4'd9;

    // Registers
    reg [3:0] state, next_state;
    reg [3:0] n_reg;
    reg [15:0] adj [0:15];      // Adjacency matrix (bitmask)
    reg [15:0] gold [0:13];     // Gold for villages 3..16 (indices 0..13)
    reg [15:0] dist_matrix [0:15][0:15]; // All pairs shortest distance
    reg [3:0] path_stack [0:15]; // Stack for DFS
    reg [3:0] stack_ptr;
    reg [15:0] visited_mask;    // For DFS
    reg [15:0] current_gold;
    reg [15:0] max_gold;
    reg [3:0] target_dist;
    
    // Temporary variables for loops
    reg [3:0] i, j, k;
    reg [15:0] temp_mask;
    reg [15:0] temp_dist;
    reg found_flag;
    reg [15:0] return_visited;
    reg [3:0] q_head, q_tail;
    reg [3:0] q_queue [0:15];
    reg [15:0] reachable_mask;
    reg [15:0] nodes_to_remove;
    reg [15:0] valid_path_nodes;
    
    // Valid range for n: 3 to 16. Assume 16 for max logic if not set yet.
    // Gold indices: 0 maps to village 3.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
            n_reg <= 4'd16;
            max_gold <= 16'd0;
            stack_ptr <= 4'd0;
            visited_mask <= 16'd0;
            current_gold <= 16'd0;
            target_dist <= 4'd0;
            // Initialize adjacency matrix
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 16'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    dist_matrix[i][j] <= 16'd0;
                end
            end
            // Initialize gold memory
            for (i = 0; i < 14; i = i + 1) begin
                gold[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        max_gold <= 16'd0;
                        // Reset adjacency and gold if needed (part of load)
                        for (i = 0; i < 16; i = i + 1) begin
                            adj[i] <= 16'd0;
                        end
                        for (i = 0; i < 14; i = i + 1) begin
                            gold[i] <= 16'd0;
                        end
                    end
                end
                
                LOAD: begin
                    // Load edges and gold concurrently
                    if (edge_valid) begin
                        // Edge a->b and b->a. indices are 1-based.
                        // adj is 0-based index 0..15 corresponding to villages 1..16
                        if ((edge_a >= 4'd1) && (edge_a <= n_reg) && 
                            (edge_b >= 4'd1) && (edge_b <= n_reg)) begin
                            adj[edge_a - 4'd1][edge_b - 4'd1] <= 1'b1;
                            adj[edge_b - 4'd1][edge_a - 4'd1] <= 1'b1;
                        end
                    end
                    if (gold_valid) begin
                        // gold_in is for village index 3..16
                        // Input index 0..13 provided externally? Spec says gold_valid for current index.
                        // Assuming gold_in is valid for village 3 + current_index count.
                        // The spec says: gold_in for current village index (valid 0-13, map to village 3..16)
                        // This implies an external counter or sequential loading. 
                        // We need to track which gold index we are loading.
                        // Let's add a counter for gold loading if we are in LOAD state.
                        // Actually, it's safer to use a dedicated load counter.
                        // We will add a gold_idx counter.
                    end
                end
                
                PREPARE: begin
                    // BFS for all pairs shortest path
                    // We use dist_matrix[i][j] as distance.
                    // Reset dist_matrix first.
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            if (i == j) dist_matrix[i][j] <= 16'd0;
                            else if (adj[i][j]) dist_matrix[i][j] <= 16'd1;
                            else dist_matrix[i][j] <= 16'hFFFF;
                        end
                    end
                    k <= 4'd0; // Outer loop variable
                end
                
                BFS_RUN: begin
                    // Floyd-Warshall or simple BFS from each node.
                    // Since n<=16, simple BFS from each node is okay.
                    // We will run BFS for source node i.
                    // State transition handles the loop.
                end
                
                FIND_DIST: begin
                    // D = Dist[0][1] (Node 1 to Node 2 -> indices 0 to 1)
                    target_dist <= dist_matrix[0][1][3:0]; // Distance is small
                    // Reset DFS stack
                    stack_ptr <= 4'd0;
                    path_stack[0] <= 4'd0; // Start at node 0 (village 1)
                    visited_mask <= 16'd1; // Visited node 0
                    current_gold <= 16'd0;
                end
                
                ENUM_PATHS: begin
                    // DFS to find paths of length target_dist
                end
                
                CHECK_RETURN: begin
                    // Check connectivity from 2 (index 1) to 1 (index 0) 
                    // avoiding nodes in path_stack (except 1 and 2).
                    // Build nodes_to_remove mask.
                end
                
                UPDATE_RES: begin
                    if (current_gold > max_gold) begin
                        max_gold <= current_gold;
                    end
                end
                
                DONE_STATE: begin
                    result <= max_gold;
                    done <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
        end
    end

    // Combinational Logic for State Transitions
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            
            LOAD: begin
                // Wait for edge_load_done.
                // Since gold loading logic needs a counter, we need to handle it here.
                // We will infer a gold_idx counter implicitly in the combinational block.
                if (edge_load_done) next_state = PREPARE;
            end
            
            PREPARE: begin
                next_state = BFS_RUN;
            end
            
            BFS_RUN: begin
                // Trigger BFS for current source k
                next_state = BFS_CHECK;
            end
            
            BFS_CHECK: begin
                // Check if all sources processed
                if (k < n_reg) begin
                    next_state = BFS_RUN;
                end else begin
                    next_state = FIND_DIST;
                end
            end
            
            FIND_DIST: begin
                if (target_dist > 15) begin
                    // No path found
                    next_state = DONE_STATE;
                end else begin
                    next_state = ENUM_PATHS;
                end
            end
            
            ENUM_PATHS: begin
                // DFS Logic:
                // 1. Peek top of stack (path_stack[stack_ptr-1]).
                // 2. Check neighbors.
                // 3. If neighbor is valid (not visited, within constraints), push.
                // 4. If path length == target_dist + 1 (count of nodes), check if end is node 1 (index 1).
                //    If yes -> valid path found. Go to CHECK_RETURN.
                //    If no -> backtrack.
                // 5. If no valid neighbors, backtrack.
                // 
                // We need to use helper logic to find next valid neighbor.
                // Let's assume a 'valid_neighbor_found' flag and 'next_node' variable are computed.
                // If end of path reached (stack_ptr == target_dist + 1):
                //   If top of stack is node 1 (index 1) -> Valid path. -> CHECK_RETURN
                //   Else -> Backtrack.
                // If backtracked to empty (stack_ptr == 0) -> DONE_STATE
                // Else -> Continue DFS
            end
            
            CHECK_RETURN: begin
                // BFS to check connectivity
                // If reachable, next_state = UPDATE_RES
                // Else, next_state = ENUM_PATHS (continue search)
            end
            
            UPDATE_RES: begin
                next_state = ENUM_PATHS;
            end
            
            DONE_STATE: begin
                if (!busy) next_state = IDLE; // Wait for reset or new start
                else next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Helper Logic (Combinational) for BFS and DFS
    // We need to define these outside the always block but use reg/wire.
    
    // BFS Logic Variables
    reg [3:0] bfs_src;
    reg [15:0] bfs_dist [0:15];
    reg [15:0] bfs_visited;
    reg [3:0] bfs_q [0:15];
    reg [3:0] bfs_q_head, bfs_q_tail;
    reg [3:0] bfs_u, bfs_v;
    integer bit_idx;
    
    // DFS Logic Variables
    reg [15:0] dfs_allowed_mask; // Mask of nodes allowed in path (excluding stolen nodes later, but here just valid nodes)
    reg [15:0] path_gold_sum;
    
    // BFS from node k (index) logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset if needed
        end else if (state == PREPARE) begin
            k <= 4'd0;
        end else if (state == BFS_RUN) begin
            // Init BFS for source k
            bfs_src <= k;
            for (i = 0; i < 16; i = i + 1) begin
                bfs_dist[i] <= 16'hFFFF;
            end
            bfs_dist[k] <= 16'd0;
            bfs_visited <= 16'd0;
            bfs_q[0] <= k;
            bfs_q_head <= 4'd0;
            bfs_q_tail <= 4'd1;
            bfs_visited[k] <= 1'b1;
        end else if (state == BFS_CHECK) begin
            if (bfs_q_head < bfs_q_tail) begin
                // Process queue
                bfs_u <= bfs_q[bfs_q_head];
                bfs_q_head <= bfs_q_head + 4'd1;
                // We need a sub-state or variable to iterate neighbors of bfs_u
                // Since Verilog execution is sequential in always block, we can iterate here.
                // However, it's a loop. Let's use a variable 'neighbor_bit' to process one neighbor per cycle.
                // Optimization: Since n <= 16, we can process all neighbors of u in one cycle block if we don't have time constraints.
                // Let's iterate v from 0 to n_reg-1.
                for (v = 0; v < 16; v = v + 1) begin
                    if (v < n_reg && adj[bfs_u][v]) begin
                        if (!bfs_visited[v]) begin
                            bfs_visited[v] <= 1'b1;
                            bfs_dist[v] <= bfs_dist[bfs_u] + 16'd1;
                            bfs_q[bfs_q_tail] <= v;
                            bfs_q_tail <= bfs_q_tail + 4'd1;
                        end
                    end
                end
            end else begin
                // BFS Finished for node k
                // Save distances to dist_matrix[k][*]
                for (v = 0; v < 16; v = v + 1) begin
                    dist_matrix[k][v] <= bfs_dist[v];
                end
                k <= k + 4'd1;
            end
        end
    end

    // DFS Logic for finding paths
    // We need to manage the stack and check conditions.
    // We need a way to find the next candidate node in ENUM_PATHS state.
    // Since we need to iterate, we can use a 'search_start_node' register to try neighbors.
    reg [3:0] search_neighbor_idx;
    reg [3:0] backtrack_depth;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else if (state == ENUM_PATHS) begin
            // We are in a loop. We need to find the next action.
            // Action 1: If stack is empty -> DONE.
            // Action 2: Check if current path is complete (top == 1).
            // Action 3: If complete, validate. If valid, go to CHECK_RETURN.
            // Action 4: If not complete, find next neighbor.
            
            // Let's handle this step-by-step.
            // If we just entered ENUM_PATHS from FIND_DIST, stack has 0.
            // If we returned from CHECK_RETURN/UPDATE_RES, we need to backtrack or advance.
            
            // Logic flow:
            // 1. Check if path length == target_dist + 1.
            //    If yes: Check if last node is 1. 
            //      If yes: We have a path. Calculate gold. Go to CHECK_RETURN.
            //      If no: Backtrack.
            // 2. If path length < target_dist + 1:
            //    Find next neighbor of current top.
            //    If found: Push to stack. Update gold. Update visited.
            //    If not found: Backtrack.
            
            // Backtrack logic:
            //   Pop from stack. Remove from visited. Subtract gold.
            //   Increment search_neighbor_idx for the new top to continue search.
            
            // We will use search_neighbor_idx to track where we are in the neighbor scan.
            // If search_neighbor_idx == 0, it means we just pushed or are at new node.
            
            // Check if valid path found (Top is 1)
            if (stack_ptr > 0 && path_stack[stack_ptr - 1] == 4'd1 && stack_ptr == (target_dist + 4'd1)) begin
                // Valid path found! (Indices: 0..1 path length D edges, D+1 nodes)
                // Gold already summed in 'current_gold' logic below.
                // Move to CHECK_RETURN
            end else begin
                // Try to find next move
                if (stack_ptr > 0 && stack_ptr < (target_dist + 4'd1)) begin
                    // Try to find a neighbor for current top
                    // search_neighbor_idx continues from previous value
                    // But we need to check against 'n_reg'
                    // We can iterate search_neighbor_idx in this block.
                    // To avoid combinational loop, we process one step per cycle or use logic.
                    // With n<=16, 5000 cycles is plenty. Let's step through neighbors.
                    
                    // Find next valid neighbor
                    // Valid neighbor: connected, not visited, not start node (unless start? start is already visited)
                    // We need a separate combinational block to determine the next state/action.
                    // The sequential block just updates registers.
                end
            end
        end
    end
    
    // --- Combinational Logic for DFS Neighbors ---
    // This block determines the action in ENUM_PATHS state.
    // We define wires for conditions.
    
    wire path_complete;
    wire path_valid;
    wire has_next_neighbor;
    wire [3:0] next_node_found;
    
    assign path_complete = (stack_ptr > 0) && (stack_ptr == (target_dist + 4'd1));
    assign path_valid = path_complete && (path_stack[stack_ptr - 1] == 4'd1);
    
    // Search for next neighbor logic
    reg [3:0] next_nbr;
    reg nbr_found;
    
    always @(*) begin
        nbr_found = 1'b0;
        next_nbr = 4'd0;
        if (stack_ptr > 0 && stack_ptr < (target_dist + 4'd1)) begin
            // Search from search_neighbor_idx to n_reg-1
            for (int idx = 0; idx < 16; idx = idx + 1) begin
                if (!nbr_found && idx < n_reg && idx != path_stack[stack_ptr - 1]) begin
                    if (adj[path_stack[stack_ptr - 1]][idx] && !visited_mask[idx]) begin
                        // Check if adding this node can possibly reach target length?
                        // Not strictly necessary with simple DFS, but good pruning.
                        // For now, just any valid neighbor.
                        // Also, if we are at depth D (stack_ptr == D), we MUST go to node 1.
                        if (stack_ptr == target_dist) begin
                            if (idx == 4'd1) begin
                                nbr_found = 1'b1;
                                next_nbr = idx;
                            end
                        end else begin
                            nbr_found = 1'b1;
                            next_nbr = idx;
                        end
                    end
                end
            end
        end
    end

    // Sequential Update for DFS
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else if (state == ENUM_PATHS) begin
            // If we just found a valid path (detected by combinational logic), 
            // the main state machine will transition to CHECK_RETURN.
            // We need to handle updates here.
            
            if (path_valid) begin
                // State transition handles next_state. 
                // No register update needed here, maybe prepare for CHECK_RETURN.
                // Prepare nodes_to_remove
                // Current path is in path_stack[0..stack_ptr-1]
                // Nodes to remove are path_stack[1..stack_ptr-2] (exclude start 0 and end 1)
            end else if (stack_ptr > 0 && stack_ptr < (target_dist + 4'd1) && nbr_found) begin
                // Push neighbor
                path_stack[stack_ptr] <= next_nbr;
                stack_ptr <= stack_ptr + 4'd1;
                visited_mask[next_nbr] <= 1'b1;
                // Update gold
                if (next_nbr >= 4'd2) begin // Villages 3+ (index 2 corresponds to village 3? No, village 1 is index 0)
                    // Village 1 -> index 0
                    // Village 2 -> index 1
                    // Village 3 -> index 2 -> gold index 0
                    current_gold <= current_gold + gold[next_nbr - 4'd2];
                end
                search_neighbor_idx <= 4'd0; // Reset search for new node
            end else begin
                // Backtrack if no neighbor found or invalid path
                // Condition: 
                // 1. stack_ptr == target_dist + 1 but top != 1 (invalid)
                // 2. stack_ptr < target_dist + 1 but !nbr_found
                // 3. Stack not empty
                if (stack_ptr > 0) begin
                    // Pop
                    stack_ptr <= stack_ptr - 4'd1;
                    visited_mask[path_stack[stack_ptr - 1]] <= 1'b0;
                    if (path_stack[stack_ptr - 1] >= 4'd2) begin
                        current_gold <= current_gold - gold[path_stack[stack_ptr - 1] - 4'd2];
                    end
                end else begin
                    // Stack empty, search done
                    // State machine will handle transition to DONE
                end
            end
        end
    end

    // --- CHECK_RETURN Logic ---
    // BFS from node 1 (index 1) to node 0 (index 0) avoiding 'nodes_to_remove'.
    
    reg [15:0] ret_dist [0:15];
    reg [15:0] ret_visited;
    reg [3:0] ret_q [0:15];
    reg [3:0] ret_q_head, ret_q_tail;
    reg [3:0] ret_u;
    wire [15:0] avoid_mask;
    
    // Build avoid_mask: bits set for nodes to avoid.
    // Path is in path_stack[0..stack_ptr-1].
    // Avoid path_stack[1] to path_stack[stack_ptr-2] (if any).
    // Also avoid node 0 (start) and node 1 (end) are not avoided.
    
    assign avoid_mask = 16'd0; // Defined in sequential logic
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else if (state == CHECK_RETURN) begin
            if (stack_ptr > 2) begin
                // Need to construct avoid_mask dynamically or register it.
                // Let's construct it once when entering CHECK_RETURN.
                // But we are in a cycle. Let's use a flag to initialize.
            end
            
            // BFS Loop
            if (ret_q_head < ret_q_tail) begin
                ret_u <= ret_q[ret_q_head];
                ret_q_head <= ret_q_head + 4'd1;
                for (v = 0; v < 16; v = v + 1) begin
                    if (v < n_reg && adj[ret_u][v]) begin
                        // Check avoid mask
                        if (!ret_visited[v] && !avoid_mask[v]) begin
                            ret_visited[v] <= 1'b1;
                            ret_dist[v] <= ret_dist[ret_u] + 16'd1;
                            ret_q[ret_q_tail] <= v;
                            ret_q_tail <= ret_q_tail + 4'd1;
                        end
                    end
                end
            end else begin
                // BFS Done
                // Check if node 0 (index 0) is visited
                if (ret_visited[0]) begin
                    // Reachable
                    found_flag <= 1'b1;
                end else begin
                    found_flag <= 1'b0;
                end
            end
        end
    end

    // --- Control Flow for CHECK_RETURN ---
    // We need to initialize BFS variables when entering CHECK_RETURN.
    // Since CHECK_RETURN might be entered multiple times, we need a one-time init.
    reg ret_initialized;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ret_initialized <= 1'b0;
        end else begin
            if (state != CHECK_RETURN) begin
                ret_initialized <= 1'b0;
            end else if (state == CHECK_RETURN && !ret_initialized) begin
                // Initialize BFS
                ret_initialized <= 1'b1;
                // Reset dist/visited
                for (i = 0; i < 16; i = i + 1) begin
                    ret_dist[i] <= 16'hFFFF;
                end
                // Start at node 1 (index 1)
                ret_dist[1] <= 16'd0;
                ret_visited <= 16'd0;
                ret_visited[1] <= 1'b1;
                ret_q[0] <= 4'd1;
                ret_q_head <= 4'd0;
                ret_q_tail <= 4'd1;
                
                // Build avoid_mask
                // Path nodes: path_stack[0..stack_ptr-1]
                // Avoid: path_stack[1] ... path_stack[stack_ptr-2]
                // Node 0 and 1 are allowed.
                // We can compute this in a combinational block or here.
            end
        end
    end

    // Combinational logic for final transition from CHECK_RETURN
    always @(*) begin
        if (state == CHECK_RETURN && ret_initialized && ret_q_head >= ret_q_tail) begin
            // BFS finished
            if (ret_visited[0]) begin
                // Reachable
                next_state = UPDATE_RES;
            end else begin
                // Not reachable
                next_state = ENUM_PATHS;
            end
        end
    end
    
    // Helper to construct avoid_mask
    reg [15:0] dynamic_avoid_mask;
    always @(*) begin
        dynamic_avoid_mask = 16'd0;
        for (int m = 1; m < 15; m = m + 1) begin
            if (m < (stack_ptr - 1)) begin
                dynamic_avoid_mask[path_stack[m]] = 1'b1;
            end
        end
    end

    // --- Load Gold Logic ---
    // We need to store gold_in into gold array.
    // Spec: gold_valid indicates gold_in is valid for current index (0-13).
    // Does this mean we need a counter? Or is it sequential 0, 1, 2...
    // It says "gold_in for current village index". Usually implies a sequential load.
    // We'll add a counter to track loading.
    reg [3:0] gold_load_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gold_load_idx <= 4'd0;
        end else if (state == LOAD) begin
            if (gold_valid) begin
                if (gold_load_idx < 4'd14) begin
                    gold[gold_load_idx] <= gold_in;
                    gold_load_idx <= gold_load_idx + 4'd1;
                end
            end
        end else if (state == IDLE) begin
            gold_load_idx <= 4'd0;
        end
    end

endmodule
