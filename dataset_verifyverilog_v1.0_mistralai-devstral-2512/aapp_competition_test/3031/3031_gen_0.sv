module TreeGoodNodesFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire [3:0] edge_src,
    input wire [3:0] edge_dst,
    input wire [7:0] edge_color,
    input wire edge_load_en,
    input wire [3:0] query_node,
    output reg done,
    output reg is_good,
    output reg [3:0] result_count
);

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Edge storage (15 edges max)
    reg [3:0] edge_src_mem [0:14];
    reg [3:0] edge_dst_mem [0:14];
    reg [7:0] edge_color_mem [0:14];
    reg [3:0] edge_count;
    
    // Adjacency list (16 nodes, 3 edges max per node)
    reg [3:0] adj_node [0:15][0:2];
    reg [7:0] adj_color [0:15][0:2];
    reg [3:0] adj_count [0:15];
    
    // Computation variables
    reg [3:0] current_node;
    reg [3:0] check_node;
    reg [3:0] neighbor_idx;
    reg [3:0] color_check_node;
    reg [3:0] subtree_node;
    reg [3:0] subtree_parent;
    reg [7:0] check_color;
    reg [3:0] good_nodes [0:15];
    reg [3:0] good_count;
    reg [3:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] visited [0:15];
    reg color_found;
    reg [3:0] i, j, k;
    
    // Load edges into memory
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_count <= 4'd0;
            for (i = 0; i < 15; i = i + 1) begin
                edge_src_mem[i] <= 4'd0;
                edge_dst_mem[i] <= 4'd0;
                edge_color_mem[i] <= 8'd0;
            end
        end else if (state == LOAD_EDGES && edge_load_en) begin
            edge_src_mem[edge_count] <= edge_src;
            edge_dst_mem[edge_count] <= edge_dst;
            edge_color_mem[edge_count] <= edge_color;
            edge_count <= edge_count + 4'd1;
        end
    end
    
    // Build adjacency list
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                adj_count[i] <= 4'd0;
                for (j = 0; j < 3; j = j + 1) begin
                    adj_node[i][j] <= 4'd0;
                    adj_color[i][j] <= 8'd0;
                end
            end
        end else if (state == LOAD_EDGES && edge_count == num_nodes - 4'd1) begin
            // Build adjacency list after all edges loaded
            for (i = 0; i < 15; i = i + 1) begin
                if (edge_src_mem[i] != 4'd0) begin
                    j = adj_count[edge_src_mem[i]];
                    adj_node[edge_src_mem[i]][j] <= edge_dst_mem[i];
                    adj_color[edge_src_mem[i]][j] <= edge_color_mem[i];
                    adj_count[edge_src_mem[i]] <= adj_count[edge_src_mem[i]] + 4'd1;
                    
                    j = adj_count[edge_dst_mem[i]];
                    adj_node[edge_dst_mem[i]][j] <= edge_src_mem[i];
                    adj_color[edge_dst_mem[i]][j] <= edge_color_mem[i];
                    adj_count[edge_dst_mem[i]] <= adj_count[edge_dst_mem[i]] + 4'd1;
                end
            end
        end
    end
    
    // Check if node is good
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_node <= 4'd0;
            check_node <= 4'd0;
            neighbor_idx <= 4'd0;
            color_check_node <= 4'd0;
            subtree_node <= 4'd0;
            subtree_parent <= 4'd0;
            check_color <= 8'd0;
            stack_ptr <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                visited[i] <= 4'd0;
            end
            color_found <= 1'b0;
        end else if (state == COMPUTE) begin
            // Local color check
            if (neighbor_idx == 4'd0) begin
                // Initialize for new node
                check_node <= current_node;
                color_found <= 1'b0;
                
                // Check if any color appears more than once
                for (i = 0; i < adj_count[check_node]; i = i + 1) begin
                    for (j = i + 4'd1; j < adj_count[check_node]; j = j + 1) begin
                        if (adj_color[check_node][i] == adj_color[check_node][j]) begin
                            color_found <= 1'b1;
                        end
                    end
                end
                
                if (!color_found && adj_count[check_node] > 4'd0) begin
                    // Start subtree check
                    neighbor_idx <= 4'd0;
                    stack_ptr <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        visited[i] <= 4'd0;
                    end
                end else begin
                    // Skip to next node
                    good_nodes[current_node] <= 4'd0;
                    current_node <= current_node + 4'd1;
                    if (current_node >= num_nodes) begin
                        next_state <= OUTPUT;
                    end
                end
            end else if (neighbor_idx < adj_count[check_node]) begin
                // Subtree check for current neighbor
                check_color <= adj_color[check_node][neighbor_idx];
                subtree_node <= adj_node[check_node][neighbor_idx];
                subtree_parent <= check_node;
                
                // Initialize stack for DFS
                stack[0] <= subtree_node;
                stack_ptr <= 4'd1;
                visited[subtree_node] <= 4'd1;
                
                neighbor_idx <= neighbor_idx + 4'd1;
            end else begin
                // All neighbors checked, node is good
                good_nodes[current_node] <= 4'd1;
                current_node <= current_node + 4'd1;
                if (current_node >= num_nodes) begin
                    next_state <= OUTPUT;
                end
            end
        end
    end
    
    // DFS for subtree color check
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in COMPUTE block
        end else if (state == COMPUTE && stack_ptr > 4'd0) begin
            // Pop from stack
            subtree_node <= stack[stack_ptr - 4'd1];
            stack_ptr <= stack_ptr - 4'd1;
            
            // Check if this node has the color we're looking for
            for (i = 0; i < adj_count[subtree_node]; i = i + 1) begin
                if (adj_color[subtree_node][i] == check_color && 
                    adj_node[subtree_node][i] != subtree_parent) begin
                    color_found <= 1'b1;
                end
            end
            
            // Push unvisited neighbors to stack
            for (i = 0; i < adj_count[subtree_node]; i = i + 1) begin
                if (adj_node[subtree_node][i] != subtree_parent && 
                    !visited[adj_node[subtree_node][i]]) begin
                    stack[stack_ptr] <= adj_node[subtree_node][i];
                    stack_ptr <= stack_ptr + 4'd1;
                    visited[adj_node[subtree_node][i]] <= 4'd1;
                end
            end
            
            // If color found, mark node as not good and move to next
            if (color_found) begin
                good_nodes[current_node] <= 4'd0;
                current_node <= current_node + 4'd1;
                if (current_node >= num_nodes) begin
                    next_state <= OUTPUT;
                end
            end
        end
    end
    
    // Count good nodes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            good_count <= 4'd0;
        end else if (state == OUTPUT) begin
            good_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (good_nodes[i]) begin
                    good_count <= good_count + 4'd1;
                end
            end
        end
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            is_good <= 1'b0;
            result_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                next_state = IDLE;
                done = 1'b0;
                if (start) begin
                    next_state = LOAD_EDGES;
                end
            end
            
            LOAD_EDGES: begin
                next_state = LOAD_EDGES;
                done = 1'b0;
                if (edge_count == num_nodes - 4'd1) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                next_state = COMPUTE;
                done = 1'b0;
                if (current_node >= num_nodes) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                next_state = IDLE;
                done = 1'b1;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output results
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_count <= 4'd0;
            is_good <= 1'b0;
        end else begin
            result_count <= good_count;
            is_good <= good_nodes[query_node];
        end
    end
    
endmodule