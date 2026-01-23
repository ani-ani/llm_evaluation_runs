module cycle_decomposition(
    input clk,
    input rst_n,
    input start,
    input [5:0] node_count,
    input [5:0] edge_count,
    input [4:0] edge_from [63:0],
    input [4:0] edge_to [63:0],
    output reg valid,
    output reg [4:0] cycle_count,
    output reg [4:0] cycle_length [15:0],
    output reg [4:0] cycle_nodes [15:0][15:0],
    output reg [5:0] nodes_used
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam BUILD = 4'd1;
    localparam CHECK = 4'd2;
    localparam FIND_CYCLES = 4'd3;
    localparam VALIDATE = 4'd4;
    localparam DONE = 4'd5;

    reg [3:0] state;
    reg [3:0] next_state;

    // Adjacency Matrix: 16x16 bits
    // adj_matrix[i] is a 16-bit vector where bit j is 1 if edge exists from i to j
    reg [15:0] adj_matrix [15:0];

    // Internal counters and pointers
    reg [4:0] current_node; // Node index (0-15)
    reg [3:0] cycle_idx;    // Cycle index (0-15)
    reg [3:0] node_ptr;     // Pointer inside a cycle path
    reg [3:0] i, j;         // General purpose loop counters

    // Traversal state
    reg [15:0] visited_nodes; // Bitmask of nodes already placed in cycles
    reg [15:0] path_history [15:0]; // History of visited nodes in current traversal
    reg [15:0] temp_nodes_used;
    reg [3:0] path_len;
    reg [4:0] start_node;
    reg [4:0] next_node;
    reg [3:0] cycle_len_temp;

    // Status flags
    reg all_nodes_has_outgoing;
    reg is_cycle_found;
    reg is_valid_decomposition;
    reg [3:0] temp_cycle_count;

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? BUILD : IDLE;
            BUILD: next_state = (i == node_count) ? CHECK : BUILD;
            CHECK: next_state = all_nodes_has_outgoing ? FIND_CYCLES : DONE; // If check fails, go to DONE (valid=0)
            FIND_CYCLES: begin
                if (cycle_idx == node_count) begin
                    next_state = VALIDATE;
                end else begin
                    // Logic inside handles cycle finding, transition when cycle processed
                    if (visited_nodes[current_node]) begin
                        next_state = FIND_CYCLES; // Skip used nodes
                    end else begin
                        if (is_cycle_found) next_state = FIND_CYCLES; // Continue to next node
                        else next_state = FIND_CYCLES; // Continue traversing
                    end
                end
            end
            VALIDATE: next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State Transition and FSM Control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
        end else begin
            state <= next_state;
            
            // Reset valid when starting new computation
            if (state == IDLE && start) valid <= 0;
            if (state == DONE) valid <= is_valid_decomposition;
        end
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset internal signals
            i <= 0;
            j <= 0;
            current_node <= 0;
            cycle_idx <= 0;
            visited_nodes <= 16'h0;
            nodes_used <= 6'h0;
            all_nodes_has_outgoing <= 0;
            is_cycle_found <= 0;
            is_valid_decomposition <= 0;
            temp_cycle_count <= 0;
            path_len <= 0;
            cycle_len_temp <= 0;
            // Reset outputs
            cycle_count <= 0;
            // Cycle nodes and lengths initialized implicitly or explicitly if needed
        end else begin
            case (state)
                BUILD: begin
                    if (i < node_count) begin
                        // Initialize adjacency row to 0
                        adj_matrix[i] <= 16'h0;
                        // Check if we need to increment i (waiting for next cycle to populate)
                        // Actually, we need to scan all edges to populate the matrix
                        // Since we are sequential, we iterate j through edges
                    end
                    // Note: Building in single cycle requires combinational loop or multi-cycle
                    // Requirement says latency ~256 cycles, so we can iterate.
                    // Let's use 'j' for edges in a separate state or combine.
                    // Combined BUILD logic: iterate 'i' from 0 to edge_count-1
                end
            endcase
        end
    end

    // Re-implementing Logic cleanly in a single always block for robustness
    reg [5:0] edge_iter;
    reg [4:0] src, dst;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            i <= 0; 
            edge_iter <= 0;
            visited_nodes <= 16'h0;
            cycle_count <= 0;
            nodes_used <= 0;
            all_nodes_has_outgoing <= 0;
            path_len <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= BUILD;
                        edge_iter <= 0;
                        i <= 0;
                        // Clear adjacency matrix
                        for (int k=0; k<16; k++) adj_matrix[k] <= 16'h0;
                    end
                end

                BUILD: begin
                    // Build adjacency matrix from edge list
                    if (edge_iter < edge_count) begin
                        src <= edge_from[edge_iter];
                        dst <= edge_to[edge_iter];
                        // Register write next cycle (since RAM read is synchronous or inputs are regs)
                        // We update adj_matrix based on previous cycle's read or combinational
                        // Assuming inputs are stable, we can write directly:
                        if (edge_iter > 0) adj_matrix[src] <= adj_matrix[src] | (1 << dst);
                        edge_iter <= edge_iter + 1;
                    end else begin
                        // Handle the last edge write
                        if (edge_count > 0) adj_matrix[src] <= adj_matrix[src] | (1 << dst);
                        state <= CHECK;
                        i <= 0;
                    end
                    // Optimization: We can't easily update array in same cycle without combinational logic
                    // Let's use combinational update inside sequential block for valid inputs
                    if (edge_iter < edge_count) begin
                         // Actually, inputs are reg. We write to adj_matrix next cycle.
                         // We need to buffer one cycle or use combinational logic.
                         // Let's use combinational logic for the array update to save latency.
                         // Since edge_from/to are inputs, they are available immediately.
                         // We will update adj_matrix for edge_iter immediately in this block.
                         adj_matrix[edge_from[edge_iter]] <= adj_matrix[edge_from[edge_iter]] | (1 << edge_to[edge_iter]);
                    end
                end

                CHECK: begin
                    // Check if node i has at least one outgoing edge
                    if (i < node_count) begin
                        if (adj_matrix[i] == 16'h0) begin
                            all_nodes_has_outgoing <= 0;
                            state <= DONE;
                            valid <= 0;
                        end else begin
                            i <= i + 1;
                            if (i + 1 == node_count) begin
                                all_nodes_has_outgoing <= 1;
                                // Setup for cycle finding
                                state <= FIND_CYCLES;
                                cycle_idx <= 0;
                                visited_nodes <= 16'h0;
                                cycle_count <= 0;
                                nodes_used <= 0;
                            end
                        end
                    end else begin
                        all_nodes_has_outgoing <= 1;
                        state <= FIND_CYCLES;
                        cycle_idx <= 0;
                        visited_nodes <= 16'h0;
                        cycle_count <= 0;
                        nodes_used <= 0;
                    end
                end

                FIND_CYCLES: begin
                    // Greedy cycle finding
                    if (cycle_idx < node_count) begin
                        // Skip if node already used
                        if (visited_nodes[cycle_idx]) begin
                            cycle_idx <= cycle_idx + 1;
                        end else begin
                            // Start finding a cycle from node 'cycle_idx'
                            // Use iterative traversal
                            if (path_len == 0) begin
                                // Initialize path
                                path_history[0] <= cycle_idx;
                                path_len <= 1;
                                current_node <= cycle_idx;
                            end else begin
                                // Traverse
                                // Pick next node: first set bit in adj_matrix[current_node] not in visited_nodes
                                // But we must allow returning to start.
                                // Logic: Find first neighbor.
                                // If neighbor == start_node AND visited_nodes[start_node] is 0 (it is not yet marked used), it's a cycle.
                                // If neighbor is visited but not start, it's a conflict or old cycle. But we check visited_nodes array.
                                // visited_nodes tracks nodes already assigned to *valid* cycles.
                                
                                // Check if we have returned to start
                                if (current_node == cycle_idx && path_len > 1) begin
                                    // Cycle found
                                    // Record cycle info
                                    cycle_count <= cycle_count + 1;
                                    nodes_used <= nodes_used | (1 << cycle_idx); // Mark start node as used
                                    cycle_length[cycle_count] <= path_len;
                                    // Store nodes
                                    for (int k=0; k<16; k++) begin
                                        if (k < path_len) cycle_nodes[cycle_count][k] <= path_history[k];
                                        else cycle_nodes[cycle_count][k] <= 5'd0;
                                        if (k < path_len && path_history[k] != cycle_idx) nodes_used <= nodes_used | (1 << path_history[k]);
                                    end
                                    
                                    // Mark all nodes in path as visited
                                    for (int k=0; k<path_len; k++) visited_nodes <= visited_nodes | (1 << path_history[k]);
                                    
                                    path_len <= 0;
                                    cycle_idx <= cycle_idx + 1;
                                end else begin
                                    // Find next node
                                    // Priority encoder on adj_matrix[current_node]
                                    // Filter out already visited nodes (except start_node which is handled above)
                                    // Wait, visited_nodes might include nodes from other cycles. Those should be ignored.
                                    // If we hit a node in visited_nodes that is NOT start_node, it's invalid path? 
                                    // Greedy approach: If we hit a used node (not start), we stop? 
                                    // The prompt implies 'find cycles' on unused nodes. 
                                    // Let's strictly follow edges. If we hit a used node, backtrack or fail? 
                                    // Since it's a disjoint decomposition, we shouldn't hit used nodes.
                                    
                                    // Find first neighbor
                                    reg [15:0] neighbors;
                                    neighbors = adj_matrix[current_node];
                                    // Mask out nodes already in visited_nodes (except start_node logic is tricky)
                                    // Actually, if we start at A, go to B, B is visited (by another cycle), we fail for this start node A? 
                                    // Yes. We should probably skip start_node if it leads to a used node.
                                    // Let's implement a simple next node finder.
                                    
                                    next_node <= 5'd31; // invalid
                                    // Loop to find next valid neighbor (priority encoded)
                                    for (int n=0; n<16; n++) begin
                                        if (neighbors[n] && !visited_nodes[n] && n != cycle_idx) begin
                                            if (next_node == 5'd31) next_node <= n;
                                        end
                                        // Special case: if neighbor is start node
                                        if (neighbors[cycle_idx] && path_len > 1) begin
                                            next_node <= cycle_idx;
                                        end
                                    end
                                    
                                    // If no valid next node found (all neighbors used or invalid)
                                    if (next_node == 5'd31) begin
                                        // Dead end or self-loop logic check
                                        // Check for self loop (edge to self)
                                        if (adj_matrix[cycle_idx][cycle_idx] && path_len == 1 && cycle_idx == cycle_idx) begin
                                             // Self loop found
                                             cycle_count <= cycle_count + 1;
                                             cycle_length[cycle_count] <= 1;
                                             cycle_nodes[cycle_count][0] <= cycle_idx;
                                             visited_nodes <= visited_nodes | (1 << cycle_idx);
                                             nodes_used <= nodes_used | (1 << cycle_idx);
                                             path_len <= 0;
                                             cycle_idx <= cycle_idx + 1;
                                        end else begin
                                            // Invalid path for this start node. 
                                            // In a valid decomposition, this shouldn't happen if graph has a cycle.
                                            // We skip this node? No, if it's not a cycle, it's invalid.
                                            // But we might have started on a path that doesn't form a cycle yet? 
                                            // Greedy: pick first edge. 
                                            // If we can't complete cycle, maybe we need to backtrack or try different edge.
                                            // Given constraints, let's assume simple traversal works for valid inputs.
                                            // If invalid, we just move to next start node (effectively failing to use this node).
                                            // If at end we have unused nodes, VALIDATE will fail.
                                            path_len <= 0;
                                            cycle_idx <= cycle_idx + 1;
                                        end
                                    end else begin
                                        // Advance
                                        if (path_len < 16) begin
                                            path_history[path_len] <= next_node;
                                            path_len <= path_len + 1;
                                            current_node <= next_node;
                                        end else begin
                                            // Path too long (should not happen for cycles <= 16)
                                            path_len <= 0;
                                            cycle_idx <= cycle_idx + 1;
                                        end
                                    end
                                end
                            end
                        end
                    end else begin
                        state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    // Check if all nodes 0..node_count-1 are in visited_nodes
                    is_valid_decomposition <= 1;
                    for (int k=0; k<16; k++) begin
                        if (k < node_count) begin
                            if (!visited_nodes[k]) is_valid_decomposition <= 0;
                        end
                    end
                    state <= DONE;
                end

                DONE: begin
                    state <= IDLE;
                    valid <= is_valid_decomposition;
                end
            endcase
        end
    end

endmodule

// Helper module for priority encoder (not strictly necessary but cleaner logic in synthesis)
module prio_enc (
    input [15:0] in,
    output reg [4:0] out,
    output reg valid
);
    always @(*) begin
        valid = 0;
        out = 0;
        for (int i=0; i<16; i++) begin
            if (in[i]) begin
                out = i;
                valid = 1;
                break;
            end
        end
    end
endmodule
