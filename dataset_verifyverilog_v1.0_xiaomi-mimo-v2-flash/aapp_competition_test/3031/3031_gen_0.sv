module TreeGoodNodesFinder(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [3:0] edge_src,
    input [3:0] edge_dst,
    input [7:0] edge_color,
    input edge_load_en,
    input [3:0] query_node,
    output reg done,
    output reg is_good,
    output reg [3:0] result_count
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CHECK_NODE = 3'd2;
    localparam [2:0] CHECK_LOCAL = 3'd3;
    localparam [2:0] CHECK_SUBTREE = 3'd4;
    localparam [2:0] UPDATE_COUNT = 3'd5;
    localparam [2:0] QUERY = 3'd6;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [3:0] current_node;
    reg [3:0] edge_idx;
    reg [3:0] neighbor_idx;
    reg [3:0] node_count;
    reg [3:0] edge_count;
    reg [3:0] temp_count;
    reg [3:0] cycle_count;
    
    // Adjacency storage: 16 nodes, each with up to 4 edges
    // edge format: {neighbor[3:0], color[7:0], valid[0:0]}
    reg [11:0] adj_list [0:15][0:3];
    reg [3:0] adj_degree [0:15];
    
    // Tree traversal state
    reg visited [0:15];
    reg [3:0] traversal_stack [0:15];
    reg [3:0] stack_ptr;
    reg [7:0] target_color;
    reg conflict_found;
    reg [3:0] temp_node;
    reg [3:0] i_idx;
    reg [3:0] j_idx;
    reg [3:0] stack_idx;
    reg [3:0] node_id;
    
    // Good node tracking
    reg good_node [0:15];
    reg [3:0] good_count;
    reg query_result;
    
    // Color check registers
    reg [7:0] color_check [0:15];
    reg [3:0] color_count;
    reg [3:0] color_idx;
    
    integer i, j, k;
    
    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                if (edge_count == num_nodes - 4'd1 && !edge_load_en)
                    next_state = CHECK_NODE;
                else
                    next_state = LOAD;
            end
            CHECK_NODE: begin
                if (current_node < num_nodes)
                    next_state = CHECK_LOCAL;
                else
                    next_state = QUERY;
            end
            CHECK_LOCAL: begin
                // Check for duplicate colors locally
                if (adj_degree[current_node] <= 4'd1)
                    next_state = CHECK_SUBTREE; // No conflicts possible
                else if (color_idx < adj_degree[current_node])
                    next_state = CHECK_LOCAL;
                else if (conflict_found)
                    next_state = UPDATE_COUNT;
                else
                    next_state = CHECK_SUBTREE;
            end
            CHECK_SUBTREE: begin
                // Check subtrees for each incident edge
                if (edge_idx < adj_degree[current_node]) begin
                    if (stack_ptr == 5'd16 || conflict_found)
                        next_state = CHECK_SUBTREE; // Move to next edge
                    else
                        next_state = CHECK_SUBTREE; // Continue traversal
                end else begin
                    next_state = UPDATE_COUNT;
                end
            end
            UPDATE_COUNT: begin
                next_state = CHECK_NODE;
            end
            QUERY: begin
                next_state = QUERY;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            is_good <= 1'b0;
            result_count <= 4'd0;
            current_node <= 4'd0;
            edge_count <= 4'd0;
            node_count <= 4'd0;
            cycle_count <= 4'd0;
            edge_idx <= 4'd0;
            neighbor_idx <= 4'd0;
            temp_count <= 4'd0;
            query_result <= 1'b0;
            good_count <= 4'd0;
            conflict_found <= 1'b0;
            stack_ptr <= 4'd0;
            color_idx <= 4'd0;
            
            // Initialize adjacency lists
            for (i = 0; i < 16; i = i + 1) begin
                adj_degree[i] <= 4'd0;
                for (j = 0; j < 4; j = j + 1) begin
                    adj_list[i][j] <= 12'd0;
                end
                good_node[i] <= 1'b0;
                visited[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    is_good <= 1'b0;
                    current_node <= 4'd0;
                    edge_count <= 4'd0;
                    cycle_count <= 4'd0;
                    conflict_found <= 1'b0;
                    if (start) begin
                        result_count <= 4'd0;
                        good_count <= 4'd0;
                    end
                end
                
                LOAD: begin
                    if (edge_load_en && edge_count < num_nodes - 4'd1) begin
                        // Load edge into adjacency list
                        // Store as {dst[3:0], color[7:0], 1'b1}
                        adj_list[edge_src][adj_degree[edge_src]] <= {edge_dst, edge_color, 1'b1};
                        adj_degree[edge_src] <= adj_degree[edge_src] + 4'd1;
                        
                        adj_list[edge_dst][adj_degree[edge_dst]] <= {edge_src, edge_color, 1'b1};
                        adj_degree[edge_dst] <= adj_degree[edge_dst] + 4'd1;
                        
                        edge_count <= edge_count + 4'd1;
                    end
                end
                
                CHECK_NODE: begin
                    // Reset traversal state
                    conflict_found <= 1'b0;
                    edge_idx <= 4'd0;
                    current_node <= current_node + 4'd1;
                end
                
                CHECK_LOCAL: begin
                    if (color_idx == 4'd0) begin
                        // Initialize color check array
                        for (k = 0; k < 16; k = k + 1) begin
                            color_check[k] <= 8'd0;
                        end
                    end else begin
                        // Check for duplicate colors
                        if (color_idx < adj_degree[current_node]) begin
                            // Get color from current edge
                            if (color_check[adj_list[current_node][color_idx-4'd1][11:4]] == 8'd0) begin
                                color_check[adj_list[current_node][color_idx-4'd1][11:4]] <= 1'b1;
                            end else begin
                                conflict_found <= 1'b1;
                            end
                        end
                    end
                    color_idx <= color_idx + 4'd1;
                end
                
                CHECK_SUBTREE: begin
                    if (edge_idx == 4'd0 && conflict_found == 1'b0) begin
                        // Reset visited array
                        for (k = 0; k < 16; k = k + 1) begin
                            visited[k] <= 1'b0;
                        end
                        visited[current_node] <= 1'b1;
                    end
                    
                    if (edge_idx < adj_degree[current_node] && conflict_found == 1'b0) begin
                        // Get neighbor and color for this edge
                        temp_node <= adj_list[current_node][edge_idx][11:4];
                        target_color <= adj_list[current_node][edge_idx][10:3];
                        
                        if (stack_ptr == 4'd0) begin
                            // Start traversal
                            stack_ptr <= 4'd1;
                            traversal_stack[0] <= adj_list[current_node][edge_idx][11:4];
                            visited[adj_list[current_node][edge_idx][11:4]] <= 1'b1;
                        end else begin
                            // Continue traversal
                            if (stack_ptr < 5'd16 && stack_idx < stack_ptr) begin
                                // Visit top of stack
                                node_id <= traversal_stack[stack_idx];
                                
                                // Check neighbors
                                if (neighbor_idx < adj_degree[traversal_stack[stack_idx]]) begin
                                    // Get neighbor
                                    temp_node <= adj_list[traversal_stack[stack_idx]][neighbor_idx][11:4];
                                    
                                    // Check if this edge has target color
                                    if (adj_list[traversal_stack[stack_idx]][neighbor_idx][10:3] == target_color) begin
                                        if (!visited[adj_list[traversal_stack[stack_idx]][neighbor_idx][11:4]]) begin
                                            // Found color again in subtree!
                                            conflict_found <= 1'b1;
                                        end
                                    end
                                    
                                    // Add unvisited neighbor to stack
                                    if (!visited[adj_list[traversal_stack[stack_idx]][neighbor_idx][11:4]] &&
                                        adj_list[traversal_stack[stack_idx]][neighbor_idx][11:4] != current_node) begin
                                        traversal_stack[stack_ptr] <= adj_list[traversal_stack[stack_idx]][neighbor_idx][11:4];
                                        visited[adj_list[traversal_stack[stack_idx]][neighbor_idx][11:4]] <= 1'b1;
                                        stack_ptr <= stack_ptr + 4'd1;
                                    end
                                    
                                    neighbor_idx <= neighbor_idx + 4'd1;
                                end else begin
                                    // Move to next stack element
                                    stack_idx <= stack_idx + 4'd1;
                                    neighbor_idx <= 4'd0;
                                end
                            end else if (stack_ptr >= 5'd16) begin
                                conflict_found <= 1'b1; // Overflow protection
                            end else begin
                                // Traversal complete, move to next edge
                                edge_idx <= edge_idx + 4'd1;
                                stack_ptr <= 4'd0;
                                stack_idx <= 4'd0;
                                neighbor_idx <= 4'd0;
                            end
                        end
                    end else begin
                        // Move to next edge or finish
                        if (edge_idx < adj_degree[current_node]) begin
                            edge_idx <= edge_idx + 4'd1;
                            stack_ptr <= 4'd0;
                            stack_idx <= 4'd0;
                            neighbor_idx <= 4'd0;
                        end
                    end
                end
                
                UPDATE_COUNT: begin
                    if (!conflict_found && adj_degree[current_node-4'd1] > 4'd0) begin
                        // Node is good
                        good_node[current_node-4'd1] <= 1'b1;
                        good_count <= good_count + 4'd1;
                    end else begin
                        good_node[current_node-4'd1] <= 1'b0;
                    end
                    conflict_found <= 1'b0;
                    color_idx <= 4'd0;
                    stack_ptr <= 4'd0;
                    stack_idx <= 4'd0;
                    neighbor_idx <= 4'd0;
                    if (current_node >= num_nodes) begin
                        done <= 1'b1;
                        result_count <= good_count;
                    end
                end
                
                QUERY: begin
                    done <= 1'b0;
                    // Provide is_good for queried node
                    is_good <= good_node[query_node];
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            state <= next_state;
        end
    end
    
endmodule