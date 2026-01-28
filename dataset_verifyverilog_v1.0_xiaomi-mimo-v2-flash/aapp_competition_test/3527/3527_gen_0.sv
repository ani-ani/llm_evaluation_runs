module NetworkDiameter(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_computers,
    input [3:0] num_cables,
    input [31:0] cable_a,
    input [31:0] cable_b,
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] BUILD_MATRIX = 4'd2;
    localparam [3:0] FIND_COMPONENTS = 4'd3;
    localparam [3:0] CALC_DIAMETERS = 4'd4;
    localparam [3:0] CALC_RESULT = 4'd5;
    localparam [3:0] FINISH = 4'd6;

    reg [3:0] state, next_state;
    
    // Configuration registers
    reg [3:0] num_computers_reg;
    reg [3:0] num_cables_reg;
    reg [31:0] cable_a_reg;
    reg [31:0] cable_b_reg;
    
    // Adjacency matrix (16x16 = 256 bits) - packed as 8x32-bit rows
    reg [31:0] adj_matrix [0:7];  // 8 rows of 32 bits
    
    // Component tracking
    reg [3:0] component_id [0:15];  // Component ID for each node
    reg [3:0] num_components;
    reg [3:0] component_nodes [0:15];  // Nodes in current component
    reg [3:0] component_node_count;
    reg [3:0] comp_diameter [0:15];  // Diameter for each component
    reg [3:0] comp_center [0:15];    // Center node for each component
    
    // BFS state
    reg [3:0] bfs_start_node;
    reg [3:0] bfs_current_node;
    reg [3:0] bfs_distance [0:15];
    reg [3:0] bfs_visited [0:15];
    reg [3:0] bfs_queue [0:15];
    reg [3:0] bfs_head;
    reg [3:0] bfs_tail;
    reg [3:0] bfs_max_dist;
    
    // BFS iteration control
    reg [3:0] bfs_iter_node;
    reg [3:0] bfs_iter_comp;
    reg [3:0] bfs_comp_start;
    reg [3:0] bfs_comp_end;
    
    // Diameter calculation
    reg [3:0] diam_max;
    reg [3:0] center_node;
    reg [3:0] center_min_max_dist;
    reg [3:0] temp_max_dist;
    
    // Result calculation
    reg [3:0] max_component_diameter;
    reg [3:0] component_count;
    reg [7:0] star_diameter;
    reg [7:0] final_result;
    
    // Loop counters
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    
    // Cycle counter for timeout prevention
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            num_computers_reg <= 4'd0;
            num_cables_reg <= 4'd0;
            cable_a_reg <= 32'd0;
            cable_b_reg <= 32'd0;
            num_components <= 4'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                adj_matrix[i] <= 32'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                component_id[i] <= 4'd0;
                comp_diameter[i] <= 4'd0;
                comp_center[i] <= 4'd0;
                bfs_distance[i] <= 4'd0;
                bfs_visited[i] <= 4'd0;
                bfs_queue[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        busy <= 1'b1;
                        num_computers_reg <= num_computers;
                        num_cables_reg <= num_cables;
                        cable_a_reg <= cable_a;
                        cable_b_reg <= cable_b;
                        // Initialize matrix
                        for (i = 0; i < 8; i = i + 1) begin
                            adj_matrix[i] <= 32'd0;
                        end
                        num_components <= 4'd0;
                        // Initialize component tracking
                        for (i = 0; i < 16; i = i + 1) begin
                            component_id[i] <= 4'd15;  // Invalid initial value
                            comp_diameter[i] <= 4'd0;
                            comp_center[i] <= 4'd0;
                        end
                    end
                end
                
                BUILD_MATRIX: begin
                    // Build adjacency matrix from cable list
                    if (cycle_count < num_cables_reg) begin
                        // Extract node pair from packed input
                        // Each cable is 4 bits for A and 4 bits for B
                        // cable_a[3:0], cable_a[7:4], cable_a[11:8], ...
                        // cable_b similar
                        
                        // Use bit slicing to access each 4-bit field
                        begin : build_loop
                            reg [3:0] node_a;
                            reg [3:0] node_b;
                            reg [31:0] row_a;
                            reg [31:0] row_b;
                            
                            // Extract based on cycle_count
                            if (cycle_count == 4'd0) begin
                                node_a = cable_a_reg[3:0];
                                node_b = cable_b_reg[3:0];
                            end else if (cycle_count == 4'd1) begin
                                node_a = cable_a_reg[7:4];
                                node_b = cable_b_reg[7:4];
                            end else if (cycle_count == 4'd2) begin
                                node_a = cable_a_reg[11:8];
                                node_b = cable_b_reg[11:8];
                            end else if (cycle_count == 4'd3) begin
                                node_a = cable_a_reg[15:12];
                                node_b = cable_b_reg[15:12];
                            end else if (cycle_count == 4'd4) begin
                                node_a = cable_a_reg[19:16];
                                node_b = cable_b_reg[19:16];
                            end else if (cycle_count == 4'd5) begin
                                node_a = cable_a_reg[23:20];
                                node_b = cable_b_reg[23:20];
                            end else if (cycle_count == 4'd6) begin
                                node_a = cable_a_reg[27:24];
                                node_b = cable_b_reg[27:24];
                            end else begin
                                node_a = cable_a_reg[31:28];
                                node_b = cable_b_reg[31:28];
                            end
                            
                            // Set matrix entries (if valid nodes)
                            if (node_a < num_computers_reg && node_b < num_computers_reg) begin
                                // Set bit in row node_a, column node_b
                                if (node_a < 4'd8) begin
                                    row_a = adj_matrix[node_a];
                                    row_a[node_b] = 1'b1;
                                    adj_matrix[node_a] <= row_a;
                                end else begin
                                    row_a = adj_matrix[node_a - 4'd8];
                                    row_a[node_b] = 1'b1;
                                    adj_matrix[node_a - 4'd8] <= row_a;
                                end
                                // Set bit in row node_b, column node_a
                                if (node_b < 4'd8) begin
                                    row_b = adj_matrix[node_b];
                                    row_b[node_a] = 1'b1;
                                    adj_matrix[node_b] <= row_b;
                                end else begin
                                    row_b = adj_matrix[node_b - 4'd8];
                                    row_b[node_a] = 1'b1;
                                    adj_matrix[node_b - 4'd8] <= row_b;
                                end
                            end
                        end
                        cycle_count <= cycle_count + 8'd1;
                    end
                end
                
                FIND_COMPONENTS: begin
                    // Find connected components using BFS
                    // Start with first unassigned node
                    if (num_components < num_computers_reg) begin
                        // Find next unassigned node
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < num_computers_reg && component_id[i] == 4'd15) begin
                                // Start BFS from this node
                                bfs_comp_start <= i;
                                // Mark all BFS nodes as unvisited
                                for (j = 0; j < 16; j = j + 1) begin
                                    bfs_visited[j] <= 4'd0;
                                    bfs_distance[j] <= 4'd15;
                                end
                                bfs_head <= 4'd0;
                                bfs_tail <= 4'd0;
                                bfs_queue[0] <= i;
                                bfs_distance[i] <= 4'd0;
                                bfs_visited[i] <= 1'b1;
                                component_node_count <= 4'd0;
                                // Continue to BFS execution
                                break;
                            end
                        end
                        num_components <= num_components + 4'd1;
                    end
                end
                
                CALC_DIAMETERS: begin
                    // Calculate diameter for each component
                    // Track max component diameter for final result
                    // Also find center node for each component
                    
                    if (bfs_iter_comp < num_components) begin
                        // Start BFS from each node in this component
                        // Track max distance from each node
                        
                        if (bfs_iter_node < num_computers_reg) begin
                            // Check if this node belongs to current component
                            if (component_id[bfs_iter_node] == bfs_iter_comp) begin
                                // Run BFS from this node
                                // Initialize BFS
                                for (k = 0; k < 16; k = k + 1) begin
                                    bfs_visited[k] <= 4'd0;
                                    bfs_distance[k] <= 4'd15;
                                end
                                bfs_head <= 4'd0;
                                bfs_tail <= 4'd1;
                                bfs_queue[0] <= bfs_iter_node;
                                bfs_visited[bfs_iter_node] <= 1'b1;
                                bfs_distance[bfs_iter_node] <= 4'd0;
                                bfs_max_dist <= 4'd0;
                                bfs_current_node <= bfs_iter_node;
                                // Use temp_max_dist to track max distance
                                temp_max_dist <= 4'd0;
                                // Will continue to BFS execution in next cycle
                            end
                            bfs_iter_node <= bfs_iter_node + 4'd1;
                        end else begin
                            // Move to next component
                            bfs_iter_node <= 4'd0;
                            bfs_iter_comp <= bfs_iter_comp + 4'd1;
                        end
                    end else if (bfs_iter_comp == num_components) begin
                        // All components processed
                        // Find max component diameter
                        max_component_diameter <= 4'd0;
                        component_count <= num_components;
                    end
                end
                
                CALC_RESULT: begin
                    // Calculate final result
                    // result = max(max_component_diameter, ceil(log2(num_components)) + 1)
                    // For star topology: distance between components = 1 + ceil(log2(num_components))
                    // But actually, in star topology with k components:
                    // Each component center connects to hub, so path between any two components
                    // passes through hub: distance = 1 + 1 = 2
                    // But we need to consider the max within component too
                    // Final diameter = max(component_diameter, 2) for 2+ components
                    // For 1 component: just component_diameter
                    // For 2+ components: max(component_diameter, 2)
                    // Actually, if we connect all centers to a new hub (not existing node):
                    // Path between nodes in different components: 1 (to hub) + 1 (from hub) = 2
                    // So final diameter = max(component_diameter, 2)
                    // But we can't add a new node, we connect centers to each other
                    // Star topology: one center as hub, others connect to it
                    // Path between nodes in different components: 1 (to hub) + 1 (from hub) = 2
                    // Or if they're both not hubs: 1 (to hub) + 1 (to other) = 2
                    // So yes, diameter = max(component_diameter, 2)
                    // But need to account for single component case
                    
                    if (component_count > 4'd1) begin
                        // More than one component: star adds diameter of 2
                        if (max_component_diameter < 4'd2) begin
                            final_result <= 8'd2;
                        end else begin
                            final_result <= {4'd0, max_component_diameter};
                        end
                    end else begin
                        // Single component: no added cables
                        final_result <= {4'd0, max_component_diameter};
                    end
                end
                
                FINISH: begin
                    result <= final_result;
                    done <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
            
            // Increment cycle counter (except in IDLE when not busy)
            if (state != IDLE || start) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                // Single cycle to load configuration
                next_state = BUILD_MATRIX;
            end
            
            BUILD_MATRIX: begin
                if (cycle_count >= num_cables_reg) begin
                    next_state = FIND_COMPONENTS;
                end
            end
            
            FIND_COMPONENTS: begin
                // Check if all nodes assigned to components
                // If BFS for current component is done, start next
                if (num_components >= num_computers_reg) begin
                    // All components found (each node is its own component)
                    // Or we need better component detection
                    // Actually, after BFS from first unassigned node, mark all reachable
                    // Continue until all nodes have component_id != 15
                    reg all_assigned;
                    all_assigned = 1'b1;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < num_computers_reg && component_id[i] == 4'd15) begin
                            all_assigned = 1'b0;
                        end
                    end
                    if (all_assigned) begin
                        next_state = CALC_DIAMETERS;
                    end
                end
            end
            
            CALC_DIAMETERS: begin
                // Wait for diameter calculations
                // After all BFS iterations complete
                if (bfs_iter_comp == num_components && bfs_iter_node >= num_computers_reg) begin
                    next_state = CALC_RESULT;
                end
            end
            
            CALC_RESULT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Timeout protection
        if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
        end
    end

    // BFS execution logic (separate combinational block)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            // BFS execution in FIND_COMPONENTS state
            if (state == FIND_COMPONENTS && num_components < num_computers_reg) begin
                // Continue BFS for current component
                if (bfs_head < bfs_tail) begin
                    // Dequeue
                    reg [3:0] current;
                    current = bfs_queue[bfs_head];
                    bfs_head <= bfs_head + 4'd1;
                    
                    // Add to component
                    if (component_node_count < 4'd16) begin
                        component_nodes[component_node_count] <= current;
                        component_node_count <= component_node_count + 4'd1;
                        component_id[current] <= num_components;
                    end
                    
                    // Enqueue neighbors
                    for (i = 0; i < num_computers_reg; i = i + 1) begin
                        // Check if neighbor and not visited
                        begin : neighbor_check
                            reg [31:0] row;
                            reg neighbor_bit;
                            if (current < 4'd8) begin
                                row = adj_matrix[current];
                            end else begin
                                row = adj_matrix[current - 4'd8];
                            end
                            neighbor_bit = row[i];
                            
                            if (neighbor_bit && !bfs_visited[i]) begin
                                bfs_visited[i] <= 1'b1;
                                bfs_distance[i] <= bfs_distance[current] + 4'd1;
                                bfs_queue[bfs_tail] <= i;
                                bfs_tail <= bfs_tail + 4'd1;
                            end
                        end
                    end
                end else if (bfs_tail > 4'd0) begin
                    // BFS complete for this component
                    // Now need to find next unassigned node
                    // This is handled by resetting bfs_head/bfs_tail and finding next unassigned
                    // For simplicity, we'll mark this and find next in main state machine
                    // Actually, we need to clear component_node_count and find next unassigned
                    
                    // Find next unassigned node for next component
                    reg found_next;
                    found_next = 1'b0;
                    for (i = 0; i < num_computers_reg; i = i + 1) begin
                        if (component_id[i] == 4'd15 && !found_next) begin
                            // Start BFS from this node
                            bfs_comp_start <= i;
                            for (j = 0; j < 16; j = j + 1) begin
                                bfs_visited[j] <= 4'd0;
                                bfs_distance[j] <= 4'd15;
                            end
                            bfs_head <= 4'd0;
                            bfs_tail <= 4'd1;
                            bfs_queue[0] <= i;
                            bfs_distance[i] <= 4'd0;
                            bfs_visited[i] <= 1'b1;
                            component_node_count <= 4'd0;
                            found_next = 1'b1;
                        end
                    end
                    if (!found_next) begin
                        // All nodes assigned
                        // Mark for state transition
                    end
                end
            end
            
            // BFS for diameter calculation
            if (state == CALC_DIAMETERS) begin
                if (bfs_iter_comp < num_components) begin
                    // Check if we need to start BFS from this node
                    if (component_id[bfs_iter_node] == bfs_iter_comp) begin
                        // Check if BFS already running for this node
                        if (bfs_head < bfs_tail) begin
                            // Continue BFS
                            reg [3:0] current;
                            current = bfs_queue[bfs_head];
                            bfs_head <= bfs_head + 4'd1;
                            
                            // Update max distance
                            if (bfs_distance[current] > bfs_max_dist) begin
                                bfs_max_dist <= bfs_distance[current];
                            end
                            
                            // Enqueue neighbors
                            for (i = 0; i < num_computers_reg; i = i + 1) begin
                                begin : neighbor_check_diam
                                    reg [31:0] row;
                                    reg neighbor_bit;
                                    if (current < 4'd8) begin
                                        row = adj_matrix[current];
                                    end else begin
                                        row = adj_matrix[current - 4'd8];
                                    end
                                    neighbor_bit = row[i];
                                    
                                    if (neighbor_bit && !bfs_visited[i]) begin
                                        bfs_visited[i] <= 1'b1;
                                        bfs_distance[i] <= bfs_distance[current] + 4'd1;
                                        bfs_queue[bfs_tail] <= i;
                                        bfs_tail <= bfs_tail + 4'd1;
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    // Combinational logic for diameter and center calculation
    always @(*) begin
        // This block runs continuously to compute intermediate values
        // It sets the max_component_diameter and other values
        
        if (state == CALC_DIAMETERS) begin
            // Check if BFS from a node is complete
            if (bfs_head >= bfs_tail && bfs_tail > 4'd0) begin
                // BFS complete for this node
                // Update component diameter if this is the maximum
                if (bfs_max_dist > comp_diameter[bfs_iter_comp]) begin
                    comp_diameter[bfs_iter_comp] = bfs_max_dist;
                end
                
                // Check if we need to update center
                // For now, just track max diameter per component
                // We'll handle center selection separately
            end
            
            // Update max component diameter
            if (bfs_iter_comp == num_components) begin
                max_component_diameter = 4'd0;
                for (i = 0; i < num_components; i = i + 1) begin
                    if (comp_diameter[i] > max_component_diameter) begin
                        max_component_diameter = comp_diameter[i];
                    end
                end
            end
        end
    end

endmodule