module governor_convergence(
    input clk,
    input rst_n,
    input start,
    input [3:0] party_vector,
    input [5:0] edge_mask,
    output reg [3:0] months,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam FIND_COMPONENTS = 3'b001;
    localparam FLIP_COMPONENT = 3'b010;
    localparam CHECK_CONVERGENCE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg [3:0] current_parties, next_parties;
    reg [3:0] months_cnt, next_months_cnt;
    reg done_reg, next_done;
    reg [3:0] max_size_reg, next_max_size;
    reg [1:0] target_component_id, next_target_component_id;
    reg [1:0] flip_start_node, next_flip_start_node; // Seed for flood fill flip
    
    // Internal counters and registers for component analysis
    reg [1:0] node_idx;
    reg [1:0] bfs_head, bfs_tail;
    reg [1:0] bfs_queue [0:3];
    reg visited [0:3];
    reg [1:0] component_id [0:3]; // Stores which component index each node belongs to
    reg [3:0] component_size [0:4]; // Size of components 0-3 (max 4 nodes)
    reg [1:0] component_party [0:3]; // Party of each component
    reg [1:0] comp_count;
    
    // BFS flip registers
    reg flip_visited [0:3];
    reg [1:0] flip_bfs_head, flip_bfs_tail;
    reg [1:0] flip_bfs_queue [0:3];
    
    // Edge lookup helper function logic signals
    reg edge_exists;
    
    // Combinational Logic for Edge Existence between u and v
    // Edges: (0,1)=0, (0,2)=1, (0,3)=2, (1,2)=3, (1,3)=4, (2,3)=5
    always @(*) begin
        edge_exists = 0;
        // Sort u and v to map to mask bits
        if (node_idx < bfs_head) begin // node_idx is current node, bfs_head is neighbor
            // Swap logic handled by explicit case
        end
        
        // Standard mapping
        case ({node_idx, bfs_head})
            4'b0001, 4'b0100: edge_exists = edge_mask[0];
            4'b0010, 4'b1000: edge_exists = edge_mask[1];
            4'b0011, 4'b1100: edge_exists = edge_mask[2];
            4'b0110, 4'b1001: edge_exists = edge_mask[3];
            4'b0111, 4'b1101: edge_exists = edge_mask[4];
            4'b1011, 4'b1110: edge_exists = edge_mask[5];
            default: edge_exists = 0;
        endcase
    end

    // State Transition and Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_parties <= 4'b0;
            months_cnt <= 4'b0;
            done_reg <= 1'b0;
            max_size_reg <= 4'b0;
            target_component_id <= 2'b0;
            flip_start_node <= 2'b0;
        end else begin
            state <= next_state;
            current_parties <= next_parties;
            months_cnt <= next_months_cnt;
            done_reg <= next_done;
            max_size_reg <= next_max_size;
            target_component_id <= next_target_component_id;
            flip_start_node <= next_flip_start_node;
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        next_parties = current_parties;
        next_months_cnt = months_cnt;
        next_done = done_reg;
        next_max_size = max_size_reg;
        next_target_component_id = target_component_id;
        next_flip_start_node = flip_start_node;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FIND_COMPONENTS;
                    next_parties = party_vector;
                    next_months_cnt = 4'b0;
                    next_done = 1'b0;
                end
            end
            
            FIND_COMPONENTS: begin
                // This state handles the BFS loop via counters.
                // If analysis is done (comp_count settled and max found), move to FLIP.
                // Since we don't have an explicit "iteration done" flag here,
                // we assume the logic below (in sequential block for BFS) updates internal registers
                // and we transition based on a condition.
                // To keep it strictly 100 cycles, we will rely on a simple counter or manual step.
                // Let's use the node_idx counter to drive the process.
                // Wait for node_idx to complete 4 checks.
                if (node_idx == 3) begin
                   // Cycle 2: Wait for size calc (implicit in logic)
                   // Cycle 3: Transition
                   next_state = FLIP_COMPONENT;
                end
            end
            
            FLIP_COMPONENT: begin
                // Perform flip of target component
                // Use a counter or specific state to ensure flip completes
                // In the code below, we perform the flip update in the sequential block.
                // Let's move to CHECK after one cycle where the flip is committed.
                next_state = CHECK_CONVERGENCE;
                next_parties = current_parties; // Default, overridden below
                
                // Apply Flip Logic immediately (combinational update to next_parties)
                // We need to check which nodes are in target_component_id
                // We use a look-up from the previous FIND_COMPONENTS stage.
                // This requires storing component_id for each node.
                // We will implement a small wire logic for this in the flip block.
            end
            
            CHECK_CONVERGENCE: begin
                if (current_parties == 4'b0000 || current_parties == 4'b1111) begin
                    next_state = DONE;
                end else begin
                    next_state = FIND_COMPONENTS;
                    next_months_cnt = months_cnt + 1;
                end
            end
            
            DONE: begin
                next_done = 1'b1;
                if (!start) begin // Wait for start to go low to reset or stay here
                    next_state = IDLE;
                    next_done = 1'b0;
                end
            end
        endcase
    end

    // -------------------------------------------------------------
    // Internal Component Analysis Logic (BFS)
    // -------------------------------------------------------------
    // To keep state machine clean, we implement the BFS logic here.
    // Since we are sequential, we need registers for BFS queue and visited.
    // 
    // Strategy:
    // 1. Reset BFS registers (visited, sizes) when entering FIND_COMPONENTS.
    // 2. Iterate through nodes 0..3 to find unvisited ones.
    // 3. BFS to find component size and assign component IDs.
    // 4. Track the largest component.
    // 
    // Implementation detail: This requires precise state management.
    // Given the "100 cycle" limit and requirement for efficiency, we will
    // unroll the logic into explicit sequential steps within the state logic.
    // 
    // Let's use `node_idx` as the main iterator counter.
    // `node_idx` increments in FIND_COMPONENTS state.
    // 
    // We need a control signal to reset BFS internal state once per FIND_COMPONENTS entry.
    // 
    // Let's refine the FIND_COMPONENTS state to handle the scan.
    // We will implement the BFS "steps" in sequential logic that is active only during FIND_COMPONENTS.

    reg bfs_rst;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            node_idx <= 0;
            bfs_head <= 0;
            bfs_tail <= 0;
            comp_count <= 0;
            // Reset visited and component_size
            visited[0] <= 0; visited[1] <= 0; visited[2] <= 0; visited[3] <= 0;
            component_size[0] <= 0; component_size[1] <= 0; component_size[2] <= 0; component_size[3] <= 0;
        end else begin
            if (state == IDLE) begin
                node_idx <= 0;
                comp_count <= 0;
                max_size_reg <= 0;
            end else if (state == FIND_COMPONENTS) begin
                // BFS Logic for Current Node (node_idx)
                // 1. If visited[node_idx], skip (increment node_idx)
                // 2. If not visited, start BFS
                
                // We need a way to manage the BFS for a single component.
                // Since we are in a single state, we effectively run the BFS serially.
                // To do this in one cycle or few cycles, we can iterate.
                // Given the "1 cycle" latency requirement for the module, but "100 cycle" budget,
                // we can take multiple cycles per component.
                
                // Let's implement a small sub-step machine or use the cycle counter.
                // Actually, simpler: We do 1 BFS sweep per clock cycle in FIND_COMPONENTS.
                // But the request implies we just need to finish within 100 cycles.
                // Let's use `node_idx` as the controller for the outer loop.
                
                // Reset logic for a new component start:
                if (!visited[node_idx]) begin
                    // Start BFS for this node
                    // We will assume a single cycle BFS for small graph (4 nodes is tiny).
                    // Or multi-cycle if complexity grows. Here, 4 nodes, so logic can be combinational 
                    // but needs to stabilize. Let's do a single cycle processing for the *entire* component
                    // if possible, or break it down. 
                    // To be safe and deterministic:
                    // Cycle N: Identify component via combinational logic, register results.
                    // 
                    // Let's implement a "Finder" logic that calculates size of component starting at node_idx
                    // immediately and registers it.
                    // But we need to check connectivity. 
                    // 
                    // Let's stick to the requirement: "Simple BFS-like logic with registers".
                    
                    // We will use the combinational block below to calculate the component info for `node_idx`
                    // only if `visited[node_idx]` is 0.
                    // Then, in the sequential block, we mark those nodes as visited and update sizes.
                    
                    // Register updates for BFS
                    // Mark current node as visited and assign component ID
                    visited[node_idx] <= 1;
                    component_id[node_idx] <= comp_count;
                    
                    // Update size (start at 1)
                    component_size[comp_count] <= 1; // This will accumulate? 
                    // Accumulation in one cycle is hard for a pure graph. 
                    // However, 4 nodes is a fixed size. We can unroll the BFS.
                    // Let's unroll the BFS levels for component starting at node_idx.
                    // Level 0: node_idx. 
                    // Level 1: Neighbors of node_idx.
                    // Level 2: Neighbors of Level 1.
                    
                    // We will add logic in the sequential block to update sizes for *all* nodes in the component
                    // in one go, using combinational logic. This is efficient for small N.
                end else begin
                    node_idx <= node_idx + 1;
                end
                
                // Force transition out if we scanned all 4 nodes
                // The transition logic checks node_idx == 3.
            end else if (state == FLIP_COMPONENT) begin
                node_idx <= 0; // Reset for potential next iteration or done
            end
        end
    end

    // -------------------------------------------------------------
    // Combinational Finder Logic (The "Heavy Lifting")
    // -------------------------------------------------------------
    // This block calculates the component size for the current `node_idx` candidate.
    // It simulates BFS to find all reachable nodes from node_idx that share party.
    // It returns the size and list of nodes.
    // We update the SEQUENTIAL registers based on this result.
    
    reg [3:0] found_nodes;
    reg [1:0] found_size;
    
    // We need a way to find all nodes in the component starting at node_idx (if unvisited).
    // We will use a small combinational BFS-like expansion.
    // Since it's only 4 nodes, we can use a fixed-depth search.
    
    integer k;
    always @(*) begin
        found_nodes = 0;
        found_size = 0;
        
        if (!visited[node_idx]) begin
            // Start expansion from node_idx
            // Nodes in component: {node_idx}
            found_nodes[node_idx] = 1'b1;
            
            // Check neighbors of node_idx
            for (k = 0; k < 4; k = k + 1) begin
                if (k != node_idx && !found_nodes[k]) begin
                    // Check edge between node_idx and k
                    if (is_connected(node_idx, k[1:0]) && party_vector[k[1:0]] == party_vector[node_idx]) begin
                        found_nodes[k] = 1'b1;
                    end
                end
            end
            
            // Check neighbors of newly added nodes (Level 2)
            for (k = 0; k < 4; k = k + 1) begin
                if (found_nodes[k]) begin
                    integer m;
                    for (m = 0; m < 4; m = m + 1) begin
                        if (!found_nodes[m]) begin
                            if (is_connected(k[1:0], m[1:0]) && party_vector[m[1:0]] == party_vector[node_idx]) begin
                                found_nodes[m] = 1'b1;
                            end
                        end
                    end
                end
            end
            
            // Count size
            found_size = 0;
            for (k = 0; k < 4; k = k + 1) begin
                if (found_nodes[k]) found_size = found_size + 1;
            end
        end
    end
    
    // Helper function for edge check (combinational)
    function automatic bit is_connected(input [1:0] u, input [1:0] v);
        bit [1:0] min_n, max_n;
        begin
            min_n = (u < v) ? u : v;
            max_n = (u < v) ? v : u;
            is_connected = 0;
            case ({min_n, max_n})
                4'b0001: is_connected = edge_mask[0];
                4'b0010: is_connected = edge_mask[1];
                4'b0011: is_connected = edge_mask[2];
                4'b0110: is_connected = edge_mask[3];
                4'b0111: is_connected = edge_mask[4];
                4'b1011: is_connected = edge_mask[5];
            endcase
        end
    endfunction

    // -------------------------------------------------------------
    // State Specific Actions in Sequential Block
    // -------------------------------------------------------------
    // We need to capture the result of the combinational finder logic
    // and apply it to the registers.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == FIND_COMPONENTS && !visited[node_idx]) begin
                // Register the discovered component
                // Mark visited all found_nodes
                // This needs to loop in hardware or be unrolled
                // Since we can't easily loop in procedural code inside always block without combinational loop risks,
                // we rely on the fact that `found_nodes` is computed combinationally.
                
                // Update visited flags for all nodes in component
                if (found_nodes[0]) visited[0] <= 1'b1;
                if (found_nodes[1]) visited[1] <= 1'b1;
                if (found_nodes[2]) visited[2] <= 1'b1;
                if (found_nodes[3]) visited[3] <= 1'b1;
                
                // Assign component IDs
                if (found_nodes[0]) component_id[0] <= comp_count;
                if (found_nodes[1]) component_id[1] <= comp_count;
                if (found_nodes[2]) component_id[2] <= comp_count;
                if (found_nodes[3]) component_id[3] <= comp_count;
                
                // Store size
                component_size[comp_count] <= found_size;
                component_party[comp_count] <= party_vector[node_idx];
                
                // Check if this is the largest so far
                if (found_size > max_size_reg) begin
                    max_size_reg <= found_size;
                    next_target_component_id = comp_count; // Target this component for flipping
                end
                
                // Increment component count
                comp_count <= comp_count + 1;
                
                // Advance node_idx to skip these nodes (actually we just increment by 1, visited check handles it)
                node_idx <= node_idx + 1;
            end else if (state == FIND_COMPONENTS && visited[node_idx]) begin
                node_idx <= node_idx + 1;
            end
            
            // Flip Action
            if (state == FLIP_COMPONENT) begin
                // Flip the party of all nodes belonging to target_component_id
                // Invert the bit: 0->1, 1->0
                // We use current_parties to modify
                
                if (component_id[0] == target_component_id) begin
                    next_parties[0] = ~current_parties[0];
                end
                if (component_id[1] == target_component_id) begin
                    next_parties[1] = ~current_parties[1];
                end
                if (component_id[2] == target_component_id) begin
                    next_parties[2] = ~current_parties[2];
                end
                if (component_id[3] == target_component_id) begin
                    next_parties[3] = ~current_parties[3];
                end
                
                // Explicit assignment to sequential reg
                current_parties <= next_parties; 
            end
        end
    end

    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            months <= 0;
            done <= 0;
        end else begin
            months <= months_cnt;
            done <= done_reg;
        end
    end

endmodule