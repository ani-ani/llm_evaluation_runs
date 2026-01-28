module LongestPathCactus (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [5:0] M,
    input [3:0] edge_A [0:15],
    input [3:0] edge_B [0:15],
    output reg [7:0] result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] BUILD_MATRIX = 3'd2;
    localparam [2:0] BFS = 3'd3;
    localparam [2:0] CYCLE_CHECK = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;
    
    // Registers for graph data
    reg [15:0] adj [0:15]; // Adjacency matrix as bitmasks (16x16)
    reg [3:0] dist [0:15]; // Distances from node 1 (1-indexed)
    
    // BFS queue and indices
    reg [3:0] queue [0:15]; // Max 16 nodes
    reg [3:0] queue_head, queue_tail, queue_count;
    reg [3:0] current_node, neighbor;
    
    // Iteration counters
    reg [3:0] i, j, k;
    reg [5:0] edge_idx;
    reg [7:0] temp_dist;
    
    // Cycle check variables
    reg [3:0] u, v;
    reg [7:0] alt_path_len;
    reg [7:0] max_path;
    
    // Cycle detection flags
    reg edge_is_tree [0:15]; // Track if edge was used in BFS tree
    
    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 16'd0;
                dist[i] <= 4'd0;
                queue[i] <= 4'd0;
                edge_is_tree[i] <= 1'b0;
            end
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_count <= 4'd0;
            current_node <= 4'd0;
            neighbor <= 4'd0;
            edge_idx <= 6'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            u <= 4'd0;
            v <= 4'd0;
            temp_dist <= 8'd0;
            max_path <= 8'd0;
            alt_path_len <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    edge_idx <= 6'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    queue_count <= 4'd0;
                    max_path <= 8'd0;
                    if (start) begin
                        // Initialize graph arrays
                        for (i = 0; i < 16; i = i + 1) begin
                            adj[i] <= 16'd0;
                            dist[i] <= 4'd0;
                            queue[i] <= 4'd0;
                            edge_is_tree[i] <= 1'b0;
                        end
                        i <= 4'd0;
                    end
                end
                
                LOAD_EDGES: begin
                    if (edge_idx < M && edge_idx < 16) begin
                        // Add edge to adjacency matrix (undirected)
                        u <= edge_A[edge_idx];
                        v <= edge_B[edge_idx];
                        edge_idx <= edge_idx + 6'd1;
                    end
                end
                
                BUILD_MATRIX: begin
                    // Update adjacency matrix with edges from LOAD_EDGES
                    // Check if u and v are valid (1 to N)
                    if (u != 4'd0 && u <= N && v != 4'd0 && v <= N) begin
                        adj[u-1] <= adj[u-1] | (16'b1 << (v-1));
                        adj[v-1] <= adj[v-1] | (16'b1 << (u-1));
                    end
                    i <= 4'd0;
                end
                
                BFS: begin
                    // Initialize distances
                    if (i < 16) begin
                        dist[i] <= 4'd15; // Use 15 as infinity
                        i <= i + 4'd1;
                    end else if (i == 16 && queue_count == 4'd0 && current_node == 4'd0) begin
                        // Initialize BFS with node 1 (index 0)
                        if (N > 4'd0) begin
                            dist[0] <= 4'd0;
                            queue[0] <= 4'd0; // Queue stores node index (0-based)
                            queue_head <= 4'd0;
                            queue_tail <= 4'd1;
                            queue_count <= 4'd1;
                            i <= i + 4'd1; // Mark as initialized
                        end
                    end else if (queue_count > 4'd0) begin
                        // Dequeue
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        queue_count <= queue_count - 4'd1;
                        j <= 4'd0; // Reset neighbor counter
                    end else if (current_node != 4'd0 || (current_node == 4'd0 && j == 4'd16)) begin
                        // Process neighbors of current_node
                        if (j < 16 && current_node < 16) begin
                            // Check if there's an edge to neighbor j
                            if (adj[current_node][j] && dist[j] == 4'd15) begin
                                // Neighbor j is unvisited
                                dist[j] <= dist[current_node] + 4'd1;
                                // Enqueue j
                                queue[queue_tail] <= j;
                                queue_tail <= queue_tail + 4'd1;
                                queue_count <= queue_count + 4'd1;
                            end
                            j <= j + 4'd1;
                        end else begin
                            current_node <= 4'd0; // Mark current processing done
                        end
                    end
                end
                
                CYCLE_CHECK: begin
                    // Check all edges for cycle paths
                    if (k < M && k < 16) begin
                        u <= edge_A[k];
                        v <= edge_B[k];
                        k <= k + 4'd1;
                    end else if (k < 16 && edge_idx < 16) begin
                        // Also check edges in adj for completeness
                        // Use edge_idx to iterate through all possible edges
                        u <= edge_idx[3:0] + 4'd1;
                        v <= 4'd0;
                        edge_idx <= edge_idx + 6'd1;
                    end
                    
                    // Calculate alternative path length for current edge (u,v)
                    if (u != 4'd0 && v != 4'd0 && u <= N && v <= N && u != v) begin
                        if (dist[u-1] < 4'd15 && dist[v-1] < 4'd15) begin
                            temp_dist <= {4'd0, dist[u-1]} + {4'd0, dist[v-1]} + 8'd1;
                            // Update max_path
                            if (temp_dist > max_path) begin
                                max_path <= temp_dist;
                            end
                        end
                    end
                    
                    // Also consider direct paths (tree distances)
                    if (u <= N && u != 4'd0 && dist[u-1] < 4'd15) begin
                        if ({4'd0, dist[u-1]} > max_path) begin
                            max_path <= {4'd0, dist[u-1]};
                        end
                    end
                end
                
                OUTPUT: begin
                    // Clamp result to 255 if needed
                    if (max_path > 8'd255) begin
                        result <= 8'd255;
                    end else begin
                        result <= max_path;
                    end
                    done <= 1'b1;
                end
                
                FINISH: begin
                    done <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_EDGES;
                else next_state = IDLE;
            end
            
            LOAD_EDGES: begin
                if (edge_idx < M && edge_idx < 16) begin
                    next_state = LOAD_EDGES;
                end else begin
                    next_state = BUILD_MATRIX;
                end
            end
            
            BUILD_MATRIX: begin
                if (i < M && i < 16) begin
                    next_state = BUILD_MATRIX;
                end else begin
                    next_state = BFS;
                end
            end
            
            BFS: begin
                // Continue until queue is empty and all neighbors processed
                if (queue_count > 4'd0 || (current_node != 4'd0 && j < 16) || (i < 16 && current_node == 4'd0)) begin
                    next_state = BFS;
                end else begin
                    next_state = CYCLE_CHECK;
                end
            end
            
            CYCLE_CHECK: begin
                if (k < M && k < 16) begin
                    next_state = CYCLE_CHECK;
                end else if (k < 16 && edge_idx < 16) begin
                    next_state = CYCLE_CHECK;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule