module min_cost_flow (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nodes,
    input [31:0] edges_u,
    input [31:0] edges_v,
    input [31:0] edges_c,
    input [31:0] edges_w,
    input [4:0] num_edges,
    input [3:0] s,
    input [3:0] t,
    output reg [15:0] max_flow,
    output reg [31:0] min_cost,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] INIT         = 4'd1;
    localparam [3:0] BUILD_MATRIX = 4'd2;
    localparam [3:0] BFS_START    = 4'd3;
    localparam [3:0] BFS_PROCESS  = 4'd4;
    localparam [3:0] FOUND_PATH   = 4'd5;
    localparam [3:0] AUGMENT      = 4'd6;
    localparam [3:0] UPDATE_RESIDUAL = 4'd7;
    localparam [3:0] FINISH       = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers
    reg [7:0] cap_matrix [0:15][0:15];   // Residual capacity matrix
    reg [7:0] cost_matrix [0:15][0:15];  // Residual cost matrix
    reg [7:0] edge_idx;
    reg [3:0] node_idx;
    reg [3:0] i, j;
    
    // BFS state
    reg [15:0] visited;                   // 16-bit visited array
    reg [15:0] queue [0:15];              // Queue for BFS
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] prev_node [0:15];           // Parent node for path reconstruction
    reg [7:0] prev_edge_cost [0:15];      // Cost to reach this node
    reg [7:0] path_cost [0:15];           // Accumulated cost
    reg [3:0] current_node;
    reg [3:0] path_len;
    
    // Augmentation
    reg [7:0] bottleneck;
    reg [3:0] aug_node;
    
    // Counters
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    reg [7:0] bfs_cycle_count;
    localparam [7:0] MAX_BFS_CYCLES = 8'd128;
    
    // Computation status
    reg path_found;
    reg no_augment_path;
    
    // Temporary storage
    reg [7:0] temp_cap;
    reg [7:0] temp_cost;
    reg [7:0] temp_u, temp_v;
    reg [7:0] temp_w;
    reg [7:0] temp_c;
    
    integer row, col;
    
    // Initialize all registers on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            max_flow <= 16'd0;
            min_cost <= 32'd0;
            done <= 1'b0;
            edge_idx <= 8'd0;
            node_idx <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            cycle_count <= 8'd0;
            bfs_cycle_count <= 8'd0;
            visited <= 16'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            current_node <= 4'd0;
            path_len <= 4'd0;
            bottleneck <= 8'd0;
            aug_node <= 4'd0;
            path_found <= 1'b0;
            no_augment_path <= 1'b0;
            temp_cap <= 8'd0;
            temp_cost <= 8'd0;
            temp_u <= 8'd0;
            temp_v <= 8'd0;
            temp_w <= 8'd0;
            temp_c <= 8'd0;
            
            // Initialize matrices to zero
            for (row = 0; row < 16; row = row + 1) begin
                for (col = 0; col < 16; col = col + 1) begin
                    cap_matrix[row][col] <= 8'd0;
                    cost_matrix[row][col] <= 8'd0;
                end
            end
            
            // Initialize BFS arrays
            for (row = 0; row < 16; row = row + 1) begin
                queue[row] <= 16'd0;
                prev_node[row] <= 4'd0;
                prev_edge_cost[row] <= 8'd0;
                path_cost[row] <= 8'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    max_flow <= 16'd0;
                    min_cost <= 32'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    edge_idx <= 8'd0;
                    node_idx <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    path_found <= 1'b0;
                    no_augment_path <= 1'b0;
                    visited <= 16'd0;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    
                    // Initialize matrices to zero
                    for (row = 0; row < 16; row = row + 1) begin
                        for (col = 0; col < 16; col = col + 1) begin
                            cap_matrix[row][col] <= 8'd0;
                            cost_matrix[row][col] <= 8'd0;
                        end
                    end
                    state <= BUILD_MATRIX;
                end
                
                BUILD_MATRIX: begin
                    if (edge_idx < num_edges) begin
                        // Extract edge data
                        temp_u <= edges_u[(edge_idx*4)+:4];
                        temp_v <= edges_v[(edge_idx*4)+:4];
                        temp_c <= edges_c[(edge_idx*8)+:8];
                        temp_w <= edges_w[(edge_idx*8)+:8];
                        
                        // Store in matrix
                        if (temp_u < 4'd16 && temp_v < 4'd16) begin
                            cap_matrix[temp_u][temp_v] <= temp_c;
                            cost_matrix[temp_u][temp_v] <= temp_w;
                        end
                        
                        edge_idx <= edge_idx + 8'd1;
                    end else begin
                        state <= BFS_START;
                    end
                end
                
                BFS_START: begin
                    // Check cycle count limit
                    if (cycle_count >= MAX_CYCLES) begin
                        no_augment_path <= 1'b1;
                        state <= FINISH;
                    end else begin
                        // Initialize BFS
                        visited <= (16'd1 << s);
                        queue[0] <= s;
                        queue_head <= 4'd0;
                        queue_tail <= 4'd1;
                        prev_node[s] <= s;
                        path_cost[s] <= 8'd0;
                        prev_edge_cost[s] <= 8'd0;
                        path_found <= 1'b0;
                        bfs_cycle_count <= 8'd0;
                        state <= BFS_PROCESS;
                    end
                end
                
                BFS_PROCESS: begin
                    if (bfs_cycle_count >= MAX_BFS_CYCLES) begin
                        no_augment_path <= 1'b1;
                        state <= FINISH;
                    end else if (queue_head < queue_tail) begin
                        // Dequeue
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        
                        // Check if reached sink
                        if (queue[queue_head] == t) begin
                            path_found <= 1'b1;
                            state <= FOUND_PATH;
                        end else begin
                            // Explore neighbors
                            node_idx <= 4'd0;
                            i <= 4'd0;
                            state <= BFS_PROCESS;
                        end
                        bfs_cycle_count <= bfs_cycle_count + 8'd1;
                    end else begin
                        // Queue empty, no path found
                        no_augment_path <= 1'b1;
                        state <= FINISH;
                    end
                end
                
                FOUND_PATH: begin
                    // Reconstruct path and find bottleneck
                    aug_node <= t;
                    bottleneck <= 8'd255;
                    path_len <= 4'd0;
                    state <= AUGMENT;
                end
                
                AUGMENT: begin
                    if (aug_node != s) begin
                        // Find bottleneck capacity along path
                        temp_u <= prev_node[aug_node];
                        temp_v <= aug_node;
                        temp_cap <= cap_matrix[prev_node[aug_node]][aug_node];
                        
                        // Update bottleneck
                        if (cap_matrix[prev_node[aug_node]][aug_node] < bottleneck) begin
                            bottleneck <= cap_matrix[prev_node[aug_node]][aug_node];
                        end
                        
                        // Move to previous node
                        aug_node <= prev_node[aug_node];
                        path_len <= path_len + 4'd1;
                    end else begin
                        // Update max flow and min cost
                        max_flow <= max_flow + {8'd0, bottleneck};
                        min_cost <= min_cost + (bottleneck * path_cost[t]);
                        
                        // Reset for augmentation update
                        aug_node <= t;
                        state <= UPDATE_RESIDUAL;
                    end
                end
                
                UPDATE_RESIDUAL: begin
                    if (aug_node != s) begin
                        // Update residual capacities
                        temp_u <= prev_node[aug_node];
                        temp_v <= aug_node;
                        temp_cap <= cap_matrix[prev_node[aug_node]][aug_node];
                        temp_cost <= cost_matrix[prev_node[aug_node]][aug_node];
                        
                        // Decrease forward capacity
                        cap_matrix[prev_node[aug_node]][aug_node] <= cap_matrix[prev_node[aug_node]][aug_node] - bottleneck;
                        
                        // Increase reverse capacity (add reverse edge)
                        if (cap_matrix[aug_node][prev_node[aug_node]] < 255) begin
                            cap_matrix[aug_node][prev_node[aug_node]] <= cap_matrix[aug_node][prev_node[aug_node]] + bottleneck;
                        end
                        
                        // Update costs (reverse edge has negative cost)
                        // For min-cost flow, we keep costs as is for forward
                        // and add negative for backward
                        
                        aug_node <= prev_node[aug_node];
                    end else begin
                        cycle_count <= cycle_count + 8'd1;
                        state <= BFS_START;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // BFS neighbor exploration logic (runs in parallel with states)
            if (state == BFS_PROCESS && queue_head < queue_tail && !path_found) begin
                // Check if we've finished exploring current node's neighbors
                if (node_idx < num_nodes) begin
                    // Check if edge exists with capacity > 0
                    if (cap_matrix[current_node][node_idx] > 0) begin
                        // Check if not visited
                        if (!((visited >> node_idx) & 16'd1)) begin
                            // Calculate new cost
                            temp_cost <= path_cost[current_node] + cost_matrix[current_node][node_idx];
                            
                            // Mark as visited
                            visited <= visited | (16'd1 << node_idx);
                            
                            // Enqueue
                            queue[queue_tail] <= node_idx;
                            queue_tail <= queue_tail + 4'd1;
                            
                            // Store parent
                            prev_node[node_idx] <= current_node;
                            path_cost[node_idx] <= path_cost[current_node] + cost_matrix[current_node][node_idx];
                        end
                    end
                    node_idx <= node_idx + 4'd1;
                end
            end
        end
    end

endmodule