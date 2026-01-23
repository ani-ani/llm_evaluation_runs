module bandit_gold_max(
    input clk,
    input rst_n,
    input start,
    input [7:0] gold_i,
    input [2:0] gold_idx,
    input [7:0] adj_matrix [8:0][8:0],
    output reg [15:0] max_gold,
    output reg done,
    output reg valid
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam INIT_GOLD = 4'd1;
    localparam BUILD_MATRIX = 4'd2;
    localparam BFS_DIST = 4'd3;
    localparam FIND_PATHS = 4'd4;
    localparam CHECK_RETURN = 4'd5;
    localparam UPDATE_MAX = 4'd6;
    localparam DONE = 4'd7;

    reg [3:0] state, next_state;
    
    // Storage for gold values (nodes 3-8)
    reg [7:0] gold_nodes [3:8];
    
    // Adjacency matrix stored locally
    reg [7:0] adj [1:8][1:8];
    
    // BFS distance array
    reg [3:0] dist [1:8]; // max distance 15
    
    // Path enumeration registers
    reg [3:0] path_nodes [7:0]; // up to 8 nodes in path
    reg [2:0] path_len; // number of nodes in current path
    reg [2:0] current_depth; // for DFS
    
    // Node tracking
    reg [2:0] node_idx; // general purpose node counter
    reg [2:0] src_node, dst_node;
    reg [2:0] queue [15:0]; // BFS queue
    reg [3:0] q_head, q_tail;
    reg [3:0] visited_nodes; // bitmask
    
    // Current path gold sum
    reg [15:0] current_gold;
    
    // Return path check registers
    reg [2:0] return_node;
    reg return_valid;
    reg [2:0] visited_mask; // for return path DFS
    
    // Path enumeration state
    reg [2:0] path_idx; // which path we're evaluating
    reg [2:0] valid_path_count;
    reg [7:0] visited_path_mask; // visited nodes in current path
    
    // Intermediate registers
    reg [3:0] dist_temp;
    reg [2:0] neighbor;
    reg [2:0] i, j, k;
    reg found;
    reg [15:0] temp_sum;
    
    // Arrays for path storage (up to 20 valid paths for 8 nodes)
    reg [2:0] stored_paths [19:0][7:0]; // 20 paths, max 8 nodes each
    reg [2:0] stored_lens [19:0];
    reg [4:0] path_count;
    
    // Return path DFS stack
    reg [2:0] ret_stack [7:0];
    reg [2:0] ret_sp;
    reg [2:0] ret_visited;
    
    integer p_idx, n_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_gold <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            path_count <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        max_gold <= 16'd0;
                        done <= 1'b0;
                        valid <= 1'b0;
                        path_count <= 5'd0;
                        node_idx <= 3'd0;
                    end
                end
                
                INIT_GOLD: begin
                    if (gold_idx >= 3'd1 && gold_idx <= 3'd6) begin
                        case (gold_idx)
                            3'd1: gold_nodes[3] <= gold_i;
                            3'd2: gold_nodes[4] <= gold_i;
                            3'd3: gold_nodes[5] <= gold_i;
                            3'd4: gold_nodes[6] <= gold_i;
                            3'd5: gold_nodes[7] <= gold_i;
                            3'd6: gold_nodes[8] <= gold_i;
                        endcase
                    end
                end
                
                BUILD_MATRIX: begin
                    // Copy adjacency matrix from input to internal storage
                    // For each pair (i,j), check if there's an edge
                    if (node_idx == 3'd0) begin
                        // Initialize
                        for (i = 1; i <= 8; i = i + 1) begin
                            for (j = 1; j <= 8; j = j + 1) begin
                                adj[i][j] <= 8'd0;
                            end
                        end
                        node_idx <= 3'd1;
                    end else if (node_idx <= 3'd6) begin
                        // Copy row and column for nodes 1-6 in first iteration
                        for (j = 1; j <= 8; j = j + 1) begin
                            adj[node_idx][j] <= adj_matrix[node_idx][j];
                        end
                        node_idx <= node_idx + 1'b1;
                    end else if (node_idx == 3'd7) begin
                        for (j = 1; j <= 8; j = j + 1) begin
                            adj[7][j] <= adj_matrix[7][j];
                            adj[8][j] <= adj_matrix[8][j];
                            adj[1][j] <= adj_matrix[1][j]; // ensure complete
                            adj[2][j] <= adj_matrix[2][j];
                        end
                        node_idx <= 3'd0;
                    end
                end
                
                BFS_DIST: begin
                    // BFS to find shortest distances from node 1
                    case (node_idx)
                        3'd0: begin
                            // Initialize distances
                            for (k = 1; k <= 8; k = k + 1) begin
                                dist[k] <= 4'hF;
                            end
                            dist[1] <= 4'd0;
                            q_head <= 4'd0;
                            q_tail <= 4'd1;
                            queue[0] <= 3'd1;
                            node_idx <= 3'd1;
                        end
                        3'd1: begin
                            if (q_head < q_tail) begin
                                // Pop from queue
                                src_node <= queue[q_head];
                                q_head <= q_head + 1'b1;
                                node_idx <= 3'd2;
                            end else begin
                                node_idx <= 3'd3;
                            end
                        end
                        3'd2: begin
                            // Visit neighbors
                            for (neighbor = 3'd1; neighbor <= 3'd7; neighbor = neighbor + 1'b1) begin
                                if (adj[src_node][neighbor] && (dist[src_node] + 1'b1 < dist[neighbor])) begin
                                    dist[neighbor] <= dist[src_node] + 1'b1;
                                    queue[q_tail] <= neighbor;
                                    q_tail <= q_tail + 1'b1;
                                end
                            end
                            // Also check node 8
                            if (adj[src_node][3'd0]) begin
                                // Node 8 is indexed as 0 in 3-bit, handle specially
                            end
                            node_idx <= 3'd1;
                        end
                        3'd3: begin
                            // Handle node 8 separately due to 3-bit encoding
                            // Check all nodes for neighbors to 8
                            for (i = 1; i <= 8; i = i + 1) begin
                                if (adj[i][8]) begin
                                    if (dist[i] + 1'b1 < dist[8]) begin
                                        dist[8] <= dist[i] + 1'b1;
                                    end
                                end
                            end
                            node_idx <= 3'd0;
                        end
                    endcase
                end
                
                FIND_PATHS: begin
                    // Find all shortest paths from 1 to 2
                    case (node_idx)
                        3'd0: begin
                            // Initialize path enumeration
                            path_count <= 5'd0;
                            current_depth <= 3'd0;
                            visited_path_mask <= 8'd0;
                            path_nodes[0] <= 3'd1;
                            visited_path_mask[1] <= 1'b1;
                            node_idx <= 3'd1;
                        end
                        3'd1: begin
                            // DFS to enumerate paths
                            if (current_depth == 3'd0) begin
                                // Start DFS
                                current_depth <= 3'd1;
                                node_idx <= 3'd2;
                            end else if (current_depth > 3'd0 && current_depth < dist[2]) begin
                                // Find next valid node
                                found <= 1'b0;
                                for (i = 1; i <= 8; i = i + 1) begin
                                    if (!visited_path_mask[i] && adj[path_nodes[current_depth-1]][i] && 
                                        (dist[i] == dist[path_nodes[current_depth-1]] + 1'b1) &&
                                        (dist[i] <= dist[2])) begin
                                        // Push
                                        path_nodes[current_depth] <= i;
                                        visited_path_mask[i] <= 1'b1;
                                        current_depth <= current_depth + 1'b1;
                                        found <= 1'b1;
                                        disable;
                                    end
                                end
                                if (!found) begin
                                    // Backtrack
                                    if (current_depth > 3'd1) begin
                                        visited_path_mask[path_nodes[current_depth-1]] <= 1'b0;
                                        current_depth <= current_depth - 1'b1;
                                    end else begin
                                        node_idx <= 3'd0;
                                    end
                                end
                            end else if (current_depth == dist[2]) begin
                                // Check if reached destination
                                if (path_nodes[current_depth-1] == 3'd2) begin
                                    // Store path
                                    if (path_count < 20) begin
                                        for (p_idx = 0; p_idx < 8; p_idx = p_idx + 1) begin
                                            if (p_idx < current_depth) begin
                                                stored_paths[path_count][p_idx] <= path_nodes[p_idx];
                                            end else begin
                                                stored_paths[path_count][p_idx] <= 3'd0;
                                            end
                                        end
                                        stored_lens[path_count] <= current_depth;
                                        path_count <= path_count + 1'b1;
                                    end
                                    // Backtrack
                                    current_depth <= current_depth - 1'b1;
                                    visited_path_mask[path_nodes[current_depth-1]] <= 1'b0;
                                end else begin
                                    // Continue DFS
                                    node_idx <= 3'd1;
                                end
                            end else begin
                                node_idx <= 3'd1;
                            end
                        end
                    endcase
                end
                
                CHECK_RETURN: begin
                    // Check if return path exists avoiding robbed nodes
                    case (node_idx)
                        3'd0: begin
                            // Initialize for current path
                            path_idx <= 5'd0;
                            node_idx <= 3'd1;
                        end
                        3'd1: begin
                            if (path_idx < path_count) begin
                                // Calculate gold for this path
                                current_gold <= 16'd0;
                                for (p_idx = 0; p_idx < 8; p_idx = p_idx + 1) begin
                                    if (stored_lens[path_idx] > p_idx && stored_paths[path_idx][p_idx] >= 3'd3) begin
                                        current_gold <= current_gold + gold_nodes[stored_paths[path_idx][p_idx]];
                                    end
                                end
                                // Build robbed nodes mask
                                visited_mask <= 8'd0;
                                for (p_idx = 0; p_idx < 8; p_idx = p_idx + 1) begin
                                    if (stored_lens[path_idx] > p_idx && stored_paths[path_idx][p_idx] >= 3'd3) begin
                                        visited_mask[stored_paths[path_idx][p_idx]] <= 1'b1;
                                    end
                                end
                                node_idx <= 3'd2;
                            end else begin
                                node_idx <= 3'd4;
                            end
                        end
                        3'd2: begin
                            // BFS for return path from 2 to 1
                            // Reset visited for return
                            ret_visited <= 5'b0; // 5 bits: nodes 1-8 (skip 0)
                            ret_sp <= 4'd0;
                            ret_stack[0] <= 3'd2;
                            ret_visited[2] <= 1'b1;
                            node_idx <= 3'd3;
                        end
                        3'd3: begin
                            // DFS for return path
                            if (ret_sp == 8'hFF) begin
                                // Done - path not found
                                return_valid <= 1'b0;
                                node_idx <= 3'd1; // next path
                            end else if (ret_stack[ret_sp] == 3'd1) begin
                                // Found path
                                return_valid <= 1'b1;
                                node_idx <= 3'd4;
                            end else begin
                                // Expand current node
                                src_node <= ret_stack[ret_sp];
                                found <= 1'b0;
                                for (neighbor = 3'd1; neighbor <= 3'd7; neighbor = neighbor + 1'b1) begin
                                    if (adj[src_node][neighbor] && !ret_visited[neighbor] && 
                                        (neighbor == 3'd1 || !visited_mask[neighbor])) begin
                                        ret_sp <= ret_sp + 1'b1;
                                        ret_stack[ret_sp + 1'b1] <= neighbor;
                                        ret_visited[neighbor] <= 1'b1;
                                        found <= 1'b1;
                                        disable;
                                    end
                                end
                                // Check node 8
                                if (adj[src_node][8] && !ret_visited[8] && !visited_mask[8]) begin
                                    ret_sp <= ret_sp + 1'b1;
                                    ret_stack[ret_sp + 1'b1] <= 3'd0;
                                    ret_visited[8] <= 1'b1;
                                    found <= 1'b1;
                                end
                                if (!found) begin
                                    ret_sp <= ret_sp - 1'b1;
                                end
                            end
                        end
                        3'd4: begin
                            // Update max gold if valid
                            if (return_valid && current_gold > max_gold) begin
                                max_gold <= current_gold;
                            end
                            path_idx <= path_idx + 1'b1;
                            node_idx <= 3'd1;
                        end
                    endcase
                end
                
                UPDATE_MAX: begin
                    // State transition to done
                end
                
                DONE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT_GOLD;
            INIT_GOLD: begin
                // Wait for completion signal or timeout
                // In practice, testbench will pulse gold values then move to next state
                // For now, advance after fixed cycles
                if ($time > 0) next_state = BUILD_MATRIX; // Placeholder
            end
            BUILD_MATRIX: next_state = BFS_DIST;
            BFS_DIST: begin
                // Execute BFS until queue empty (simplified)
                next_state = FIND_PATHS;
            end
            FIND_PATHS: begin
                // After path enumeration completes
                if (node_idx == 3'd0 && path_count > 0) next_state = CHECK_RETURN;
                else if (node_idx == 3'd0) next_state = DONE;
            end
            CHECK_RETURN: begin
                // After checking all paths
                if (node_idx == 3'd4 && path_idx >= path_count) next_state = DONE;
            end
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
        
        // Override for INIT_GOLD - needs to wait for gold inputs
        if (state == INIT_GOLD && gold_idx != 3'd0 && gold_idx <= 3'd6) begin
            next_state = INIT_GOLD;
        end
        if (state == INIT_GOLD && gold_idx == 3'd0) begin
            next_state = BUILD_MATRIX;
        end
    end

endmodule
