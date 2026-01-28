module global_warming_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire edge_valid,
    input wire [7:0] p,
    input wire [7:0] q,
    input wire [19:0] cost,
    input wire edge_done,
    output reg [23:0] result,
    output reg impossible,
    output reg done
);
    // State encoding
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COLLECT = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE = 2'd3;
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] visited_nodes;
    reg [19:0] cost_matrix [0:7][0:7];
    reg [7:0] components [0:7];
    reg [3:0] comp_count;
    reg [23:0] dp [0:255];
    reg [23:0] total_cost;
    reg [7:0] current_component;
    reg [3:0] comp_size;
    reg [3:0] node_count;
    reg [2:0] node_list [0:7];
    reg [7:0] global_visited;
    reg [7:0] bfs_visited;
    reg [2:0] queue [0:7];
    reg [2:0] queue_head;
    reg [2:0] queue_tail;
    reg [2:0] current_node;
    reg [3:0] comp_index;
    reg [23:0] dp_mask;
    reg [23:0] dp_min;
    reg [2:0] i;
    reg [2:0] j;
    reg [7:0] temp_mask;
    reg [23:0] cycle_counter;
    
    // Local parameters
    localparam [23:0] INF = 24'd16_777_215;
    localparam [23:0] MAX_CYCLES = 24'd1000;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            impossible <= 1'b0;
            done <= 1'b0;
            visited_nodes <= 8'd0;
            comp_count <= 4'd0;
            total_cost <= 24'd0;
            global_visited <= 8'd0;
            current_component <= 8'd0;
            bfs_visited <= 8'd0;
            queue_head <= 3'd0;
            queue_tail <= 3'd0;
            comp_index <= 4'd0;
            dp_mask <= 24'd0;
            dp_min <= 24'd0;
            i <= 3'd0;
            j <= 3'd0;
            comp_size <= 4'd0;
            node_count <= 4'd0;
            current_node <= 3'd0;
            cycle_counter <= 24'd0;
            // Clear cost_matrix
            for (integer k = 0; k < 8; k = k + 1) begin
                for (integer l = 0; l < 8; l = l + 1) begin
                    cost_matrix[k][l] <= 20'd0;
                end
            end
            // Clear dp table
            for (integer m = 0; m < 256; m = m + 1) begin
                dp[m] <= 24'd0;
            end
            // Clear components
            for (integer n = 0; n < 8; n = n + 1) begin
                components[n] <= 8'd0;
                node_list[n] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COLLECT;
                        visited_nodes <= 8'd0;
                        // Clear cost_matrix
                        for (integer k = 0; k < 8; k = k + 1) begin
                            for (integer l = 0; l < 8; l = l + 1) begin
                                cost_matrix[k][l] <= 20'd0;
                            end
                        end
                    end
                end
                
                COLLECT: begin
                    if (edge_valid) begin
                        // Store edge if valid IDs (1-8) and not same
                        if ((p >= 8'd1) && (p <= 8'd8) && 
                            (q >= 8'd1) && (q <= 8'd8) && 
                            (p != q)) begin
                            cost_matrix[p-1][q-1] <= cost;
                            cost_matrix[q-1][p-1] <= cost;
                            visited_nodes <= visited_nodes | (1 << (p-1)) | (1 << (q-1));
                        end
                    end
                    if (edge_done) begin
                        state <= COMPUTE;
                        global_visited <= 8'd0;
                        comp_count <= 4'd0;
                        comp_index <= 4'd0;
                        total_cost <= 24'd0;
                        impossible <= 1'b0;
                        cycle_counter <= 24'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 24'd1;
                    
                    // Component detection: find next unvisited node
                    if (comp_count == 4'd0) begin
                        // Find first unvisited node
                        temp_mask <= visited_nodes & ~global_visited;
                        // Use j as temp variable to find first bit
                        if ((visited_nodes & ~global_visited) != 8'd0) begin
                            // Found a node to start BFS
                            for (j = 3'd0; j < 3'd8; j = j + 3'd1) begin
                                if (temp_mask[j]) begin
                                    current_node <= j;
                                    global_visited <= global_visited | (1 << j);
                                    current_component <= (1 << j);
                                    bfs_visited <= (1 << j);
                                    queue[0] <= j;
                                    queue_head <= 3'd0;
                                    queue_tail <= 3'd1;
                                    // Start BFS in next cycle
                                    comp_size <= 4'd1; // Count current node
                                    break;
                                end
                            end
                        end else begin
                            // All nodes visited, components done
                            comp_count <= comp_count + 4'd1;
                        end
                    end else if (comp_count < 4'd9) begin
                        // BFS phase for current component
                        if (queue_head < queue_tail) begin
                            // Process queue
                            current_node <= queue[queue_head];
                            queue_head <= queue_head + 3'd1;
                            // Check all neighbors in next cycle
                        end else begin
                            // BFS complete, store component
                            components[comp_count - 4'd1] <= current_component;
                            // Find next unvisited node
                            temp_mask <= visited_nodes & ~global_visited;
                            if ((visited_nodes & ~global_visited) != 8'd0) begin
                                for (j = 3'd0; j < 3'd8; j = j + 3'd1) begin
                                    if (temp_mask[j]) begin
                                        current_node <= j;
                                        global_visited <= global_visited | (1 << j);
                                        current_component <= (1 << j);
                                        bfs_visited <= (1 << j);
                                        queue[0] <= j;
                                        queue_head <= 3'd0;
                                        queue_tail <= 3'd1;
                                        comp_size <= 4'd1;
                                        comp_count <= comp_count + 4'd1;
                                        break;
                                    end
                                end
                            end else begin
                                // All nodes processed
                                comp_index <= 4'd0;
                                comp_count <= comp_count + 4'd1;
                            end
                        end
                    end else if (comp_count < 4'd10) begin
                        // BFS neighbor expansion
                        // Check all neighbors of current_node
                        if (queue_head <= queue_tail) begin
                            // Expand neighbors for current node
                            for (j = 3'd0; j < 3'd8; j = j + 3'd1) begin
                                if (visited_nodes[j] && !bfs_visited[j] && 
                                    cost_matrix[current_node][j] != 20'd0) begin
                                    bfs_visited <= bfs_visited | (1 << j);
                                    current_component <= current_component | (1 << j);
                                    queue[queue_tail] <= j;
                                    queue_tail <= queue_tail + 3'd1;
                                    comp_size <= comp_size + 4'd1;
                                end
                            end
                        end
                        comp_count <= comp_count + 4'd1;
                    end else if (comp_index < (comp_count - 4'd1)) begin
                        // Process components
                        // Extract current component
                        comp_mask <= components[comp_index];
                        // Count size and extract nodes
                        node_count <= 4'd0;
                        for (j = 3'd0; j < 3'd8; j = j + 3'd1) begin
                            if (components[comp_index][j]) begin
                                node_list[node_count] <= j;
                                node_count <= node_count + 4'd1;
                            end
                        end
                        comp_size <= node_count;
                        
                        // Check even size
                        if (node_count[0]) begin // Odd
                            impossible <= 1'b1;
                            state <= DONE;
                        end else begin
                            // Initialize DP for this component
                            for (i = 3'd0; i < 3'd8; i = i + 3'd1) begin
                                for (j = 3'd0; j < 3'd8; j = j + 3'd1) begin
                                    dp[(i * 8'd8) + j] <= INF;
                                end
                            end
                            dp[0] <= 24'd0;
                            dp_mask <= 24'd0;
                            // Reset DP loop variables
                            i <= 3'd0;
                            j <= 3'd1;
                            comp_count <= comp_count + 4'd1; // Mark DP start
                        end
                    end else if (comp_count < 4'd20) begin
                        // DP computation phase
                        // Iterate through masks
                        if (dp_mask < (1 << comp_size)) begin
                            if (dp[dp_mask] < INF) begin
                                // Find first unmatched node
                                if (i < comp_size) begin
                                    if (!dp_mask[i]) begin
                                        if (j < comp_size) begin
                                            if (!dp_mask[j] && (j != i)) begin
                                                // Compute new mask and cost
                                                temp_mask <= dp_mask | (1 << i) | (1 << j);
                                                // Update dp in next cycle
                                                if (dp[dp_mask] + cost_matrix[node_list[i]][node_list[j]] < 
                                                    dp[dp_mask | (1 << i) | (1 << j)]) begin
                                                    dp[dp_mask | (1 << i) | (1 << j)] <= 
                                                        dp[dp_mask] + cost_matrix[node_list[i]][node_list[j]];
                                                end
                                            end
                                            j <= j + 3'd1;
                                        end else begin
                                            j <= 3'd0;
                                            i <= i + 3'd1;
                                        end
                                    end else begin
                                        i <= i + 3'd1;
                                    end
                                end else begin
                                    // Move to next mask
                                    dp_mask <= dp_mask + 24'd1;
                                    i <= 3'd0;
                                    j <= 3'd1;
                                end
                            end else begin
                                dp_mask <= dp_mask + 24'd1;
                            end
                        end else begin
                            // Add component cost to total
                            total_cost <= total_cost + dp[(1 << comp_size) - 1];
                            comp_index <= comp_index + 4'd1;
                            comp_count <= 4'd10; // Back to processing phase
                        end
                    end else begin
                        // Check if all components processed
                        if (comp_index >= (comp_count - 4'd1)) begin
                            state <= DONE;
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!impossible) begin
                        result <= total_cost;
                    end
                    // Wait for next start
                    if (start) begin
                        state <= COLLECT;
                        done <= 1'b0;
                        // Clear for next computation
                        visited_nodes <= 8'd0;
                        comp_count <= 4'd0;
                        total_cost <= 24'd0;
                        impossible <= 1'b0;
                        cycle_counter <= 24'd0;
                        // Clear cost_matrix
                        for (integer k = 0; k < 8; k = k + 1) begin
                            for (integer l = 0; l < 8; l = l + 1) begin
                                cost_matrix[k][l] <= 20'd0;
                            end
                        end
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule