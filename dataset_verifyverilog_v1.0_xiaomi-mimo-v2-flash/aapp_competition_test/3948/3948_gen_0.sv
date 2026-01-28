module VerifyMultihedgehog (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [15:0] adj_matrix [0:15][0:15],
    output reg result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] INIT         = 4'd1;
    localparam [3:0] CHECK_K0     = 4'd2;
    localparam [3:0] FIND_LEAVES  = 4'd3;
    localparam [3:0] CHECK_PARENT = 4'd4;
    localparam [3:0] REMOVE_LEAVES = 4'd5;
    localparam [3:0] CHECK_FINAL  = 4'd6;
    localparam [3:0] SUCCESS      = 4'd7;
    localparam [3:0] FAIL         = 4'd8;
    localparam [3:0] DONE_OUT     = 4'd9;

    reg [3:0] state;
    reg [3:0] curr_k;
    reg [3:0] valid_nodes_count;
    reg [3:0] parent_idx;
    reg [15:0] active_nodes;
    reg [3:0] degree [0:15];
    reg [15:0] current_leaves;
    reg [3:0] remaining_nodes;
    reg found_error;
    reg [4:0] i;
    reg [4:0] j;
    reg [3:0] leaf_count;
    reg [3:0] active_degree;
    reg [3:0] loop_k;
    reg [3:0] leaf_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            // Initialize arrays
            for (int init_i = 0; init_i < 16; init_i = init_i + 1) begin
                degree[init_i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Compute initial degrees
                    // Reset flags
                    found_error <= 1'b0;
                    valid_nodes_count <= 4'd0;
                    active_nodes <= 16'hFFFF;
                    // Trim active_nodes to n
                    for (int bit_idx = 0; bit_idx < 16; bit_idx = bit_idx + 1) begin
                        if (bit_idx >= n) begin
                            active_nodes[bit_idx] <= 1'b0;
                        end
                    end
                    // Calculate degrees based on adjacency matrix
                    // We do this in a single pass logic or small loop (simulated here)
                    // Since combinational logic is preferred for degrees, we will compute continuously in always block
                    // But here we are in sequential FSM, so we need to compute degree.
                    // Let's assume degree calculation happens in INIT or is pre-computed.
                    // Since adj_matrix is input, we can compute degrees in a combinational block
                    // and latch in INIT.
                    // However, to stick to FSM constraints, let's compute degree in INIT.
                    
                    // Reset degrees to 0
                    for (int d_init = 0; d_init < 16; d_init = d_init + 1) begin
                        degree[d_init] <= 4'd0;
                    end
                    // Note: Due to Verilog limitations in loop unrolling with input arrays, 
                    // we might need a counter or assume synthesis handles it. 
                    // We will use a loop counter 'i' to iterate over nodes.
                    i <= 4'd0;
                    j <= 4'd0;
                    
                    // If k > n-1, impossible (centers need branches)
                    if (k >= n && n > 1) begin
                        state <= FAIL;
                    end else begin
                        state <= CHECK_K0;
                    end
                end

                CHECK_K0: begin
                    // Handle k=0 case (single node)
                    if (k == 4'd0) begin
                        if (n == 4'd1) begin
                            state <= SUCCESS;
                        end else begin
                            state <= FAIL;
                        end
                    end else begin
                        // Start peeling process
                        curr_k <= k;
                        loop_k <= 4'd0;
                        // We need to calculate degrees first. 
                        // Since we can't do combinational assignment in sequential block easily,
                        // let's assume we calculate degree in a separate step or we do it here.
                        // Let's do degree calculation before peeling.
                        state <= FIND_LEAVES;
                    end
                end

                FIND_LEAVES: begin
                    // Compute degrees for current active nodes
                    // This is tricky in sequential. We will compute degree on the fly in FIND_LEAVES
                    // and store in degree array.
                    // Since adj_matrix is an input, we can access it.
                    // We will iterate i from 0 to n-1 to calculate degree.
                    // Since n is max 16, we can use a counter.
                    
                    // To make this synthesizable and simple, we treat degree calculation as part of the step.
                    // We will iterate i from 0 to 15 to update degrees.
                    
                    // Reset degrees for active nodes
                    if (i < n) begin
                        if (active_nodes[i]) begin
                            degree[i] <= 4'd0;
                            j <= 4'd0;
                            state <= 4'd20; // Sub-state for degree calc inner loop
                        end else begin
                            i <= i + 4'd1;
                        end
                    end else begin
                        // Done calculating degrees
                        i <= 4'd0;
                        leaf_count <= 4'd0;
                        current_leaves <= 16'b0;
                        state <= 4'd10; // Go to check leaves
                    end
                end

                4'd20: begin // Inner loop for degree calc
                    if (j < n) begin
                        if (adj_matrix[i][j] && active_nodes[j]) begin
                            degree[i] <= degree[i] + 4'd1;
                        end
                        j <= j + 4'd1;
                    end else begin
                        i <= i + 4'd1;
                        state <= FIND_LEAVES;
                    end
                end

                4'd10: begin // Identify leaves
                    if (i < n) begin
                        if (active_nodes[i] && degree[i] == 4'd1) begin
                            current_leaves[i] <= 1'b1;
                            leaf_count <= leaf_count + 4'd1;
                        end
                        i <= i + 4'd1;
                    end else begin
                        if (leaf_count == 4'd0) begin
                            // No leaves found - fail unless this is the last step and only center remains
                            // But strictly, peeling requires leaves.
                            // Exception: If only 1 node remains (the center) and loop is done? 
                            // Handled in CHECK_FINAL.
                            // If loop is active, we need leaves.
                            state <= FAIL;
                        end else begin
                            state <= CHECK_PARENT;
                        end
                    end
                end

                CHECK_PARENT: begin
                    // Find the common parent of leaves
                    // Iterate to find a node connected to all leaves
                    // Reset parent found flag
                    found_error <= 1'b1; // Assume failure until proven otherwise
                    i <= 4'd0;
                    state <= 4'd11;
                end

                4'd11: begin // Find candidate parent
                    if (i < n) begin
                        if (active_nodes[i]) begin
                            // Check if i is connected to all leaves
                            j <= 4'd0;
                            parent_idx <= i;
                            state <= 4'd12;
                        end else begin
                            i <= i + 4'd1;
                        end
                    end else begin
                        if (found_error) begin
                            state <= FAIL;
                        end else begin
                            state <= FAIL; // Should have found parent
                        end
                    end
                end

                4'd12: begin // Verify parent connection to all leaves
                    if (j < n) begin
                        if (current_leaves[j]) begin
                            if (adj_matrix[parent_idx][j]) begin
                                j <= j + 4'd1;
                            end else begin
                                // Not connected to this leaf
                                state <= 4'd11; // Try next candidate
                                i <= i + 4'd1;
                            end
                        end else begin
                            j <= j + 4'd1;
                        end
                    end else begin
                        // Found a valid parent
                        // Check if it's the ONLY one (optional, but good for strictness)
                        // Actually, definition implies unique center.
                        // Let's just mark found and continue.
                        found_error <= 1'b0;
                        // Check degree requirement: Parent must have degree >= 3 in current graph
                        // Unless it's the final center (k=1) or special cases.
                        // For k > 1, centers must have degree >= 3.
                        // For the center remaining at the end (k=1 case), it must have degree >= 3 initially?
                        // Yes, definition: "center node with degree >= 3" for k=1.
                        // For peeling steps, the parent is the center of a sub-hedgehog.
                        // So degree must be >= 3.
                        
                        // However, if this is the LAST step (curr_k == 1), the parent becomes the final center.
                        // We check degree >= 3.
                        // Wait, if curr_k == 1, we remove leaves, leaving center. We must check center degree >= 3?
                        // Actually, we check degree >= 3 before removal.
                        // If the graph is a single center, degree should be >= 3.
                        // If the graph is being peeled, the parent degree should be >= 3.
                        // But wait, if there are 2 leaves and a center, degree is 2. This is not a hedgehog.
                        // So degree >= 3 is strict.
                        
                        // Special case: if (remaining_nodes == leaf_count + 1), then we are at the center.
                        // The degree check applies.
                        
                        if (degree[parent_idx] < 4'd3) begin
                             state <= FAIL;
                        end else begin
                             state <= REMOVE_LEAVES;
                        end
                    end
                end

                REMOVE_LEAVES: begin
                    // Decrement parent degree by leaf_count
                    // Remove leaves from active_nodes
                    // We do this by iterating.
                    if (i < n) begin
                        if (current_leaves[i]) begin
                            active_nodes[i] <= 1'b0;
                        end
                        i <= i + 4'd1;
                    end else begin
                        // Update parent degree
                        // Note: degree[parent_idx] currently holds full degree.
                        // The new degree of the center is (degree - leaf_count).
                        // In a true hedgehog, after removing leaves, the center becomes a leaf (degree 1) 
                        // relative to the upper level (unless k=1).
                        // Wait, the logic says:
                        // "Outer Loop (iter k times)"
                        // "At each peeling step... set of removed leaves must have common parent."
                        // "Parent must have degree >= 3."
                        // "Remove leaves: Decrement degree of parent."
                        
                        // Let's update degree[parent_idx].
                        // Since we are iterating, we can just update the register.
                        degree[parent_idx] <= degree[parent_idx] - leaf_count;
                        
                        // Decrement remaining nodes count
                        remaining_nodes <= remaining_nodes - leaf_count;
                        
                        // Next iteration
                        curr_k <= curr_k - 4'd1;
                        loop_k <= loop_k + 4'd1;
                        
                        // Reset loop counters
                        i <= 4'd0;
                        
                        if (curr_k == 4'd1) begin
                            // After this step, we should check final state
                            state <= CHECK_FINAL;
                        end else begin
                            // Continue peeling
                            state <= FIND_LEAVES;
                        end
                    end
                end

                CHECK_FINAL: begin
                    // Check if exactly one node remains
                    // Count active nodes
                    if (i < n) begin
                        if (active_nodes[i]) begin
                            valid_nodes_count <= valid_nodes_count + 4'd1;
                            // We can also check if this node has degree > 0 (connected to others)
                        end
                        i <= i + 4'd1;
                    end else begin
                        if (valid_nodes_count == 4'd1) begin
                            state <= SUCCESS;
                        end else begin
                            state <= FAIL;
                        end
                    end
                end

                SUCCESS: begin
                    result <= 1'b1;
                    state <= DONE_OUT;
                end

                FAIL: begin
                    result <= 1'b0;
                    state <= DONE_OUT;
                end

                DONE_OUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for initial degree calculation (needed for INIT state transition)
    // We need a separate always block or we integrate into FSM. 
    // The FSM above handles logic sequentially. To ensure correctness for the start:
    // We need to populate 'remaining_nodes' initially.
    // Since 'n' is an input, we can't use it directly in 'for' loop synthesis easily for initialization of state.
    // The FSM 'INIT' state sets up 'n' count.
    
    // However, the sequential loops inside FSM for degree calculation are complex for Verilog.
    // A cleaner approach for Verilog synthesis is to use a combinational block for degree calculation
    // and latch it in a cycle. But the requirements say "use small FSM".
    
    // Let's refine the FSM to be more linear and robust.
    // The above code attempts a complex sequential loop. Let's rewrite it to be cleaner.
    
    // Revision: The logic requires calculating degrees dynamically as nodes are removed.
    // Since n is small (16), we can unroll loops or use a simple state machine for each step.
    // The current FSM structure is okay, but the nested loop logic is fragile.
    
    // Let's simplify: 
    // INIT: Set active_nodes mask, set remaining_nodes = n.
    // LOOP_START: If curr_k == 0, check remaining_nodes == 1.
    //             If remaining_nodes == 1, Success. Fail if curr_k > 0.
    //             Calculate degrees for all active nodes (using a nested FSM state).
    //             Identify leaves. If none, Fail.
    //             Find parent. If multiple or none, Fail.
    //             Check parent degree >= 3. Fail if not.
    //             Remove leaves (update active_nodes, remaining_nodes).
    //             curr_k--. Go to LOOP_START.
    
    // The code block provided above is a valid implementation attempt. 
    // I will clean up the state definitions and make sure all cases are covered.
    
    // One issue: The nested loop for degree calc (state 20, 4'hd10, 4'd11, 4'd12) needs careful management of i/j.
    // The code in 4'd11 checks candidates. It increments i to check next candidate.
    // If a candidate fails (not connected to all leaves), we go back to 4'd11 with i incremented.
    // If i reaches n, we fail.
    // If candidate passes (in 4'd12), we set found_error=0 and go to REMOVE.
    // Wait, in 4'd12, if we check all leaves and they are connected, we should break out.
    // But the loop in 4'd12 checks *all* nodes j. If j < n, loop. If j == n, we are done.
    // If we reach end of j loop, we found the parent. We set found_error = 0.
    // Then we need to go to REMOVE_LEAVES.
    // But the code in 4'd12 goes to FAIL if found_error is true (which it is by default).
    // The logic `if (found_error) state <= FAIL` is executed when j finishes?
    // No, it's executed when `j < n` is false.
    // If `j < n` is false, we checked all j. If we are here, `found_error` is still 1?
    // We need to set `found_error <= 1'b0` when we successfully verify a connection.
    // But we verify connection incrementally.
    // Correct logic for 4'd12:
    // If j < n:
    //    Check if j is a leaf.
    //    If yes, check connection.
    //    If no connection, go back to 4'd11 (next candidate).
    //    If connected, j++.
    // If j == n:
    //    All leaves connected. We found the parent. 
    //    Set found_error = 0. Go to REMOVE.
    
    // Let's rewrite 4'd12 carefully.
    // Also, we need to handle the initial degree calculation in INIT.
    // The code in INIT skips degree calc, assuming it happens in FIND_LEAVES.
    // But FIND_LEAVES uses degrees. 
    // We should calculate degrees once in INIT before entering loop.
    
    // Let's adjust the states:
    // INIT: Calculate degrees for all nodes. 
    //       Use a counter. 
    //       If i < n: Calculate degree[i]. 
    //       Then i++. 
    //       When i == n, go to CHECK_K0.
    
    // I will provide the corrected module in the final output.
endmodule

// Note: The complexity of sequential loops in Verilog synthesis is high. 
// A standard "peeling" algorithm for small N usually implies unrolled logic or a datapath.
// Given the constraint "small FSM (max 64 states)", a sequential loop is acceptable.
// The code below refines the state machine to be cleaner.

module VerifyMultihedgehog (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [15:0] adj_matrix [0:15][0:15],
    output reg result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] SETUP        = 4'd1; // Initialize active nodes
    localparam [3:0] DEG_CALC     = 4'd2; // Calculate degrees for active nodes
    localparam [3:0] FIND_LEAVES  = 4'd3; // Identify leaves
    localparam [3:0] FIND_PARENT  = 4'd4; // Find common parent
    localparam [3:0] CHECK_DEG    = 4'd5; // Check parent degree >= 3
    localparam [3:0] REMOVE       = 4'd6; // Remove leaves
    localparam [3:0] NEXT_ITER    = 4'd7; // Decrement k, loop
    localparam [3:0] FINAL_CHECK  = 4'd8; // Check one node remains
    localparam [3:0] SUCCESS_S    = 4'd9;
    localparam [3:0] FAIL_S       = 4'd10;
    localparam [3:0] DONE_S       = 4'd11;

    reg [3:0] state;
    reg [3:0] loop_counter;
    reg [3:0] active_count;
    reg [15:0] active_mask;
    reg [3:0] degree [0:15];
    reg [15:0] leaf_mask;
    reg [3:0] parent_idx_reg;
    reg [3:0] i_reg, j_reg; // Loop counters
    reg [3:0] temp_deg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize
                        if (n == 4'd0 || n > 4'd15) begin
                            state <= FAIL_S; // Invalid N
                        end else begin
                            state <= SETUP;
                        end
                    end
                end

                SETUP: begin
                    // Setup active mask and loop counter
                    active_mask <= 16'hFFFF >> (16 - n); // Set n bits to 1
                    active_count <= n;
                    loop_counter <= k;
                    // Special case for k=0
                    if (k == 4'd0) begin
                        if (n == 4'd1) state <= SUCCESS_S;
                        else state <= FAIL_S;
                    end else begin
                        state <= DEG_CALC;
                    end
                    // Reset loop vars
                    i_reg <= 4'd0;
                    leaf_mask <= 16'b0;
                end

                DEG_CALC: begin
                    // Calculate degrees for all active nodes
                    if (i_reg < n) begin
                        if (active_mask[i_reg]) begin
                            // Compute degree of node i_reg
                            temp_deg <= 4'd0;
                            j_reg <= 4'd0;
                            // We need a sub-state to compute degree or do it combinational
                            // Since we are in sequential block, let's use a sub-state or logic.
                            // Let's use the fact that n is small and do it inside this state with a counter.
                            // We'll use j_reg to sum up edges.
                            // Accessing adj_matrix[i_reg][j_reg] is combinational.
                            // We iterate j from 0 to n-1.
                            // Accumulate into temp_deg.
                            state <= 4'd20; // Sub-state for inner degree calc
                        end else begin
                            i_reg <= i_reg + 4'd1;
                        end
                    end else begin
                        // Done calculating all degrees
                        i_reg <= 4'd0; // Reset for next phase
                        state <= FIND_LEAVES;
                    end
                end

                4'd20: begin // Inner degree calc loop
                    if (j_reg < n) begin
                        if (adj_matrix[i_reg][j_reg] && active_mask[j_reg]) begin
                            temp_deg <= temp_deg + 4'd1;
                        end
                        j_reg <= j_reg + 4'd1;
                    end else begin
                        degree[i_reg] <= temp_deg;
                        i_reg <= i_reg + 4'd1;
                        state <= DEG_CALC;
                    end
                end

                FIND_LEAVES: begin
                    // Identify leaves (degree == 1) among active nodes
                    if (i_reg < n) begin
                        if (active_mask[i_reg] && degree[i_reg] == 4'd1) begin
                            leaf_mask[i_reg] <= 1'b1;
                        end else begin
                            leaf_mask[i_reg] <= 1'b0;
                        end
                        i_reg <= i_reg + 4'd1;
                    end else begin
                        // Check if any leaves found
                        // If no leaves, fail (unless active_count == 1 which is handled in final check)
                        if (leaf_mask == 16'b0) begin
                            state <= FAIL_S;
                        end else begin
                            i_reg <= 4'd0; // Reset to find parent
                            state <= FIND_PARENT;
                        end
                    end
                end

                FIND_PARENT: begin
                    // Find a node connected to all leaves in leaf_mask
                    // Iterate through active nodes
                    if (i_reg < n) begin
                        if (active_mask[i_reg]) begin
                            // Check if i_reg is connected to all leaves
                            j_reg <= 4'd0;
                            // Assume valid parent until proven otherwise
                            // We need a flag. Let's reuse temp_deg as a validity flag (1=valid, 0=invalid)
                            temp_deg <= 4'd1; // Assume valid
                            parent_idx_reg <= i_reg;
                            state <= 4'd30; // Check connections
                        end else begin
                            i_reg <= i_reg + 4'd1;
                        end
                    end else begin
                        // No parent found
                        state <= FAIL_S;
                    end
                end

                4'd30: begin // Verify parent connects to all leaves
                    if (j_reg < n) begin
                        if (leaf_mask[j_reg]) begin
                            // j is a leaf. Check connection to parent_idx_reg
                            if (!adj_matrix[parent_idx_reg][j_reg]) begin
                                temp_deg <= 4'd0; // Not a parent
                                // We can break early, but let's just finish the loop conceptually
                                // or jump to next parent candidate. 
                                // To save states, we can jump to next parent immediately.
                            end
                        end
                        j_reg <= j_reg + 4'd1;
                    end else begin
                        // Loop finished. Check validity.
                        if (temp_deg == 4'd1) begin
                            state <= CHECK_DEG;
                        end else begin
                            // Try next candidate
                            i_reg <= i_reg + 4'd1;
                            state <= FIND_PARENT;
                        end
                    end
                end

                CHECK_DEG: begin
                    // Check if parent degree >= 3
                    if (degree[parent_idx_reg] >= 4'd3) begin
                        state <= REMOVE;
                    end else begin
                        state <= FAIL_S;
                    end
                end

                REMOVE: begin
                    // Remove leaves: Update active_mask and active_count
                    if (i_reg < n) begin
                        if (leaf_mask[i_reg]) begin
                            active_mask[i_reg] <= 1'b0;
                            active_count <= active_count - 4'd1;
                        end
                        i_reg <= i_reg + 4'd1;
                    end else begin
                        state <= NEXT_ITER;
                    end
                end

                NEXT_ITER: begin
                    if (loop_counter == 4'd1) begin
                        // Last iteration done, check final state
                        state <= FINAL_CHECK;
                    end else begin
                        loop_counter <= loop_counter - 4'd1;
                        i_reg <= 4'd0; // Reset for next degree calc
                        leaf_mask <= 16'b0;
                        state <= DEG_CALC;
                    end
                end

                FINAL_CHECK: begin
                    // Exactly one node must remain
                    if (active_count == 4'd1) begin
                        state <= SUCCESS_S;
                    end else begin
                        state <= FAIL_S;
                    end
                end

                SUCCESS_S: begin
                    result <= 1'b1;
                    state <= DONE_S;
                end

                FAIL_S: begin
                    result <= 1'b0;
                    state <= DONE_S;
                end

                DONE_S: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule