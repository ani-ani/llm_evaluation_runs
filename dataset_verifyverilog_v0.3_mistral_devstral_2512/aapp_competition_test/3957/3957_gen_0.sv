module treeland_max_distance (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,          // Number of towns (1-16)
    input [3:0] k,          // Number of university pairs (1-8)
    input [15:0] universities, // Bitmask of towns with universities (16 bits)
    input [15:0] adj [0:15], // Adjacency matrix for tree connections
    output reg [7:0] result,
    output reg done
);

    // Internal registers and state machine
    reg [2:0] state;
    reg [3:0] node_counter;
    reg [3:0] parent [0:15];
    reg [3:0] subtree_count [0:15];
    reg [7:0] total_distance;
    reg [3:0] i, j;
    reg [15:0] visited;
    reg [3:0] queue [0:15];
    reg [3:0] head, tail;
    reg [3:0] bfs_order [0:15];
    reg [3:0] bfs_index;
    
    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_TREE = 3'd1;
    localparam [2:0] CALC_SUBTREE = 3'd2;
    localparam [2:0] CALC_DISTANCE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            total_distance <= 8'd0;
            visited <= 16'd0;
            head <= 4'd0;
            tail <= 4'd0;
            bfs_index <= 4'd0;
            node_counter <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            for (integer idx = 0; idx < 16; idx = idx + 1) begin
                parent[idx] <= 4'd0;
                subtree_count[idx] <= 4'd0;
                bfs_order[idx] <= 4'd0;
                queue[idx] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize subtree counts with university markers
                        for (integer idx = 0; idx < 16; idx = idx + 1) begin
                            subtree_count[idx] <= universities[idx] ? 4'd1 : 4'd0;
                        end
                        state <= BUILD_TREE;
                        node_counter <= 4'd0;
                        visited <= 16'b0000000000000001; // Mark node 0 as visited
                        parent[0] <= 4'd0;
                        head <= 4'd0;
                        tail <= 4'd1;
                        queue[0] <= 4'd0;
                        bfs_index <= 4'd0;
                    end
                end
                
                BUILD_TREE: begin
                    // BFS to build tree structure and get order
                    if (head < tail) begin
                        // Dequeue current node
                        i <= queue[head];
                        head <= head + 4'd1;
                        j <= 4'd0;
                        state <= BUILD_TREE; // Stay for neighbor processing
                    end else if (bfs_index < 16) begin
                        // Process nodes in reverse BFS order for subtree calculation
                        state <= CALC_SUBTREE;
                        node_counter <= 4'd15; // Start from last node
                    end else begin
                        state <= IDLE;
                    end
                end
                
                CALC_SUBTREE: begin
                    if (node_counter > 0) begin
                        // For each node except root, add its subtree count to parent
                        if (parent[node_counter] != 4'd0 && parent[node_counter] != node_counter) begin
                            subtree_count[parent[node_counter]] <= subtree_count[parent[node_counter]] + subtree_count[node_counter];
                        end
                        node_counter <= node_counter - 4'd1;
                    end else begin
                        state <= CALC_DISTANCE;
                        node_counter <= 4'd1; // Start from node 1 (skip root)
                        total_distance <= 8'd0;
                    end
                end
                
                CALC_DISTANCE: begin
                    if (node_counter < n) begin
                        // For each edge, calculate contribution
                        if (subtree_count[node_counter] > 0 && subtree_count[node_counter] < (k << 1)) begin
                            // Contribution = min(subtree_count, 2*k - subtree_count)
                            if (subtree_count[node_counter] <= k) begin
                                total_distance <= total_distance + subtree_count[node_counter];
                            end else begin
                                total_distance <= total_distance + ((k << 1) - subtree_count[node_counter]);
                            end
                        end
                        node_counter <= node_counter + 4'd1;
                    end else begin
                        state <= DONE_STATE;
                        result <= total_distance;
                        done <= 1'b1;
                    end
                end
                
                DONE_STATE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
            
            // BUILD_TREE neighbor processing (combinational logic within state)
            if (state == BUILD_TREE && head < tail) begin
                if (j < 16) begin
                    if (adj[i][j] && !visited[j]) begin
                        parent[j] <= i;
                        visited[j] <= 1'b1;
                        queue[tail] <= j;
                        tail <= tail + 4'd1;
                        bfs_order[bfs_index] <= j;
                        bfs_index <= bfs_index + 4'd1;
                    end
                    j <= j + 4'd1;
                end
            end
        end
    end
endmodule