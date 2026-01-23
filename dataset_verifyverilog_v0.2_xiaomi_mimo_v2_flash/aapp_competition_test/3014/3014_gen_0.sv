module disco_cyber_security (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [4:0] num_edges,
    input [3:0] edge_u [0:15],
    input [3:0] edge_v [0:15],
    output reg [3:0] num_remove,
    output reg [3:0] remove_indices [0:7],
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_CYCLE = 3'b001;
    localparam REMOVE_EDGE = 3'b010;
    localparam UPDATE_MATRIX = 3'b011;
    localparam DONE = 3'b100;
    localparam RESET_CYCLE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Registers for edge iteration
    reg [4:0] current_edge_idx; // 0 to 15
    reg [3:0] node_idx; // 0 to 7 for BFS/DFS
    
    // Adjacency matrix storage (8x8 bits)
    // Using packed array for efficient storage and access
    reg [7:0] adj_matrix [0:7];
    
    // Registers for cycle detection (BFS)
    reg [7:0] visited;
    reg [7:0] queue [0:7]; // Simple FIFO for BFS (max 8 nodes)
    reg [2:0] q_head;
    reg [2:0] q_tail;
    reg q_empty;
    
    // Temporary storage for edge removal
    reg [3:0] target_node;
    reg found_path;
    
    // Removal list tracking
    reg [4:0] remove_count; // Can go up to 8, but uses 5 bits
    reg [4:0] removed_edges_mask; // Bitmask to track removed edges (max 16 edges)
    
    integer i, j;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = (num_edges == 0) ? DONE : RESET_CYCLE;
                else next_state = IDLE;
            end
            RESET_CYCLE: next_state = CHECK_CYCLE;
            CHECK_CYCLE: begin
                // If we checked all nodes or found cycle, go to next logic
                if (node_idx >= num_nodes || found_path) 
                    next_state = REMOVE_EDGE;
                else 
                    next_state = CHECK_CYCLE; // Keep checking BFS
            end
            REMOVE_EDGE: begin
                if (found_path && (remove_count < 8) && (remove_count < (num_edges >> 1))) 
                    next_state = UPDATE_MATRIX;
                else 
                    next_state = DONE; // Cannot remove more or no cycle found
            end
            UPDATE_MATRIX: next_state = DONE; // After removing edge, we are done for this edge iteration
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            num_remove <= 0;
            done <= 0;
            current_edge_idx <= 0;
            remove_count <= 0;
            removed_edges_mask <= 0;
            found_path <= 0;
            // Reset removal indices
            for (i = 0; i < 8; i = i + 1) remove_indices[i] <= 0;
            // Reset adjacency matrix
            for (i = 0; i < 8; i = i + 1) adj_matrix[i] <= 8'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize adjacency matrix
                        for (i = 0; i < 8; i = i + 1) adj_matrix[i] <= 8'b0;
                        current_edge_idx <= 0;
                        remove_count <= 0;
                        removed_edges_mask <= 0;
                        // Pre-build adjacency matrix based on initial edges
                        // (Or build incrementally, here we build incrementally in UPDATE_MATRIX or just check via stored pairs)
                        // Strategy: Store edges in matrix to check cycles. If cycle found, remove edge.
                        // Since we can remove edges, we need to modify matrix.
                    end
                end

                RESET_CYCLE: begin
                    // Prepare BFS for current edge (edge_u[current_edge_idx], edge_v[current_edge_idx])
                    // Check if path exists from v back to u in current graph
                    // Check if edge is already removed
                    if (removed_edges_mask[current_edge_idx]) begin
                        // Edge already removed, skip to next or done
                        found_path <= 0;
                    end else begin
                        // Initialize BFS
                        for (i = 0; i < 8; i = i + 1) visited[i] <= 0;
                        q_head <= 0;
                        q_tail <= 0;
                        q_empty <= 1;
                        node_idx <= 0; // Use node_idx as loop counter for BFS expansion
                        target_node <= edge_u[current_edge_idx]; // Target is source node (need path v -> u)
                        found_path <= 0;
                        
                        // If source and dest are same (self loop), immediately cycle
                        if (edge_u[current_edge_idx] == edge_v[current_edge_idx]) begin
                            found_path <= 1; // Cycle detected immediately
                            node_idx <= num_nodes; // Skip BFS loop
                        end else if (edge_u[current_edge_idx] == 0 || edge_v[current_edge_idx] > num_nodes) begin
                            // Invalid edge or out of bounds, ignore
                            found_path <= 0;
                            node_idx <= num_nodes;
                        end else begin
                            // Start BFS from v
                            // Enqueue v (convert 1-based to 0-based index for queue)
                            // Queue stores node index (0-7)
                            // We need to map v (1..8) to 0..7
                            if (edge_v[current_edge_idx] > 0 && edge_v[current_edge_idx] <= 8) begin
                                queue[0] <= edge_v[current_edge_idx] - 1;
                                visited[edge_v[current_edge_idx] - 1] <= 1;
                                q_tail <= 1;
                                q_empty <= 0;
                            end else begin
                                q_empty <= 1;
                            end
                        end
                    end
                end

                CHECK_CYCLE: begin
                    // Perform BFS steps
                    if (!q_empty && !found_path) begin
                        // Dequeue
                        reg [3:0] curr_node;
                        curr_node = queue[q_head];
                        q_head <= q_head + 1;
                        if (q_head + 1 == q_tail) q_empty <= 1;

                        // Check if current node matches target
                        if (curr_node == (target_node - 1)) begin
                            found_path <= 1;
                        end else begin
                            // Check neighbors from adjacency matrix
                            // adj_matrix[curr_node] has bits set for outgoing edges
                            // We iterate 0 to 7 to find neighbors
                            // To do this sequentially in hardware without huge logic:
                            // We can use node_idx as an iterator over neighbors 0..7
                            // But here CHECK_CYCLE state is re-entered. 
                            // Let's simplify: 
                            // BFS loop needs to check all neighbors of curr_node. 
                            // We'll use a sub-iteration or just unroll if small.
                            // Since we have 8 nodes, we can iterate neighbors 0 to 7.
                        end
                    end 
                    // To handle neighbor checking properly in a flat FSM without sub-states:
                    // We iterate through the bits of the adjacency row of the dequeued node.
                    // We need a variable to store the 'current node being expanded' and 'current neighbor to check'.
                    // Let's add registers for that.
                end
            endcase
        end
    end

    // Neighbor processing logic (split out for clarity and state management)
    // We need a way to iterate neighbors of a popped node.
    // Let's refine the FSM to handle the BFS neighbor scan.
    
    // Extra registers for BFS scan
    reg [3:0] bfs_current_node;
    reg [3:0] bfs_neighbor_iter;
    reg bfs_node_popped; // Flag to indicate we have a node to scan
    
    // Re-write the sequential logic to handle BFS properly
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            num_remove <= 0;
            done <= 0;
            current_edge_idx <= 0;
            remove_count <= 0;
            removed_edges_mask <= 0;
            for (i = 0; i < 8; i = i + 1) remove_indices[i] <= 0;
            for (i = 0; i < 8; i = i + 1) adj_matrix[i] <= 8'b0;
            found_path <= 0;
            bfs_node_popped <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Build initial adjacency matrix from inputs
                        // Note: We must build it initially if we want to check cycles.
                        // However, the problem implies we remove edges sequentially.
                        // We will populate the matrix initially.
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < num_edges) begin
                                if (edge_u[i] > 0 && edge_u[i] <= 8 && edge_v[i] > 0 && edge_v[i] <= 8) begin
                                    adj_matrix[edge_u[i]-1][edge_v[i]-1] <= 1;
                                end
                            end
                        end
                        current_edge_idx <= 0;
                        remove_count <= 0;
                        removed_edges_mask <= 0;
                        state <= CHECK_CYCLE_START;
                    end
                end

                CHECK_CYCLE_START: begin
                    // Check if we have processed all edges
                    if (current_edge_idx >= num_edges) begin
                        state <= DONE;
                    end else if (removed_edges_mask[current_edge_idx]) begin
                        // Edge already removed, skip to next
                        current_edge_idx <= current_edge_idx + 1;
                        state <= CHECK_CYCLE_START;
                    end else begin
                        // Start BFS for edge current_edge_idx
                        // Target: edge_u[current_edge_idx] (1-based)
                        // Start node: edge_v[current_edge_idx] (1-based)
                        
                        // Reset visited
                        for (i = 0; i < 8; i = i + 1) visited[i] <= 0;
                        q_head <= 0;
                        q_tail <= 0;
                        q_empty <= 1;
                        found_path <= 0;
                        
                        // Self loop check
                        if (edge_u[current_edge_idx] == edge_v[current_edge_idx]) begin
                            found_path <= 1;
                            state <= DECIDE_REMOVAL;
                        end else if (edge_u[current_edge_idx] == 0 || edge_v[current_edge_idx] == 0) begin
                            state <= NEXT_EDGE;
                        end else begin
                            // Start BFS
                            reg [3:0] start_v = edge_v[current_edge_idx] - 1;
                            visited[start_v] <= 1;
                            queue[0] <= start_v;
                            q_tail <= 1;
                            q_empty <= 0;
                            state <= BFS_LOOP;
                        end
                    end
                end

                BFS_LOOP: begin
                    if (!q_empty && !found_path) begin
                        // Pop node
                        reg [3:0] u_node = queue[q_head];
                        q_head <= q_head + 1;
                        if (q_head + 1 == q_tail) q_empty <= 1;
                        
                        // Check target
                        if (u_node == (edge_u[current_edge_idx] - 1)) begin
                            found_path <= 1;
                            state <= DECIDE_REMOVAL;
                        end else begin
                            // Scan neighbors of u_node
                            // We need to iterate 0..7 to find set bits in adj_matrix[u_node]
                            bfs_current_node <= u_node;
                            bfs_neighbor_iter <= 0;
                            if (adj_matrix[u_node] != 0) begin
                                state <= SCAN_NEIGHBORS;
                            end else begin
                                // No neighbors, continue BFS
                                state <= BFS_LOOP;
                            end
                        end
                    end else begin
                        // Queue empty or found path
                        state <= DECIDE_REMOVAL;
                    end
                end

                SCAN_NEIGHBORS: begin
                    if (bfs_neighbor_iter < 8) begin
                        if (adj_matrix[bfs_current_node][bfs_neighbor_iter]) begin
                            // Check if neighbor is visited
                            if (!visited[bfs_neighbor_iter]) begin
                                visited[bfs_neighbor_iter] <= 1;
                                // Enqueue
                                queue[q_tail] <= bfs_neighbor_iter;
                                q_tail <= q_tail + 1;
                            end
                        end
                        bfs_neighbor_iter <= bfs_neighbor_iter + 1;
                        // Stay in this state until all neighbors checked
                    end else begin
                        state <= BFS_LOOP;
                    end
                end

                DECIDE_REMOVAL: begin
                    if (found_path && (remove_count < 8) && (remove_count < (num_edges >> 1))) begin
                        // Remove this edge
                        remove_indices[remove_count] <= current_edge_idx + 1; // 1-based index
                        remove_count <= remove_count + 1;
                        removed_edges_mask[current_edge_idx] <= 1;
                        
                        // Remove edge from adjacency matrix
                        if (edge_u[current_edge_idx] > 0 && edge_v[current_edge_idx] > 0)
                            adj_matrix[edge_u[current_edge_idx]-1][edge_v[current_edge_idx]-1] <= 0;
                        
                        // Move to next edge
                        state <= NEXT_EDGE;
                    end else begin
                        // No removal needed or limit reached
                        state <= NEXT_EDGE;
                    end
                end

                NEXT_EDGE: begin
                    current_edge_idx <= current_edge_idx + 1;
                    state <= CHECK_CYCLE_START;
                end

                DONE: begin
                    done <= 1;
                    num_remove <= remove_count;
                end
            endcase
        end
    end

    // Need to define all states used in the FSM logic above
    localparam CHECK_CYCLE_START = 3'b001;
    localparam BFS_LOOP = 3'b010;
    localparam SCAN_NEIGHBORS = 3'b011;
    localparam DECIDE_REMOVAL = 3'b100;
    localparam NEXT_EDGE = 3'b101;
    // DONE state was defined as 3'b100 in the first definition, let's update localparams to match usage
    // The first localparam block is overwritten by the second definition in practice if not careful.
    // Let's ensure unique states:
    // IDLE = 0, CHECK_CYCLE_START = 1, BFS_LOOP = 2, SCAN_NEIGHBORS = 3, DECIDE_REMOVAL = 4, NEXT_EDGE = 5, DONE = 6
    
    // Redefine states correctly to match the logic flow
    always @(*) begin
        // This block is not strictly necessary if we use localparams consistently in the sequential block
        // But to be clean, we ensure the synthesis tool sees the flow
    end

    // Correcting the localparams to match the implemented state machine flow
    // The previous localparam block defined IDLE=000, CHECK_CYCLE=001, etc.
    // We essentially replaced CHECK_CYCLE with CHECK_CYCLE_START, BFS_LOOP, SCAN_NEIGHBORS, etc.
    // To keep the code valid, we need to use the state values used in the always block.
    // State values used in always block:
    // IDLE (implicit 0 or defined)
    // CHECK_CYCLE_START (new)
    // BFS_LOOP (new)
    // SCAN_NEIGHBORS (new)
    // DECIDE_REMOVAL (new)
    // NEXT_EDGE (new)
    // DONE (new)

endmodule

// To ensure the localparams match the logic, here is the explicit definition
// (The module body uses state names, so we need to map them. 
// Since the `always @(posedge...)` block uses named states, we need to define them.
// Usually, this is done at the top. I will inject the correct localparams into the code string.

// Re-generated module with explicit state definitions included in the code string:

module disco_cyber_security_final (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [4:0] num_edges,
    input [3:0] edge_u [0:15],
    input [3:0] edge_v [0:15],
    output reg [3:0] num_remove,
    output reg [3:0] remove_indices [0:7],
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CHECK_CYCLE_START = 3'b001;
    localparam BFS_LOOP = 3'b010;
    localparam SCAN_NEIGHBORS = 3'b011;
    localparam DECIDE_REMOVAL = 3'b100;
    localparam NEXT_EDGE = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state;
    
    // Registers
    reg [4:0] current_edge_idx;
    reg [4:0] remove_count;
    reg [15:0] removed_edges_mask;
    
    // Adjacency matrix (8x8)
    reg [7:0] adj_matrix [0:7];
    
    // BFS registers
    reg [7:0] visited;
    reg [2:0] q_head, q_tail;
    reg q_empty;
    reg [2:0] queue [0:7];
    reg [3:0] bfs_u_node; // Currently dequeued node
    reg [3:0] bfs_iter;   // Neighbor iterator
    
    // Helper signals
    reg [3:0] target_u;
    reg found_cycle;
    
    integer i;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            num_remove <= 0;
            remove_count <= 0;
            removed_edges_mask <= 0;
            current_edge_idx <= 0;
            found_cycle <= 0;
            for (i = 0; i < 8; i = i + 1) remove_indices[i] <= 0;
            for (i = 0; i < 8; i = i + 1) adj_matrix[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Build initial adjacency matrix
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < num_edges) begin
                                if (edge_u[i] > 0 && edge_u[i] <= 8 && edge_v[i] > 0 && edge_v[i] <= 8) begin
                                    adj_matrix[edge_u[i]-1][edge_v[i]-1] <= 1;
                                end
                            end
                        end
                        current_edge_idx <= 0;
                        remove_count <= 0;
                        removed_edges_mask <= 0;
                        state <= CHECK_CYCLE_START;
                    end
                end

                CHECK_CYCLE_START: begin
                    // Check if we are done iterating edges
                    if (current_edge_idx >= num_edges) begin
                        state <= DONE;
                    end else if (removed_edges_mask[current_edge_idx]) begin
                        // Edge already removed, skip to next
                        current_edge_idx <= current_edge_idx + 1;
                    end else begin
                        // Setup target and start BFS
                        target_u <= edge_u[current_edge_idx]; // 1-based
                        found_cycle <= 0;
                        
                        // Check immediate self-loop
                        if (edge_u[current_edge_idx] == edge_v[current_edge_idx]) begin
                            found_cycle <= 1;
                            state <= DECIDE_REMOVAL;
                        end else begin
                            // Initialize BFS queue
                            for (i = 0; i < 8; i = i + 1) visited[i] <= 0;
                            q_head <= 0;
                            q_tail <= 0;
                            q_empty <= 1;
                            
                            if (edge_v[current_edge_idx] > 0 && edge_v[current_edge_idx] <= 8) begin
                                reg [3:0] start_node = edge_v[current_edge_idx] - 1;
                                visited[start_node] <= 1;
                                queue[0] <= start_node;
                                q_tail <= 1;
                                q_empty <= 0;
                                state <= BFS_LOOP;
                            end else begin
                                // Invalid source/dest, treat as no cycle
                                state <= DECIDE_REMOVAL;
                            end
                        end
                    end
                end

                BFS_LOOP: begin
                    if (!q_empty && !found_cycle) begin
                        // Dequeue
                        bfs_u_node <= queue[q_head];
                        q_head <= q_head + 1;
                        if (q_head + 1 == q_tail) q_empty <= 1;
                        
                        // Prepare neighbor scan
                        bfs_iter <= 0;
                        state <= SCAN_NEIGHBORS;
                    end else begin
                        // Queue empty or cycle found
                        state <= DECIDE_REMOVAL;
                    end
                end

                SCAN_NEIGHBORS: begin
                    if (bfs_iter < 8) begin
                        // Check if there is an edge from bfs_u_node to bfs_iter
                        if (adj_matrix[bfs_u_node][bfs_iter]) begin
                            // Check target match (convert bfs_iter back to 1-based for comparison)
                            if ((bfs_iter + 1) == target_u) begin
                                found_cycle <= 1;
                                state <= DECIDE_REMOVAL; // Found path, stop searching
                            end else begin
                                // Check visited
                                if (!visited[bfs_iter]) begin
                                    visited[bfs_iter] <= 1;
                                    // Enqueue
                                    queue[q_tail] <= bfs_iter;
                                    q_tail <= q_tail + 1;
                                    if (q_tail == q_head) q_empty <= 0; // Should not happen given size, but safety
                                end
                            end
                        end
                        bfs_iter <= bfs_iter + 1;
                        // Stay in state to scan all neighbors
                    end else begin
                        state <= BFS_LOOP;
                    end
                end

                DECIDE_REMOVAL: begin
                    if (found_cycle && (remove_count < 8) && (remove_count < (num_edges >> 1))) begin
                        // Mark edge for removal
                        remove_indices[remove_count] <= current_edge_idx + 1; // 1-based index output
                        remove_count <= remove_count + 1;
                        removed_edges_mask[current_edge_idx] <= 1;
                        
                        // Update adjacency matrix (remove the edge)
                        if (edge_u[current_edge_idx] > 0 && edge_v[current_edge_idx] > 0)
                            adj_matrix[edge_u[current_edge_idx]-1][edge_v[current_edge_idx]-1] <= 0;
                    end
                    state <= NEXT_EDGE;
                end

                NEXT_EDGE: begin
                    current_edge_idx <= current_edge_idx + 1;
                    state <= CHECK_CYCLE_START;
                end

                DONE: begin
                    done <= 1;
                    num_remove <= remove_count;
                end
            endcase
        end
    end

endmodule