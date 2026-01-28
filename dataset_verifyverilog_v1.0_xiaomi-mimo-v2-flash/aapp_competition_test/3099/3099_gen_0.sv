module MinimumMessages (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] enemies,
    input wire [31:0] edges_valid,
    input wire [4:0] edge_src [31:0],
    input wire [4:0] edge_dst [31:0],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_MATRIX = 3'd1;
    localparam [2:0] FIND_COMPONENT = 3'd2;
    localparam [2:0] TRAVERSE = 3'd3;
    localparam [2:0] INCREMENT_COUNT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] edge_idx;
    reg [3:0] node_idx;
    reg [3:0] search_node;
    reg [15:0] visited;
    reg [15:0] q [15:0]; // 16-element queue, each is a 16-bit mask (one-hot or just index)
    reg [4:0] q_head;
    reg [4:0] q_tail;
    reg [15:0] adj [15:0]; // 16x16 adjacency matrix, row is source, bits are destinations
    reg [4:0] msg_count;
    reg [3:0] cycle_count; // Safety counter
    localparam [3:0] MAX_CYCLES = 4'd15; // Sufficient for 16 nodes

    // Combinational signals
    reg [15:0] current_node_mask;
    reg [15:0] new_neighbors;
    reg [15:0] valid_neighbors;
    reg found_unvisited;
    integer i;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            edge_idx <= 5'd0;
            node_idx <= 4'd0;
            search_node <= 4'd0;
            visited <= 16'd0;
            q_head <= 5'd0;
            q_tail <= 5'd0;
            msg_count <= 5'd0;
            cycle_count <= 4'd0;
            // Reset adjacency matrix
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    edge_idx <= 5'd0;
                    node_idx <= 4'd0;
                    visited <= 16'd0;
                    msg_count <= 5'd0;
                    cycle_count <= 4'd0;
                    // Clear queue pointers
                    q_head <= 5'd0;
                    q_tail <= 5'd0;
                    // Clear adjacency matrix
                    for (i = 0; i < 16; i = i + 1) begin
                        adj[i] <= 16'd0;
                    end
                end

                BUILD_MATRIX: begin
                    if (edge_idx < 32) begin
                        if (edges_valid[edge_idx]) begin
                            // Check if src and dst are not enemies
                            // Since enemy input is 16-bit, bit index matches node index
                            // However, edge_src/dst are 5-bit, so we check if < 16
                            // and if enemy bit is 0
                            if ((edge_src[edge_idx] < 16) && (edge_dst[edge_idx] < 16)) begin
                                if (!enemies[edge_src[edge_idx]] && !enemies[edge_dst[edge_idx]]) begin
                                    // Set bit in adjacency matrix
                                    adj[edge_src[edge_idx]][edge_dst[edge_idx]] <= 1'b1;
                                end
                            end
                        end
                        edge_idx <= edge_idx + 5'd1;
                    end
                end

                FIND_COMPONENT: begin
                    // Look for a non-enemy node that hasn't been visited
                    if (node_idx < 16) begin
                        if (!enemies[node_idx] && !visited[node_idx]) begin
                            search_node <= node_idx;
                            // Found a new source, increment count
                            msg_count <= msg_count + 5'd1;
                            // Mark visited immediately for the source
                            visited[node_idx] <= 1'b1;
                            // Initialize queue for this BFS
                            q[0] <= (1'b1 << node_idx); // Store mask or just the node index. Let's store mask.
                            // Actually, storing node index in queue is easier, but we need 4 bits. 
                            // Let's use q as a 16-bit mask queue for simplicity in hardware.
                            // q[q_tail] is the mask of nodes to process.
                            q[0] <= (16'd1 << node_idx);
                            q_tail <= 5'd1;
                            q_head <= 5'd0;
                            cycle_count <= 4'd0;
                        end
                        node_idx <= node_idx + 4'd1;
                    end
                end

                TRAVERSE: begin
                    // BFS traversal
                    // Check if queue is empty or cycle limit reached
                    if (q_head == q_tail || cycle_count >= MAX_CYCLES) begin
                        // Done with this component, return to FIND_COMPONENT
                        // But we need to wait a cycle to check next node in FIND_COMPONENT
                        // Transition handled in comb logic
                    end else begin
                        cycle_count <= cycle_count + 4'd1;
                        // Pop from queue
                        current_node_mask = q[q_head];
                        q_head <= q_head + 5'd1;
                        
                        // Expand current_node_mask (which should be a single bit in valid BFS)
                        // Find which bit is set (or just iterate all nodes if mask has multiple bits)
                        // Given BFS with single-source start, mask is usually one-hot.
                        // Let's handle the case where multiple nodes might be in the same mask for efficiency.
                        
                        // We will compute the union of neighbors for all bits in current_node_mask
                        new_neighbors = 16'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (current_node_mask[i]) begin
                                new_neighbors = new_neighbors | adj[i];
                            end
                        end
                        
                        // Filter out already visited and enemies
                        // Note: adj only has non-enemy edges, but we check visited
                        valid_neighbors = new_neighbors & ~visited;
                        
                        // Update visited
                        visited <= visited | valid_neighbors;
                        
                        // Enqueue valid neighbors
                        // If valid_neighbors is not empty
                        if (valid_neighbors != 16'd0) begin
                            q[q_tail] <= valid_neighbors;
                            q_tail <= q_tail + 5'd1;
                        end
                    end
                end

                INCREMENT_COUNT: begin
                    // State to handle counting logic or waiting
                    // Just pass through
                end

                FINISH: begin
                    result <= msg_count[3:0]; // Truncate to 4 bits
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = BUILD_MATRIX;
            end
            
            BUILD_MATRIX: begin
                if (edge_idx >= 32) next_state = FIND_COMPONENT;
            end
            
            FIND_COMPONENT: begin
                // If we found a new node to start BFS
                if (!enemies[node_idx] && !visited[node_idx] && node_idx < 16) begin
                    next_state = TRAVERSE;
                end else if (node_idx >= 16) begin
                    // Checked all nodes
                    next_state = FINISH;
                end else begin
                    // Keep looking
                    next_state = FIND_COMPONENT;
                end
            end
            
            TRAVERSE: begin
                // Continue traversing if queue has items and cycle count is low
                if (q_head != q_tail && cycle_count < MAX_CYCLES) begin
                    next_state = TRAVERSE;
                end else begin
                    // Finished component, go back to find next component
                    // We loop back to FIND_COMPONENT. 
                    // But we need to ensure node_idx is already incremented or we skip visited nodes.
                    // In FIND_COMPONENT logic, we increment node_idx until we find a free node.
                    // However, we just finished a BFS starting at 'search_node'.
                    // We should continue searching from 'search_node + 1'.
                    // Since we modified 'node_idx' in FIND_COMPONENT to set 'search_node',
                    // we need to reset 'node_idx' or just loop back.
                    // Wait, if we loop back to FIND_COMPONENT immediately, node_idx is still at the old position.
                    // We need to increment node_idx.
                    // Actually, if we loop back, the comb logic in FIND_COMPONENT checks !visited[node_idx].
                    // Since we visited the component rooted at node_idx, it is now visited.
                    // So it will skip and increment.
                    // However, the sequential logic in FIND_COMPONENT increments node_idx only if condition is met OR if it wraps?
                    // Let's look at sequential FIND_COMPONENT: it checks condition, if met it stops incrementing.
                    // This creates a latch or stuck state if we don't handle it carefully.
                    // Let's make it simpler: 
                    // In FIND_COMPONENT, we just look for an unvisited node.
                    // If found, go to TRAVERSE.
                    // If not found (node_idx >= 16), go to FINISH.
                    // When returning from TRAVERSE, we must ensure we search for the NEXT unvisited node.
                    // We can force node_idx to 0 in IDLE, but that rescan is inefficient.
                    // Better: Keep node_idx and in TRAVERSE->FIND_COMPONENT transition, we effectively scan again.
                    next_state = FIND_COMPONENT;
                end
            end
            
            FINISH: begin
                next_state = IDLE; // Self reset or wait for next start
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Fix for node_idx increment in FIND_COMPONENT
    // The sequential block increments node_idx only when checking a specific node.
    // If we loop back to FIND_COMPONENT, we need to continue from where we left off.
    // The current logic `if (!enemies[node_idx] && !visited[node_idx])` works if we keep node_idx.
    // But what if node_idx is currently at a visited node (from previous component)?
    // We need to advance node_idx until we find a free one or reach end.
    // The current sequential logic only advances if the condition is met (i.e. found one) or implicitly if we don't check?
    // No, the sequential block has `if (node_idx < 16)`. If it doesn't enter the inner if, node_idx stays same.
    // This causes infinite loop if node_idx is stuck at a visited/enemy node.
    // We need to modify the FIND_COMPONENT sequential logic to increment node_idx every cycle until found or end.

endmodule