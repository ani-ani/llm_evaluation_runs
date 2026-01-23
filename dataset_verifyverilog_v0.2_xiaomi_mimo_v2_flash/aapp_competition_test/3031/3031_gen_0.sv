module good_nodes_finder(
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [23:0] edge_data,
    input [2:0] edge_index,
    output reg [7:0] good_nodes,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam LOAD_EDGES = 3'b001;
    localparam CHECK_NODES = 3'b010;
    localparam CHECK_PATHS = 3'b011;
    localparam UPDATE_RESULT = 3'b100;
    localparam FINISHED = 3'b101;

    reg [2:0] state, next_state;
    
    // Edge storage: 8 nodes max, so 8x8 adjacency matrix for color
    // 0 means no edge, otherwise color value 1-8
    reg [3:0] adj_matrix [0:7][0:7];
    
    // Counter for loading edges
    reg [2:0] edge_load_cnt;
    
    // Node iteration counter
    reg [2:0] node_idx; // 0-7 representing node 1-8
    
    // BFS/DFS traversal registers
    reg [7:0] visited_nodes; // Bitmap of visited nodes during traversal
    reg [2:0] current_node; // Current node being visited in BFS
    reg [3:0] parent_edge_color; // Color of edge leading to current_node
    
    // Queue for BFS (simple FIFO)
    reg [2:0] queue [0:7]; // Queue of node indices
    reg [2:0] queue_head;
    reg [2:0] queue_tail;
    reg [3:0] queue_colors [0:7]; // Color of edge leading to node in queue
    
    // Flags
    reg node_is_bad; // Set high if current node fails rainbow condition
    reg [3:0] n_nodes; // Stored node count
    
    integer i, j;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_EDGES;
                else next_state = IDLE;
            end
            LOAD_EDGES: begin
                // Load n-1 edges. If n_nodes <= 1, skip immediately
                if (n_nodes <= 4'd1) next_state = FINISHED;
                else if (edge_load_cnt == n_nodes - 4'd1) next_state = CHECK_NODES;
                else next_state = LOAD_EDGES;
            end
            CHECK_NODES: begin
                // Iterate through nodes 1 to n
                if (node_idx >= n_nodes) begin
                    next_state = FINISHED;
                end else begin
                    // If node has neighbors, check paths, otherwise it's good
                    // Check if node has any edges
                    reg has_edges;
                    has_edges = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (adj_matrix[node_idx][i] != 4'd0 || adj_matrix[i][node_idx] != 4'd0) has_edges = 1;
                    end
                    if (!has_edges) next_state = UPDATE_RESULT; // Leaf node is good
                    else next_state = CHECK_PATHS;
                end
            end
            CHECK_PATHS: begin
                // BFS traversal check
                // If we found a bad path (node_is_bad) or queue empty (all paths checked good)
                if (node_is_bad) next_state = UPDATE_RESULT;
                else if (queue_head == queue_tail) next_state = UPDATE_RESULT; // Queue empty, node is good
                else next_state = CHECK_PATHS;
            end
            UPDATE_RESULT: begin
                next_state = CHECK_NODES;
            end
            FINISHED: begin
                if (start) next_state = IDLE; // Reset if start re-asserted
                else next_state = FINISHED;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            good_nodes <= 8'h0;
            done <= 1'b0;
            edge_load_cnt <= 3'b0;
            node_idx <= 3'b0;
            visited_nodes <= 8'h0;
            queue_head <= 3'b0;
            queue_tail <= 3'b0;
            node_is_bad <= 1'b0;
            n_nodes <= 4'd0;
            // Reset adjacency matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    adj_matrix[i][j] <= 4'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        n_nodes <= node_count;
                        edge_load_cnt <= 3'b0;
                        good_nodes <= 8'h0;
                        done <= 1'b0;
                        // Reset adj matrix on start
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                adj_matrix[i][j] <= 4'd0;
                            end
                        end
                    end
                end

                LOAD_EDGES: begin
                    // Load edge if index matches current load counter or sequential loading assumed
                    // The spec says edge_index is provided. We assume sequential loading 0, 1, 2...
                    // However, to be robust, let's just check if edge_index matches edge_load_cnt
                    // Actually, spec says "input [2:0] edge_index, Current edge index to load"
                    // If the input is valid in this cycle, load it.
                    if (edge_index == edge_load_cnt && edge_load_cnt < n_nodes - 4'd1) begin
                        // Extract data
                        // edge_data: {color[3:0], node_b[3:0], node_a[3:0]}
                        // node_a, node_b are 1-based. Convert to 0-based.
                        // Colors 1-8. 0 means no edge.
                        if (edge_data[3:0] != 4'd0 && edge_data[7:4] != 4'd0 && edge_data[11:8] != 4'd0) begin
                            // Check bounds < 8
                            if (edge_data[7:4] <= 4'd8 && edge_data[11:8] <= 4'd8) begin
                                adj_matrix[edge_data[11:8] - 4'd1][edge_data[7:4] - 4'd1] <= edge_data[3:0];
                                adj_matrix[edge_data[7:4] - 4'd1][edge_data[11:8] - 4'd1] <= edge_data[3:0];
                            end
                        end
                        edge_load_cnt <= edge_load_cnt + 3'b1;
                    end
                end

                CHECK_NODES: begin
                    node_idx <= node_idx + 3'b1;
                    // Prepare for BFS if needed
                    if (node_idx < n_nodes && (|adj_matrix[node_idx] || |adj_matrix[0][node_idx] || |adj_matrix[1][node_idx] || |adj_matrix[2][node_idx] || |adj_matrix[3][node_idx] || |adj_matrix[4][node_idx] || |adj_matrix[5][node_idx] || |adj_matrix[6][node_idx] || |adj_matrix[7][node_idx])) begin
                        // Initialize BFS for current node_idx
                        // We use a DFS-like state machine or BFS.
                        // Let's use a stack-like approach with a queue.
                        queue_head <= 3'b0;
                        queue_tail <= 3'b0;
                        visited_nodes <= 8'h0;
                        node_is_bad <= 1'b0;
                        
                        // Start with neighbors of node_idx
                        // Push neighbors to queue
                        // Note: We need to handle the root node specifically. 
                        // The root has no parent edge color.
                        // We need to check paths starting from root.
                        // Path: Root -> N1 -> N2 ...
                        // Condition: Edge(Root, N1) color != Edge(N1, N2) color.
                        // So we need to check adjacent edges in the path.
                        
                        // Strategy: Start BFS from node_idx.
                        // The queue stores {node, parent_color}.
                        // For the root (node_idx), we push its neighbors.
                        // The color of the edge to the neighbor is the first edge color.
                        // Then, when expanding from a node, we compare current edge color with parent_color.
                        
                        // Push neighbors of node_idx to queue
                        for (i = 0; i < 8; i = i + 1) begin
                            if (adj_matrix[node_idx][i] != 4'd0 && i != node_idx) begin
                                queue[queue_tail] <= i[2:0];
                                queue_colors[queue_tail] <= adj_matrix[node_idx][i];
                                queue_tail <= queue_tail + 3'b1;
                                visited_nodes[i] <= 1'b1; // Mark neighbor as visited to prevent loops back to root immediately
                            end
                        end
                        // Mark root as visited
                        visited_nodes[node_idx] <= 1'b1;
                    end
                end

                CHECK_PATHS: begin
                    // Process one node from queue per cycle
                    if (queue_head != queue_tail) begin
                        // Get current node from queue
                        // Pop from head
                        // Actually, Verilog reg array indexing is tricky in always blocks if not fully supported in synthesis, but usually ok.
                        // Let's use the extracted values.
                        
                        // We need to read queue[queue_head] and queue_colors[queue_head]
                        // But since it's a reg array, we need to index with a variable.
                        // Let's perform the operations.
                        
                        // Check: current_node = queue[queue_head], parent_color = queue_colors[queue_head]
                        // We need temporary registers for the read values in this cycle
                        // because we are updating pointers.
                        
                        // Actually, we can do this sequentially:
                        // 1. Read queue_head location
                        // 2. Update queue_head
                        // 3. Process neighbors
                        
                        // Let's define helper regs for the read values to avoid multiple driver issues if we split logic
                        // But since we are in a single always block, we can just use intermediate wires or process sequentially.
                        
                        // Let's just extract the current node logic into a separate combinational block or use if-else carefully.
                        // To be safe, we'll process the logic here:
                        
                        // We need to know the current node and color to process neighbors.
                        // Since queue_head is updated, we must capture the data first.
                        
                        // Temporary variables for the current step
                        reg [2:0] curr_node;
                        reg [3:0] prev_color;
                        curr_node = queue[queue_head];
                        prev_color = queue_colors[queue_head];
                        
                        // Move head pointer
                        queue_head <= queue_head + 3'b1;
                        
                        // Explore neighbors
                        for (i = 0; i < 8; i = i + 1) begin
                            if (adj_matrix[curr_node][i] != 4'd0 && !visited_nodes[i]) begin
                                // Found a path extension
                                // Check rainbow condition: prev_color != current_edge_color
                                if (prev_color == adj_matrix[curr_node][i]) begin
                                    node_is_bad <= 1'b1;
                                end else begin
                                    // Push to queue if not bad yet (if we want to continue searching for other bad paths)
                                    // Actually, if we found a bad path, we can stop, but state transition handles it.
                                    // Let's push anyway, but flag node_is_bad.
                                    // Optimization: If node_is_bad is high, we don't strictly need to push, but we might be in the middle of a cycle.
                                    // State transition checks node_is_bad next cycle.
                                    queue[queue_tail] <= i[2:0];
                                    queue_colors[queue_tail] <= adj_matrix[curr_node][i];
                                    queue_tail <= queue_tail + 3'b1;
                                    visited_nodes[i] <= 1'b1;
                                end
                            end
                        end
                    end
                end

                UPDATE_RESULT: begin
                    // Update good_nodes bitmask
                    // If node_is_bad is 0, node is good.
                    // Check if node was a leaf (no neighbors) - handled by CHECK_NODES state skipping to here.
                    // If node_idx was valid in CHECK_NODES, we update bit.
                    // Note: node_idx was incremented in CHECK_NODES state, so we refer to (node_idx - 1)
                    // But wait, CHECK_NODES increments node_idx. So if we are in UPDATE_RESULT, the node we just checked is (node_idx - 1).
                    // However, node_idx was incremented at the beginning of CHECK_NODES.
                    // Let's trace:
                    // CHECK_NODES state: node_idx = old_idx. 
                    // Inside CHECK_NODES: if valid, next_state = CHECK_PATHS.
                    // When CHECK_PATHS finishes, next_state = UPDATE_RESULT.
                    // So UPDATE_RESULT sees node_idx = old_idx + 1.
                    // The node checked was old_idx = node_idx - 1.
                    
                    // Wait, what if CHECK_NODES skipped directly to UPDATE_RESULT (leaf node)?
                    // Then node_idx was incremented. So we update (node_idx - 1).
                    
                    // So we need to update bit (node_idx - 1).
                    if (!node_is_bad) begin
                        // Mark node (node_idx - 1) as good
                        if (node_idx > 3'b0) begin
                            good_nodes[node_idx - 3'b1] <= 1'b1;
                        end
                    end
                    // Reset node_is_bad for next iteration (though CHECK_NODES resets it if we enter logic)
                    // node_is_bad is reset at start of CHECK_NODES.
                end

                FINISHED: begin
                    done <= 1'b1;
                    if (!start) begin
                        // Wait for start to go low to reset done or stay done
                        // Requirement: "High when computation complete"
                        // Usually stays high until next start.
                        // If start goes high again, we go to IDLE.
                    end
                end
            endcase
        end
    end

endmodule