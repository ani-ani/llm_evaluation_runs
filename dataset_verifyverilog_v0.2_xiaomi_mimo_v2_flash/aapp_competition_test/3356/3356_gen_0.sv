module mole_residence (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_a_i,
    input [2:0] node_b_i,
    input input_valid,
    input input_done,
    output reg [7:0] diameter_result,
    output reg [2:0] close_node_a,
    output reg [2:0] close_node_b,
    output reg [2:0] open_node_a,
    output reg [2:0] open_node_b,
    output reg computation_done
);

    // State encoding
    localparam IDLE          = 5'd0;
    localparam INPUT_EDGES   = 5'd1;
    localparam INIT_BFS      = 5'd2;
    localparam BFS_RUN       = 5'd3;
    localparam FIND_DIA_END  = 5'd4;
    localparam TRACE_PATH    = 5'd5;
    localparam ANALYZE_PATH  = 5'd6;
    localparam RECONNECT     = 5'd7;
    localparam DONE          = 5'd8;

    reg [4:0] current_state, next_state;

    // Adjacency Matrix: 64 bits (8x8)
    reg [63:0] adj_matrix;
    reg [63:0] adj_matrix_next;

    // BFS Registers
    reg [2:0] start_node;
    reg [2:0] start_node_next;
    reg [23:0] dist;           // 8 nodes * 3 bits
    reg [23:0] dist_next;
    reg [2:0] queue [0:7];
    reg [2:0] queue_next [0:7];
    reg [2:0] q_head;
    reg [2:0] q_head_next;
    reg [2:0] q_tail;
    reg [2:0] q_tail_next;
    reg [2:0] current_node;
    reg [2:0] current_node_next;
    
    // Traversal Registers
    reg [2:0] neighbor_node;
    reg [2:0] neighbor_node_next;
    
    // Path Registers
    reg [2:0] path_nodes [0:7];
    // path_nodes update logic in sequential block: path_nodes[path_idx] <= current_node;
    // We need to make sure `current_node` contains the node to store.
    reg [2:0] path_len;
    reg [2:0] path_len_next;
    reg [2:0] path_idx;
    reg [2:0] path_idx_next;

    // Diameter Result Registers
    reg [2:0] dia_end_a;
    reg [2:0] dia_end_b;
    reg [2:0] dia_end_a_next;
    reg [2:0] dia_end_b_next;
    
    // Temporary storage for cut/open nodes
    reg [2:0] close_u, close_v;
    reg [2:0] open_u, open_v;
    
    // BFS Phase Control
    reg bfs_phase;
    reg bfs_phase_next;
    
    // Edge Counter
    reg [2:0] edge_count;
    reg [2:0] edge_count_next;

    integer i;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            adj_matrix <= 64'd0;
            start_node <= 3'd0;
            dist <= 24'd0;
            q_head <= 3'd0;
            q_tail <= 3'd0;
            current_node <= 3'd0;
            neighbor_node <= 3'd0;
            path_len <= 3'd0;
            path_idx <= 3'd0;
            dia_end_a <= 3'd0;
            dia_end_b <= 3'd0;
            edge_count <= 3'd0;
            diameter_result <= 8'd0;
            close_node_a <= 3'd0;
            close_node_b <= 3'd0;
            open_node_a <= 3'd0;
            open_node_b <= 3'd0;
            computation_done <= 1'b0;
            bfs_phase <= 1'b0;
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                queue[i] <= 3'd0;
                path_nodes[i] <= 3'd0;
            end
        end else begin
            current_state <= next_state;
            adj_matrix <= adj_matrix_next;
            start_node <= start_node_next;
            dist <= dist_next;
            q_head <= q_head_next;
            q_tail <= q_tail_next;
            current_node <= current_node_next;
            neighbor_node <= neighbor_node_next;
            path_len <= path_len_next;
            path_idx <= path_idx_next;
            dia_end_a <= dia_end_a_next;
            dia_end_b <= dia_end_b_next;
            edge_count <= edge_count_next;
            bfs_phase <= bfs_phase_next;
            
            // Update Queue Array
            for (i = 0; i < 8; i = i + 1) begin
                queue[i] <= queue_next[i];
            end
            // Update Path Array (store current_node at path_idx)
            if (current_state == TRACE_PATH && path_idx < 8) begin
                path_nodes[path_idx] <= current_node;
            end
        end
    end

    // Combinational Logic
    always @(*) begin
        // Defaults
        next_state = current_state;
        adj_matrix_next = adj_matrix;
        start_node_next = start_node;
        dist_next = dist;
        q_head_next = q_head;
        q_tail_next = q_tail;
        current_node_next = current_node;
        neighbor_node_next = neighbor_node;
        path_len_next = path_len;
        path_idx_next = path_idx;
        dia_end_a_next = dia_end_a;
        dia_end_b_next = dia_end_b;
        edge_count_next = edge_count;
        bfs_phase_next = bfs_phase;
        
        // Queue default (copy current to next)
        for (i = 0; i < 8; i = i + 1) begin
            queue_next[i] = queue[i];
        end
        
        // Outputs default
        // (Keep previous values until DONE)

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = INPUT_EDGES;
                    adj_matrix_next = 64'd0;
                    edge_count_next = 3'd0;
                    bfs_phase_next = 1'b0;
                    dia_end_a_next = 3'd0;
                    dia_end_b_next = 3'd0;
                    computation_done = 1'b0;
                end
            end

            INPUT_EDGES: begin
                if (input_valid) begin
                    if (node_a_i != 3'd0 && node_b_i != 3'd0) begin
                        adj_matrix_next[(node_a_i - 1) * 8 + (node_b_i - 1)] = 1'b1;
                        adj_matrix_next[(node_b_i - 1) * 8 + (node_a_i - 1)] = 1'b1;
                        edge_count_next = edge_count + 1;
                    end
                end
                if (input_done) begin
                    next_state = INIT_BFS;
                end
            end

            INIT_BFS: begin
                // Reset dist to INF (7) and queue
                for (i = 0; i < 8; i = i + 1) begin
                    dist_next[i*3 +: 3] = 3'd7;
                    queue_next[i] = 3'd0;
                end
                // Determine start node for this BFS phase
                if (bfs_phase == 1'b0) begin
                    // Phase 0: Start from node 0 (Node 1)
                    start_node_next = 3'd0;
                    // But we need to find a reachable node if 0 is isolated? 
                    // Let's stick to 0. If disconnected, diameter might be 0.
                    dist_next[0 +: 3] = 3'd0;
                    queue_next[0] = 3'd0;
                    q_head_next = 3'd0;
                    q_tail_next = 3'd1;
                end else begin
                    // Phase 1: Start from dia_end_a
                    start_node_next = dia_end_a;
                    dist_next[dia_end_a*3 +: 3] = 3'd0;
                    queue_next[0] = dia_end_a;
                    q_head_next = 3'd0;
                    q_tail_next = 3'd1;
                end
                // Reset neighbor iterator
                neighbor_node_next = 3'd0;
                next_state = BFS_RUN;
            end

            BFS_RUN: begin
                // Perform BFS traversal
                // If queue is empty, go to FIND_DIA_END
                if (q_head == q_tail) begin
                    next_state = FIND_DIA_END;
                end else begin
                    // Dequeue current node
                    current_node_next = queue[q_head];
                    q_head_next = q_head + 1;
                    
                    // Process all neighbors in this cycle (Combinational Loop)
                    // We update dist_next and queue_next in place
                    // Note: dist_next is initialized to dist at the start of always block.
                    // current_node_next is just set.
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        // Check if edge exists
                        if (adj_matrix[current_node_next * 8 + i] == 1'b1) begin
                            // Check if not visited (dist is INF)
                            if (dist_next[i*3 +: 3] == 3'd7) begin
                                // Update distance
                                dist_next[i*3 +: 3] = dist_next[current_node_next*3 +: 3] + 1;
                                // Enqueue
                                queue_next[q_tail_next] = i[2:0];
                                q_tail_next = q_tail_next + 1;
                            end
                        end
                    end
                    next_state = BFS_RUN;
                end
            end

            FIND_DIA_END: begin
                // Find node with maximum distance
                // Use local variables for max finding
                // Default max to 0
                // We need to update dia_end_a_next or dia_end_b_next based on bfs_phase
                
                // Simple combinational max finder
                // We assign to temporary variables to determine the max node
                // Then assign to output registers
                
                // Note: In combinational block, local variables must be assigned inside or be wires.
                // We will use `current_node_next` as a temporary max holder? No, use local integer.
                
                // Reset max
                current_node_next = 3'd0;
                dist_next[0 +: 3] = dist[0 +: 3]; // Ensure dist_next is not modified wrongly (though it defaults to dist)
                
                // Iterate to find max
                for (i = 1; i < 8; i = i + 1) begin
                    if (dist[i*3 +: 3] != 3'd7) begin
                        if (dist[i*3 +: 3] > dist[current_node_next*3 +: 3]) begin
                            current_node_next = i[2:0];
                        end
                    end
                end
                
                // current_node_next now holds the node with max distance (or closest to 0 if all INF)
                
                if (bfs_phase == 1'b0) begin
                    // Phase 0 done
                    dia_end_a_next = current_node_next;
                    bfs_phase_next = 1'b1;
                    // If max distance is 0, it might be a single node or isolated.
                    // Proceed to phase 1 anyway.
                    next_state = INIT_BFS;
                end else begin
                    // Phase 1 done
                    dia_end_b_next = current_node_next;
                    // Diameter is the max distance found in this phase (dist[current_node_next])
                    // dist is the array from BFS starting at A.
                    diameter_result = {5'd0, dist[current_node_next*3 +: 3]};
                    next_state = TRACE_PATH;
                    // Setup for TRACE
                    // We need to trace from B (current_node_next) to A (dia_end_a)
                    current_node_next = current_node_next; // The node to start tracing from
                    path_idx_next = 3'd0;
                    // In TRACE_PATH, we will store B at index 0, then parent at 1, etc.
                    // We need to make sure the sequential block stores this.
                    // The sequential block stores `current_node` into `path_nodes[path_idx]`.
                    // So we set `current_node_next = dia_end_b`.
                    // And `path_idx_next = 0`.
                    // Wait, if we set `current_node_next` here, the sequential block updates `current_node`.
                    // Then in TRACE_PATH state, we read `current_node` (which is B), and `path_idx` (0).
                    // The sequential block executes: path_nodes[0] <= current_node (B).
                    // Correct.
                    
                    // Also, `dist` array is valid for path reconstruction (dist from A).
                end
            end

            TRACE_PATH: begin
                // We are tracing from B to A using `dist` array (distances from A).
                // `current_node` holds the current node in the trace (starts as B).
                // `path_idx` holds the index to store in `path_nodes`.
                
                // Check if we reached A (dia_end_a)
                if (current_node == dia_end_a) begin
                    // Path complete
                    path_len_next = path_idx;
                    path_idx_next = 3'd0; // Reset for next state
                    next_state = ANALYZE_PATH;
                end else begin
                    // Find neighbor with dist = dist[current] - 1
                    // We iterate neighbors using `neighbor_node` counter
                    
                    if (neighbor_node < 3'd7) begin
                        neighbor_node_next = neighbor_node + 1;
                    end else begin
                        neighbor_node_next = 3'd0;
                    end
                    
                    // Check edge and distance
                    if (adj_matrix[current_node * 8 + neighbor_node] == 1'b1) begin
                        if (dist[neighbor_node*3 +: 3] == dist[current_node*3 +: 3] - 1) begin
                            // Found parent
                            current_node_next = neighbor_node;
                            path_idx_next = path_idx + 1;
                            neighbor_node_next = 3'd0; // Reset neighbor iterator for next step
                        end
                    end
                    next_state = TRACE_PATH;
                end
            end

            ANALYZE_PATH: begin
                // Path is stored in path_nodes[0] (B) to path_nodes[path_len] (A).
                // path_len is the number of edges.
                
                // Indices:
                // Start of path (B): path_nodes[0]
                // End of path (A): path_nodes[path_len]
                // Center: path_nodes[path_len >> 1] (integer division)
                
                // Close edge: (A, Parent of A)
                // Parent of A is path_nodes[path_len - 1]
                // Open edge: (A, Center)
                
                close_u = path_nodes[path_len];
                close_v = path_nodes[path_len - 1];
                open_u = path_nodes[path_len];
                open_v = path_nodes[path_len >> 1];
                
                next_state = RECONNECT;
            end

            RECONNECT: begin
                // Convert 0-based internal to 1-based output
                // Node 0 (internal) -> Output 1.
                close_node_a = close_u + 1;
                close_node_b = close_v + 1;
                open_node_a = open_u + 1;
                open_node_b = open_v + 1;
                
                computation_done = 1'b1;
                next_state = DONE;
            end

            DONE: begin
                computation_done = 1'b1;
                if (!rst_n) next_state = IDLE;
                else next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule