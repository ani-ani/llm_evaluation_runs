module river_crossing(
    input clk,
    input rst_n,
    input start,
    input [15:0] edges_valid,
    input [3:0] edge_u [0:15],
    input [3:0] edge_v [0:15],
    output reg [15:0] result,
    output reg done
);

    // Node indices: 0-7 are boulders, 8 is left bank, 9 is right bank
    localparam [3:0] LEFT_BANK = 4'd8;
    localparam [3:0] RIGHT_BANK = 4'd9;
    localparam [3:0] NUM_PEOPLE = 4'd4;
    localparam [3:0] NUM_EDGES = 4'd16;
    localparam [3:0] MAX_NODES = 4'd10;
    localparam [3:0] MAX_PATH_LEN = 4'd15;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT        = 3'd1;
    localparam [2:0] BFS         = 3'd2;
    localparam [2:0] UPDATE      = 3'd3;
    localparam [2:0] CHECK_DONE  = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] person_count;          // Count of people processed (0-4)
    reg [3:0] left_behind;           // Count of people left behind
    reg [15:0] total_time;           // Accumulated time
    reg [15:0] current_edges_valid;  // Copy of edges_valid that gets modified
    
    // BFS registers
    reg [3:0] queue [0:9];           // Queue for BFS (max 10 nodes)
    reg [3:0] queue_head, queue_tail;
    reg [3:0] visited_nodes [0:9];   // Visited nodes (0=unvisited, 1=visited)
    reg [3:0] parent_node [0:9];     // Parent node for path reconstruction
    reg [3:0] current_node;
    reg [3:0] edge_idx;
    reg [3:0] path_length;
    reg [3:0] bfs_target;
    reg path_found;
    reg [7:0] cycle_count;
    
    // Path reconstruction registers
    reg [3:0] path_nodes [0:14];     // Stores nodes in reverse path order
    reg [3:0] path_edge_indices [0:14]; // Stores edge indices used in path
    reg [3:0] path_idx;
    reg [3:0] reconstruct_node;
    reg [3:0] edge_to_remove;
    reg [3:0] edge_iter;
    
    integer i;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            person_count <= 4'd0;
            left_behind <= 4'd0;
            total_time <= 16'd0;
            current_edges_valid <= 16'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            current_node <= 4'd0;
            edge_idx <= 4'd0;
            path_length <= 4'd0;
            bfs_target <= 4'd0;
            path_found <= 1'b0;
            cycle_count <= 8'd0;
            path_idx <= 4'd0;
            reconstruct_node <= 4'd0;
            edge_to_remove <= 4'd0;
            edge_iter <= 4'd0;
            result <= 16'd0;
            done <= 1'b0;
            for (i = 0; i < 10; i = i + 1) begin
                queue[i] <= 4'd0;
                visited_nodes[i] <= 4'd0;
                parent_node[i] <= 4'd0;
            end
            for (i = 0; i < 15; i = i + 1) begin
                path_nodes[i] <= 4'd0;
                path_edge_indices[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                INIT: begin
                    person_count <= 4'd0;
                    left_behind <= 4'd0;
                    total_time <= 16'd0;
                    current_edges_valid <= edges_valid;
                    cycle_count <= 8'd0;
                end
                
                BFS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // BFS state machine
                    if (queue_head < queue_tail && !path_found) begin
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        edge_idx <= 4'd0;
                    end
                    
                    // Process edges for current node
                    if (edge_idx < NUM_EDGES && current_node < MAX_NODES) begin
                        // Check if edge is valid and connects to current node
                        if (current_edges_valid[edge_idx]) begin
                            // Check if current node is endpoint of this edge
                            if (edge_u[edge_idx] == current_node && visited_nodes[edge_v[edge_idx]] == 4'd0) begin
                                // Found unvisited neighbor
                                visited_nodes[edge_v[edge_idx]] <= 4'd1;
                                parent_node[edge_v[edge_idx]] <= current_node;
                                queue[queue_tail] <= edge_v[edge_idx];
                                queue_tail <= queue_tail + 4'd1;
                                
                                // Check if we reached right bank
                                if (edge_v[edge_idx] == RIGHT_BANK) begin
                                    path_found <= 1'b1;
                                    path_length <= 4'd1; // Will increment later
                                end
                            end else if (edge_v[edge_idx] == current_node && visited_nodes[edge_u[edge_idx]] == 4'd0) begin
                                // Reverse direction
                                visited_nodes[edge_u[edge_idx]] <= 4'd1;
                                parent_node[edge_u[edge_idx]] <= current_node;
                                queue[queue_tail] <= edge_u[edge_idx];
                                queue_tail <= queue_tail + 4'd1;
                                
                                if (edge_u[edge_idx] == RIGHT_BANK) begin
                                    path_found <= 1'b1;
                                    path_length <= 4'd1;
                                end
                            end
                        end
                        edge_idx <= edge_idx + 4'd1;
                    end
                end
                
                UPDATE: begin
                    // Remove edges from the found path
                    if (edge_iter < path_length) begin
                        // Find the edge index to remove
                        if (edge_iter < path_length) begin
                            // Mark the edge as invalid
                            current_edges_valid[path_edge_indices[edge_iter]] <= 1'b0;
                        end
                        edge_iter <= edge_iter + 4'd1;
                    end
                end
                
                CHECK_DONE: begin
                    if (path_found) begin
                        total_time <= total_time + {12'd0, path_length};
                    end else begin
                        left_behind <= left_behind + 4'd1;
                    end
                    person_count <= person_count + 4'd1;
                end
                
                FINISH: begin
                    if (left_behind == 4'd0) begin
                        result <= total_time;
                    end else begin
                        result <= {12'd0, left_behind} + (16'd1 << 4);
                    end
                    done <= 1'b1;
                end
                
                default: begin
                    // Reset state-specific registers
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    current_node <= 4'd0;
                    edge_idx <= 4'd0;
                    path_length <= 4'd0;
                    path_found <= 1'b0;
                    path_idx <= 4'd0;
                    reconstruct_node <= 4'd0;
                    edge_to_remove <= 4'd0;
                    edge_iter <= 4'd0;
                    for (i = 0; i < 10; i = i + 1) begin
                        visited_nodes[i] <= 4'd0;
                        parent_node[i] <= 4'd0;
                    end
                    for (i = 0; i < 15; i = i + 1) begin
                        path_nodes[i] <= 4'd0;
                        path_edge_indices[i] <= 4'd0;
                    end
                end
            endcase
            
            // Override done when returning to idle
            if (state == IDLE) begin
                done <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            
            INIT: begin
                next_state = BFS;
            end
            
            BFS: begin
                // Continue BFS if no path found and queue not empty
                if (path_found) begin
                    next_state = UPDATE;
                end else if (queue_head >= queue_tail || cycle_count >= MAX_CYCLES) begin
                    // Queue empty or timeout - no path found
                    next_state = CHECK_DONE;
                end else begin
                    next_state = BFS;
                end
            end
            
            UPDATE: begin
                // Wait for edge removal to complete
                if (edge_iter >= path_length) begin
                    next_state = CHECK_DONE;
                end else begin
                    next_state = UPDATE;
                end
            end
            
            CHECK_DONE: begin
                if (person_count < NUM_PEOPLE - 1) begin
                    next_state = INIT;  // Reset for next person
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Path reconstruction logic (combinational)
    // This reconstructs the path from right bank to left bank
    // and stores edge indices for removal
    always @(*) begin
        if (path_found && state == UPDATE && edge_iter < path_length) begin
            // Walk back from right bank to find the edge used
            // This is simplified - we need to find which edge connects each node pair
            if (edge_iter == 4'd0) begin
                reconstruct_node = RIGHT_BANK;
            end else begin
                reconstruct_node = parent_node[reconstruct_node];
            end
            
            // Find the edge that connects reconstruct_node to its parent
            for (edge_to_remove = 0; edge_to_remove < NUM_EDGES; edge_to_remove = edge_to_remove + 1) begin
                if ((edge_u[edge_to_remove] == reconstruct_node && edge_v[edge_to_remove] == parent_node[reconstruct_node]) ||
                    (edge_v[edge_to_remove] == reconstruct_node && edge_u[edge_to_remove] == parent_node[reconstruct_node])) begin
                    // Found the edge
                end
            end
            // Note: This is just for illustration - actual edge finding happens in the BFS phase
            // In practice, we need to store the edge index during BFS
        end
    end

    // Modified BFS to record edge indices during traversal
    // This is a sequential process that overrides the BFS state's edge processing
    always @(posedge clk) begin
        if (state == BFS && edge_idx < NUM_EDGES && current_node < MAX_NODES) begin
            if (current_edges_valid[edge_idx]) begin
                // Check both directions
                if (edge_u[edge_idx] == current_node && visited_nodes[edge_v[edge_idx]] == 4'd0) begin
                    // Store edge index for path reconstruction
                    // We'll need to store this in a parallel structure
                    // For now, we'll handle edge removal by checking all edges during UPDATE
                    if (edge_v[edge_idx] == RIGHT_BANK) begin
                        path_edge_indices[0] <= edge_idx;
                    end
                end else if (edge_v[edge_idx] == current_node && visited_nodes[edge_u[edge_idx]] == 4'd0) begin
                    if (edge_u[edge_idx] == RIGHT_BANK) begin
                        path_edge_indices[0] <= edge_idx;
                    end
                end
            end
        end
    end

endmodule