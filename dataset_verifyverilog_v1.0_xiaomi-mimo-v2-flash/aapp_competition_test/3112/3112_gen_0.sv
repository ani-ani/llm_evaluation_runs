module MaxProducersModule(
    input clk,
    input rst_n,
    input start,
    input config_valid,
    input [127:0] edge_src,  // 32 edges * 4 bits
    input [127:0] edge_dst,  // 32 edges * 4 bits
    input [4:0] num_edges,
    input [3:0] num_producers,
    output reg [3:0] result,
    output reg done
);

    // --- Parameters ---
    localparam [4:0] MAX_NODES = 5'd16;
    localparam [4:0] MAX_PRODUCERS = 5'd8;
    localparam [4:0] MAX_EDGES = 5'd32;
    localparam [4:0] INF_DIST = 5'd31;
    localparam [3:0] MAX_MASK = 4'd15; // 2^4 - 1 for K=8, but we use 4-bit for count

    // --- State Machine States ---
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONFIG_LOAD = 3'd1;
    localparam [2:0] DIST_COMPUTE = 3'd2;
    localparam [2:0] CHECK_MASK = 3'd3;
    localparam [2:0] CHECK_PAIRS = 3'd4;
    localparam [2:0] CHECK_CONFLICT = 3'd5;
    localparam [2:0] UPDATE_RESULT = 3'd6;
    localparam [2:0] FINISHED = 3'd7;

    // --- Internal Registers & Wires ---
    reg [2:0] state, next_state;
    
    // Graph storage
    reg [3:0] src_reg [0:31];  // Unpacked array for source nodes
    reg [3:0] dst_reg [0:31];  // Unpacked array for destination nodes
    reg [4:0] num_edges_reg;
    reg [3:0] num_producers_reg;
    
    // Distance matrix: dist[producer][node]
    // Max 8 producers, 16 nodes. Packed as 8x16x5 bits = 640 bits
    reg [4:0] dist_matrix [0:7] [0:15];
    
    // Iteration counters
    reg [4:0] edge_idx;       // Current edge index (0 to 31)
    reg [2:0] prod_idx;       // Current producer index (0 to 7)
    reg [7:0] mask;           // Current subset mask (up to 2^8 = 256)
    reg [3:0] popcount;       // Number of set bits in mask
    reg [2:0] p1_idx;         // Index of first producer in pair
    reg [2:0] p2_idx;         // Index of second producer in pair
    reg [3:0] edge_check_idx; // Index for edge checking in pair conflict
    
    // BFS specific registers
    reg [3:0] node_queue [0:15]; // Simple queue for BFS
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] curr_node;
    reg [4:0] dist_temp;
    
    // Conflict detection
    reg conflict_found;
    reg [3:0] u_node; // Current source node of edge being checked
    
    // Counters for loops
    integer i, j;
    
    // Control signals
    reg processing_done;

    // --- Helper: Parity Check ---
    function automatic [0:0] parity;
        input [4:0] val;
        begin
            parity = ^val[3:0]; // XOR bits 0-3 (ignore MSB if INF)
        end
    endfunction

    // --- Helper: Bit Count (Popcount) ---
    function automatic [3:0] count_bits;
        input [7:0] val;
        reg [3:0] cnt;
        reg [3:0] k;
        begin
            cnt = 4'd0;
            for (k = 0; k < 8; k = k + 1) begin
                if (val[k]) cnt = cnt + 4'd1;
            end
            count_bits = cnt;
        end
    endfunction

    // --- Sequential Logic: State Transition ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            num_edges_reg <= 5'd0;
            num_producers_reg <= 4'd0;
            edge_idx <= 5'd0;
            prod_idx <= 3'd0;
            mask <= 8'd0;
            p1_idx <= 3'd0;
            p2_idx <= 3'd0;
            edge_check_idx <= 4'd0;
            conflict_found <= 1'b0;
            popcount <= 4'd0;
            // Initialize distance matrix to INF
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    dist_matrix[i][j] <= INF_DIST;
                end
            end
            // Initialize edge regs
            for (i = 0; i < 32; i = i + 1) begin
                src_reg[i] <= 4'd0;
                dst_reg[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && config_valid) begin
                        num_edges_reg <= num_edges;
                        num_producers_reg <= num_producers;
                    end
                end
                
                CONFIG_LOAD: begin
                    // Load edge data from packed arrays
                    if (edge_idx < num_edges_reg) begin
                        src_reg[edge_idx] <= edge_src[(edge_idx * 4) +: 4];
                        dst_reg[edge_idx] <= edge_dst[(edge_idx * 4) +: 4];
                        edge_idx <= edge_idx + 5'd1;
                    end
                end
                
                DIST_COMPUTE: begin
                    // BFS logic initialization and execution
                    // We iterate prod_idx (0 to K-1)
                    // Handled in next_state logic primarily, data update here
                    // dist_matrix is updated during BFS traversal
                end
                
                CHECK_MASK: begin
                    // Reset pair indices for new mask
                    p1_idx <= 3'd0;
                    p2_idx <= 3'd1;
                    conflict_found <= 1'b0;
                end
                
                CHECK_PAIRS: begin
                    // Increment indices logic handled in next_state
                    // or check current pair
                end
                
                CHECK_CONFLICT: begin
                    // Check edges for current pair (p1_idx, p2_idx)
                    // edge_check_idx iterates through edges
                    if (edge_check_idx < num_edges_reg) begin
                        // Check conflict logic here
                        // If conflict, set conflict_found
                        // Handled in combinational logic or sequential block
                        // We use sequential block for update
                        u_node <= src_reg[edge_check_idx];
                        if ((dist_matrix[p1_idx][u_node] != INF_DIST) && 
                            (dist_matrix[p2_idx][u_node] != INF_DIST)) begin
                            // Both reach this node
                            if (parity(dist_matrix[p1_idx][u_node]) == parity(dist_matrix[p2_idx][u_node])) begin
                                conflict_found <= 1'b1;
                            end
                        end
                        edge_check_idx <= edge_check_idx + 4'd1;
                    end
                end
                
                UPDATE_RESULT: begin
                    if (!conflict_found && popcount > result) begin
                        result <= popcount;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // --- Combinational Next State Logic ---
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && config_valid) next_state = CONFIG_LOAD;
                else next_state = IDLE;
            end
            
            CONFIG_LOAD: begin
                if (edge_idx >= num_edges_reg) next_state = DIST_COMPUTE;
                else next_state = CONFIG_LOAD;
            end
            
            DIST_COMPUTE: begin
                // BFS state machine logic is embedded in combinational logic below
                // This state stays active until all producers distances are computed
                // Handled via 'processing_done' flag in combinational logic block
                if (processing_done) next_state = CHECK_MASK;
                else next_state = DIST_COMPUTE;
            end
            
            CHECK_MASK: begin
                // Check if mask is valid (non-zero) and within range
                // Max mask is (1 << K) - 1
                if (mask == 0) begin // Initial state or finished previous mask
                    next_state = CHECK_MASK;
                    // Handled by sequential logic increment
                end else if (mask >= ((1 << num_producers_reg))) begin
                    next_state = FINISHED;
                end else begin
                    // Calculate popcount for this mask
                    // We will do this sequentially or combo
                    next_state = CHECK_PAIRS;
                end
            end
            
            CHECK_PAIRS: begin
                // Check if we have more pairs to check
                if (p1_idx >= num_producers_reg - 1) begin
                    // Finished all pairs for this mask
                    next_state = UPDATE_RESULT;
                end else if (p2_idx >= num_producers_reg) begin
                    // Move to next p1
                    next_state = CHECK_PAIRS; // Sequential logic will handle increment
                end else begin
                    // Check if both producers are active in current mask
                    if (mask[p1_idx] && mask[p2_idx]) begin
                        next_state = CHECK_CONFLICT;
                    end else begin
                        // Skip if not active
                        next_state = CHECK_PAIRS; // Sequential logic increments
                    end
                end
            end
            
            CHECK_CONFLICT: begin
                if (edge_check_idx >= num_edges_reg || conflict_found) begin
                    next_state = CHECK_PAIRS;
                end else begin
                    next_state = CHECK_CONFLICT;
                end
            end
            
            UPDATE_RESULT: begin
                next_state = CHECK_MASK;
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // --- Combinational Logic for BFS and Loop Control ---
    reg [3:0] bfs_state; // 0: idle, 1: pop, 2: neighbors, 3: update dist
    reg [3:0] neighbor_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing_done <= 1'b0;
            bfs_state <= 4'd0;
            neighbor_idx <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
        end else begin
            if (state == DIST_COMPUTE) begin
                case (bfs_state)
                    4'd0: begin // Initialize BFS for current producer
                        if (prod_idx < num_producers_reg) begin
                            // Clear distances for this producer (or just reset queue)
                            // Reset dist for all nodes to INF for this producer only?
                            // Optimization: Reset only needed nodes or rely on INF init.
                            // We re-init row for simplicity in sequential block
                            for (j = 0; j < 16; j = j + 1) begin
                                dist_matrix[prod_idx][j] <= INF_DIST;
                            end
                            // Start node is producer index + 1 (1 to K)
                            dist_matrix[prod_idx][prod_idx] <= 5'd0;
                            node_queue[0] <= prod_idx[3:0]; // Nodes are 0-indexed internally? Spec says 1 to N.
                            // Wait, spec says junctions 1 to N. Inputs are 0-15.
                            // Producers are at junctions 1 to K. Node 0 is unused or source?
                            // Assuming input IDs are 0-based (0-15). Producer p is at node p-1? 
                            // Spec says producers at junctions 1 to K. 
                            // If N=16, nodes are 0..15. Prod 1 is node 0? Prod 2 is node 1?
                            // Let's assume producer index 'i' corresponds to node 'i'.
                            // (Since 1 to K maps to 0 to K-1 in 0-based indexing)
                            node_queue[0] <= prod_idx; 
                            queue_head <= 4'd0;
                            queue_tail <= 4'd1;
                            bfs_state <= 4'd1; // Start processing
                        end else begin
                            processing_done <= 1'b1;
                        end
                    end
                    
                    4'd1: begin // Pop from queue
                        if (queue_head < queue_tail) begin
                            curr_node <= node_queue[queue_head];
                            queue_head <= queue_head + 4'd1;
                            neighbor_idx <= 4'd0;
                            bfs_state <= 4'd2;
                        end else begin
                            // Queue empty, move to next producer
                            prod_idx <= prod_idx + 3'd1;
                            bfs_state <= 4'd0;
                        end
                    end
                    
                    4'd2: begin // Iterate neighbors
                        if (neighbor_idx < num_edges_reg) begin
                            // Check if edge starts from curr_node
                            if (src_reg[neighbor_idx] == curr_node) begin
                                // Found neighbor
                                dist_temp = dist_matrix[prod_idx][curr_node] + 5'd1;
                                if (dist_temp < dist_matrix[prod_idx][dst_reg[neighbor_idx]]) begin
                                    dist_matrix[prod_idx][dst_reg[neighbor_idx]] <= dist_temp;
                                    // Enqueue
                                    node_queue[queue_tail] <= dst_reg[neighbor_idx];
                                    queue_tail <= queue_tail + 4'd1;
                                end
                            end
                            neighbor_idx <= neighbor_idx + 4'd1;
                        end else begin
                            bfs_state <= 4'd1; // Pop next
                        end
                    end
                    
                    default: bfs_state <= 4'd0;
                endcase
            end else begin
                bfs_state <= 4'd0;
                processing_done <= 1'b0;
            end
            
            // --- Mask Iteration Control ---
            if (state == CHECK_MASK && next_state == CHECK_MASK) begin
                // This handles the initial mask=0 case or incrementing
                if (mask == 0) mask <= 8'd1;
                else mask <= mask + 8'd1;
            end
            
            // --- Pair Iteration Control ---
            if (state == CHECK_PAIRS && next_state == CHECK_PAIRS) begin
                if (mask[p1_idx] && mask[p2_idx]) begin
                    // If we checked this pair, move to next
                    p2_idx <= p2_idx + 3'd1;
                    if (p2_idx >= num_producers_reg - 1) begin
                        // Logic handled in next_state, but if we are here, we need to reset indices for next check or increment p1
                        // Actually, if p2 reaches limit, next_state moves to UPDATE or increments p1.
                        // Wait, the logic in next_state is slightly different.
                        // Let's simplify: If we skip conflict check (not active), we increment here.
                    end
                end else begin
                    // Skip inactive producer
                    p2_idx <= p2_idx + 3'd1;
                end
                
                if (p2_idx >= num_producers_reg) begin
                    p1_idx <= p1_idx + 3'd1;
                    p2_idx <= p1_idx + 3'd2; // Start next diagonal
                    if (p1_idx >= num_producers_reg - 1) begin
                        // Done with pairs, next state is UPDATE
                        // (Handled by next_state logic condition)
                    end
                end
            end
            
            // Reset conflict check indices when entering new pair check
            if (state == CHECK_PAIRS && next_state == CHECK_CONFLICT) begin
                edge_check_idx <= 4'd0;
            end
            
            if (state == UPDATE_RESULT) begin
                // Calculate popcount for current mask
                popcount <= count_bits(mask);
                // Increment mask for next iteration (if next_state is CHECK_MASK)
                // But wait, we need to increment mask AFTER update?
                // If state == UPDATE_RESULT, next_state is CHECK_MASK.
                // In CHECK_MASK (start of loop), we increment mask.
                // But we need to handle the very first mask (1) correctly.
                // If we are in UPDATE_RESULT, we just checked 'mask'.
                // So we should increment 'mask' now, ready for next CHECK_MASK.
                mask <= mask + 8'd1;
            end
            
            // Fix for CHECK_MASK logic:
            // The sequential logic above increments mask in UPDATE_RESULT.
            // So in CHECK_MASK state, we just evaluate the current mask.
            // But wait, we need to handle the transition from DIST_COMPUTE to CHECK_MASK.
            // In DIST_COMPUTE, mask is 0.
            // If we increment in UPDATE_RESULT, then CHECK_MASK gets the new mask.
            // The first mask to check is 1.
            if (state == DIST_COMPUTE && next_state == CHECK_MASK) begin
                mask <= 8'd1;
            end
            
        end
    end

    // Fix conflict_found reset when starting new pair check
    // (Handled in CHECK_MASK state for new mask, needs to be in CHECK_PAIRS for new pair)
    // Since 'conflict_found' is a register, we must reset it explicitly.
    // Reset it when entering CHECK_PAIRS logic for a specific pair.
    // But 'conflict_found' is used in CHECK_CONFLICT to skip remaining edges.
    // We reset 'conflict_found' at the start of a pair check.
    // This happens when state transitions from CHECK_PAIRS to CHECK_CONFLICT.
    // In the sequential block, we set conflict_found <= 1'b0 in CHECK_MASK.
    // We also need to set it when moving to next pair in CHECK_PAIRS.
    // Actually, the sequential block logic for CHECK_PAIRS is complex.
    // Let's add explicit reset of conflict_found in combinational or sequential.
    
    // Let's refine the sequential updates for indices to be cleaner.
    // The combinational next_state logic might be hard to perfectly sync with indices.
    // Let's rely on the state transitions to control index updates.
    
    // Re-implementing index updates in sequential block for clarity:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset values...
        end else begin
            // ... existing code ...
            
            // Refinement for CHECK_PAIRS state transitions
            if (state == CHECK_PAIRS && next_state == CHECK_CONFLICT) begin
                // We found an active pair to check. conflict_found is reset here.
                conflict_found <= 1'b0;
                edge_check_idx <= 4'd0;
            end
            
            // If we are in CHECK_PAIRS but next state is CHECK_PAIRS (skipping inactive)
            if (state == CHECK_PAIRS && next_state == CHECK_PAIRS) begin
                // This block increments indices. 
                // The logic in the 'else' block above handles this.
                // However, if we skip conflict check (mask bit not set), we increment.
                // If we just finished a conflict check (state == CHECK_CONFLICT -> CHECK_PAIRS),
                // we need to increment indices to move to next pair.
                if (state != CHECK_CONFLICT && next_state == CHECK_PAIRS) begin
                    // This condition is tricky. 
                    // Let's separate the increment logic cleanly.
                end
            end
            
            if (state == CHECK_CONFLICT && next_state == CHECK_PAIRS) begin
                // Finished checking this pair, move to next
                p2_idx <= p2_idx + 3'd1;
                if (p2_idx + 3'd1 >= num_producers_reg) begin
                    p1_idx <= p1_idx + 3'd1;
                    p2_idx <= p1_idx + 3'd2;
                end
            end
            
            // Also handle the skip case (inactive producer)
            if (state == CHECK_PAIRS && next_state == CHECK_PAIRS) begin
                // This means we are skipping.
                // Increment logic:
                if (p2_idx >= num_producers_reg) begin
                    p1_idx <= p1_idx + 3'd1;
                    p2_idx <= p1_idx + 3'd2;
                end else begin
                    p2_idx <= p2_idx + 3'd1;
                end
            end
            
        end
    end
    
    // Update combinational logic for CHECK_PAIRS to handle the skip correctly
    // The previous combinational block for CHECK_PAIRS had a flaw in increment logic.
    // Let's rewrite the CHECK_PAIRS next_state logic slightly.
    // Actually, let's just verify the logic flow:
    // 1. Enter CHECK_PAIRS.
    // 2. Check if p1 valid. If p1 >= K-1 -> UPDATE_RESULT.
    // 3. Check if p2 valid. If p2 >= K -> increment p1 (handled seq).
    // 4. If mask[p1] && mask[p2] -> CHECK_CONFLICT.
    // 5. Else -> CHECK_PAIRS (loop until p2 valid or mask active).
    
    // The sequential block above handles the increments when next_state is CHECK_PAIRS (skip) 
    // or CHECK_CONFLICT (found). 
    // We need to handle the case where p2 goes out of bounds inside CHECK_PAIRS.
    // If p2 >= K, we must increment p1. If p1 >= K-1, we go to UPDATE.
    // The combinational block handles the 'p2 >= num_producers_reg' check.

endmodule