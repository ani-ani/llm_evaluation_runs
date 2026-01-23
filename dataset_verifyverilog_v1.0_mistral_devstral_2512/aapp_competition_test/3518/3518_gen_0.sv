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
    
    // Registers
    reg [1:0] state;
    reg [19:0] cost_matrix [0:7][0:7];
    reg [7:0] visited_nodes;
    reg [7:0] components [0:7];
    reg [3:0] comp_count;
    reg [23:0] dp [0:255];
    
    // BFS registers
    reg [7:0] global_visited;
    reg [2:0] current_node;
    reg [7:0] current_component;
    reg [7:0] bfs_visited;
    reg [2:0] queue [0:7];
    reg [2:0] queue_head;
    reg [2:0] queue_tail;
    reg [3:0] comp_index;
    reg [23:0] total_cost;
    reg [2:0] i_reg, j_reg;
    reg [7:0] comp_mask;
    reg [3:0] comp_size;
    reg [2:0] node_list [0:7];
    reg [3:0] node_count;
    reg [23:0] dp_mask;
    reg [23:0] dp_min;
    reg [2:0] u_reg;
    reg [2:0] v_reg;
    reg [23:0] new_mask;
    reg [23:0] new_cost;
    reg [23:0] temp_cost;
    reg [3:0] cycle_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 24'd0;
            impossible <= 1'b0;
            done <= 1'b0;
            visited_nodes <= 8'd0;
            comp_count <= 4'd0;
            global_visited <= 8'd0;
            current_component <= 8'd0;
            bfs_visited <= 8'd0;
            queue_head <= 3'd0;
            queue_tail <= 3'd0;
            comp_index <= 4'd0;
            total_cost <= 24'd0;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            comp_mask <= 8'd0;
            comp_size <= 4'd0;
            node_count <= 4'd0;
            dp_mask <= 24'd0;
            dp_min <= 24'd0;
            u_reg <= 3'd0;
            v_reg <= 3'd0;
            new_mask <= 24'd0;
            new_cost <= 24'd0;
            temp_cost <= 24'd0;
            cycle_count <= 4'd0;
            
            // Clear cost matrix
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    cost_matrix[i][j] <= 20'd0;
                end
            end
            
            // Clear DP table
            integer m;
            for (m = 0; m < 256; m = m + 1) begin
                dp[m] <= 24'd0;
            end
            
            // Clear components
            for (i = 0; i < 8; i = i + 1) begin
                components[i] <= 8'd0;
            end
            
            // Clear node list
            for (i = 0; i < 8; i = i + 1) begin
                node_list[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COLLECT;
                        visited_nodes <= 8'd0;
                        comp_count <= 4'd0;
                        // Clear cost matrix
                        integer i, j;
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                cost_matrix[i][j] <= 20'd0;
                            end
                        end
                    end
                end
                
                COLLECT: begin
                    if (edge_valid) begin
                        // Store edge (convert to 0-based)
                        if (p >= 1 && p <= 8 && q >= 1 && q <= 8 && p != q) begin
                            cost_matrix[p-1][q-1] <= cost;
                            cost_matrix[q-1][p-1] <= cost;
                            visited_nodes <= visited_nodes | (1 << (p-1)) | (1 << (q-1));
                        end
                    end
                    if (edge_done) begin
                        state <= COMPUTE;
                        // Initialize for component detection
                        global_visited <= 8'd0;
                        comp_count <= 4'd0;
                        comp_index <= 4'd0;
                        total_cost <= 24'd0;
                        impossible <= 1'b0;
                        cycle_count <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (cycle_count > 1000) begin
                        state <= DONE;
                        impossible <= 1'b1;
                    end else if (comp_count == 0 || comp_index < comp_count) begin
                        // Find next unvisited node
                        if (global_visited != visited_nodes) begin
                            integer n;
                            for (n = 0; n < 8; n = n + 1) begin
                                if (!global_visited[n] && visited_nodes[n]) begin
                                    current_node <= n;
                                    global_visited <= global_visited | (1 << n);
                                    current_component <= (1 << n);
                                    bfs_visited <= (1 << n);
                                    queue[0] <= n;
                                    queue_head <= 3'd0;
                                    queue_tail <= 3'd1;
                                    
                                    // BFS loop
                                    if (queue_head < queue_tail) begin
                                        u_reg <= queue[queue_head];
                                        queue_head <= queue_head + 3'd1;
                                        
                                        // Check all neighbors
                                        integer v;
                                        for (v = 0; v < 8; v = v + 1) begin
                                            if (visited_nodes[v] && !bfs_visited[v] && cost_matrix[u_reg][v] != 0) begin
                                                bfs_visited <= bfs_visited | (1 << v);
                                                current_component <= current_component | (1 << v);
                                                queue[queue_tail] <= v;
                                                queue_tail <= queue_tail + 3'd1;
                                            end
                                        end
                                    end
                                    
                                    // BFS complete for this component
                                    components[comp_count] <= current_component;
                                    comp_count <= comp_count + 4'd1;
                                end
                            end
                        end else begin
                            // All nodes processed, check components
                            comp_index <= 4'd0;
                        end
                    end else if (comp_index < comp_count) begin
                        // Process component at comp_index
                        comp_mask <= components[comp_index];
                        
                        // Count size and extract nodes
                        comp_size <= 0;
                        node_count <= 0;
                        integer n;
                        for (n = 0; n < 8; n = n + 1) begin
                            if (comp_mask[n]) begin
                                comp_size <= comp_size + 4'd1;
                                node_list[node_count] <= n;
                                node_count <= node_count + 4'd1;
                            end
                        end
                        
                        // Check if even size
                        if (comp_size[0]) begin // Odd size
                            impossible <= 1'b1;
                            state <= DONE;
                        end else begin
                            // Initialize DP
                            integer m;
                            for (m = 0; m < 256; m = m + 1) begin
                                dp[m] <= 24'd10000000; // INF
                            end
                            dp[0] <= 24'd0;
                            dp_mask <= 24'd0;
                            
                            // Start DP
                            for (dp_mask = 0; dp_mask < (1 << comp_size); dp_mask = dp_mask + 24'd1) begin
                                if (dp[dp_mask] < 24'd10000000) begin
                                    // Find first unmatched node
                                    integer i;
                                    for (i = 0; i < comp_size; i = i + 1) begin
                                        if (!dp_mask[i]) begin
                                            integer j;
                                            for (j = i + 1; j < comp_size; j = j + 1) begin
                                                if (!dp_mask[j]) begin
                                                    new_mask = dp_mask | (1 << i) | (1 << j);
                                                    new_cost = dp[dp_mask] + cost_matrix[node_list[i]][node_list[j]];
                                                    if (new_cost < dp[new_mask]) begin
                                                        dp[new_mask] <= new_cost;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            
                            // Add component cost to total
                            total_cost <= total_cost + dp[(1 << comp_size) - 1];
                            comp_index <= comp_index + 4'd1;
                        end
                    end else begin
                        // All components processed
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!impossible) begin
                        result <= total_cost;
                    end
                    if (start) begin
                        state <= COLLECT;
                        // Clear for next computation
                        visited_nodes <= 8'd0;
                        comp_count <= 4'd0;
                    end
                end
            endcase
        end
    end
endmodule