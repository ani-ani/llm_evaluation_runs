module bicycle_race_routes(
    input clk,
    input rst_n,
    input start,
    input [7:0] node_enable,
    input [7:0] adj_matrix [0:7],
    output reg [29:0] result,
    output reg done,
    output reg inf_flag
);

    // States
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam COUNTING = 3'b011; // Can be merged or used for special handling
    localparam CYCLE_CHECK = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    
    // Path tracking: 16 steps, 3 bits per node
    reg [47:0] path;
    reg [3:0] depth;
    
    // Result
    reg [29:0] path_count;
    
    // Visited mask for current path
    reg [7:0] visited_mask;
    
    // Neighbor index counter (used in PROCESSING to scan 0..7)
    reg [3:0] node_idx;
    
    // Saved indices for backtracking (stack array)
    reg [3:0] saved_idx [0:15];
    
    // Temporary registers to hold the candidate neighbor found in PROCESSING
    reg [2:0] candidate_node;
    
    // Internal flag to distinguish backtrack vs extend in CYCLE_CHECK
    reg do_backtrack;
    
    // Combinational helpers
    wire [2:0] current_parent;
    wire depth_limit_hit;
    
    assign current_parent = (depth == 0) ? 3'b000 : path[(depth-1)*3 +: 3];
    assign depth_limit_hit = (depth >= 15); // Next step would be 16 (limit 16)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            inf_flag <= 0;
            path <= 0;
            depth <= 0;
            path_count <= 0;
            visited_mask <= 0;
            node_idx <= 0;
            candidate_node <= 0;
            do_backtrack <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    // inf_flag stays high until reset or new start if not cleared, but logic implies it resets on start
                    if (start) begin
                        inf_flag <= 0;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Start at node 0 (Town 1)
                    if (node_enable[0]) begin
                        path <= 0;
                        depth <= 0;
                        path_count <= 0;
                        visited_mask <= 8'b00000001; // Mark node 0
                        node_idx <= 0;
                        state <= PROCESSING;
                    end else begin
                        state <= DONE;
                    end
                end

                PROCESSING: begin
                    // Scan neighbors of current_parent
                    if (node_idx > 7) begin
                        // Finished scanning all neighbors for this parent
                        // Trigger backtrack
                        do_backtrack <= 1;
                        state <= CYCLE_CHECK;
                    end else begin
                        // Check if edge exists and node is enabled
                        if (adj_matrix[current_parent][node_idx] && node_enable[node_idx]) begin
                            // Check if it's a cycle involving destination
                            if (visited_mask[node_idx] && (node_idx == 1)) begin
                                inf_flag <= 1;
                                // Cycle detected. We can stop or continue? 
                                // Usually stop. Let's go to DONE.
                                state <= DONE;
                            end else if (!visited_mask[node_idx]) begin
                                // Valid unvisited neighbor
                                candidate_node <= node_idx;
                                // Save the NEXT index to check when we return to this parent
                                // (i.e., when we backtrack from this child)
                                saved_idx[depth] <= node_idx + 1;
                                state <= CYCLE_CHECK;
                                do_backtrack <= 0;
                            end else begin
                                // Visited but not destination cycle -> ignore, check next
                                node_idx <= node_idx + 1;
                            end
                        end else begin
                            // No edge or disabled, check next
                            node_idx <= node_idx + 1;
                        end
                    end
                end

                CYCLE_CHECK: begin
                    if (do_backtrack) begin
                        // --- Backtracking Logic ---
                        if (depth == 0) begin
                            state <= DONE;
                        end else begin
                            // Pop from stack
                            // 1. Get the node to remove (top of path)
                            // 2. Clear visited bit
                            // 3. Decrement depth
                            // 4. Restore node_idx for the new parent
                            
                            // Node to remove is at index (depth-1)
                            // path[(depth-1)*3 +: 3]
                            // We need to update visited_mask. 
                            // Since we are popping, the node at (depth-1) is removed.
                            // So visited_mask[ path[(depth-1)*3 +: 3] ] = 0;
                            
                            // However, synthesizing this array index into combinational logic for the always block is fine.
                            // But we need to be careful with ordering.
                            
                            // Let's extract the node first.
                            // Since we can't easily wire regs, we do it implicitly in the assignment.
                            
                            visited_mask[path[(depth-1)*3 +: 3]] <= 0;
                            
                            // Decrement depth
                            depth <= depth - 1;
                            
                            // Restore node_idx from stack
                            // We need the saved index corresponding to the new current depth.
                            // If we were at depth D, we saved at index D. Now we go to D-1.
                            // So we want saved_idx[D-1]. But we just decremented depth.
                            // So we want saved_idx[depth].
                            // Wait. If depth=2, we are at node 1. We saved at saved_idx[2] when we moved to node 1.
                            // Wait, no. saved_idx[k] stores the next index for the node at depth k.
                            // If we are at depth 2, we have nodes 0, 1.
                            // Node 1 is at index 1 in path.
                            // We save its index in saved_idx[1].
                            // When we backtrack from node 1, we are going back to node 0.
                            // Node 0 is at depth 0.
                            // We need to restore node_idx for node 0.
                            // We saved node 0's index in saved_idx[0].
                            // So we need to load from saved_idx[depth - 1] BEFORE decrementing depth.
                            // Or use saved_idx[depth] if we increment depth when pushing.
                            
                            // Let's adjust the push logic in PROCESSING:
                            // saved_idx[depth] <= node_idx + 1; 
                            // This means saved_idx[k] corresponds to the node that IS at depth k.
                            // So when we backtrack from depth k to k-1, we want saved_idx[k-1].
                            
                            // Revised Backtrack:
                            // Decrement depth.
                            // Then load node_idx = saved_idx[depth] (where depth is already decremented).
                            // 
                            // Example: Depth=2 (nodes 0,1). Backtrack node 1. New depth=1 (node 0).
                            // We want saved_idx[1]. But wait, node 1 was at depth 1? No.
                            // Depth 0: Node 0. Depth 1: Node 1.
                            // When we moved to Node 1, we saved at saved_idx[0]? No.
                            // Let's trace:
                            // Parent Node 0, depth 0.
                            // Find child 1. saved_idx[0] = node_idx + 1.
                            // Push child 1. depth becomes 1.
                            // 
                            // Backtrack from depth 1:
                            // We are popping node 1. New depth 0.
                            // We want saved_idx[0].
                            // So we should load node_idx <= saved_idx[depth - 1];
                            // So:
                            // node_idx <= saved_idx[depth - 1];
                            // depth <= depth - 1;
                            // visited_mask... 
                            
                            // Let's implement exactly that.
                            node_idx <= saved_idx[depth - 1];
                            depth <= depth - 1;
                            // Visited mask update: clear bit of the node being removed.
                            // The node being removed is path[(depth-1)*3 +: 3].
                            // We must ensure we use the OLD depth for the index.
                            // But we are updating depth in the same block.
                            // We should calculate the node to remove first.
                            // Let's use a variable or do it before update.
                            // Since we can't use variable in always block easily without extra wires, 
                            // we can just compute the index.
                            // path[(depth-1)*3 +: 3] uses 'depth'.
                            // We update 'depth'. So we should do the visited update first or use a temp.
                            // 
                            // Let's do:
                            // visited_mask[ path[(depth-1)*3 +: 3] ] <= 0;
                            // node_idx <= saved_idx[depth - 1];
                            // depth <= depth - 1;
                            // This order is correct. 'depth' is used in first two lines, then updated.
                            
                            // However, `path[(depth-1)*3 +: 3]` is a register select. It might be okay.
                            // But 'depth' is changing. Let's use a helper signal.
                            // Actually, let's just update visited_mask with the node we know we are removing.
                            // We can track it, or just compute it.
                            
                            // Let's assume standard logic works.
                            // visited_mask[ path[(depth-1)*3 +: 3] ] <= 0;
                            // node_idx <= saved_idx[depth - 1];
                            // depth <= depth - 1;
                            
                            // Wait, if we remove node 1, visited_mask[1] should be 0.
                            // path[ (1)*3 +: 3] is node 1. 
                            // So yes.
                            
                            state <= PROCESSING;
                        end
                    end else begin
                        // --- Extend Logic ---
                        if (depth_limit_hit) begin
                            // Depth limit reached. Do not extend.
                            // Requirement: "If depth > 15 and still counting, trigger cycle detection"
                            // Treat as infinite/cycle.
                            inf_flag <= 1;
                            state <= DONE;
                        end else begin
                            // Check if destination reached
                            if (candidate_node == 1) begin
                                // Count and DO NOT extend
                                if (path_count < 29'd999999999) 
                                    path_count <= path_count + 1;
                                else
                                    path_count <= 0;
                                
                                // Return to parent to continue scanning
                                // We need to restore node_idx from saved_idx[depth]
                                // (Because we saved it before entering CYCLE_CHECK)
                                node_idx <= saved_idx[depth];
                                state <= PROCESSING;
                            end else begin
                                // Extend path
                                path[depth*3 +: 3] <= candidate_node;
                                visited_mask[candidate_node] <= 1;
                                depth <= depth + 1;
                                node_idx <= 0; // Start scanning neighbors of new node
                                state <= PROCESSING;
                            end
                        end
                    end
                end

                DONE: begin
                    result <= path_count;
                    done <= 1;
                end
            endcase
        end
    end
endmodule