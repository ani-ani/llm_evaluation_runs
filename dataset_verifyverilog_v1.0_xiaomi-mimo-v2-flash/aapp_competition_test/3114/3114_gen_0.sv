module graph_orientation (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [5:0] M,
    input [3:0] edge_u [0:27],
    input [3:0] edge_v [0:27],
    output reg result,
    output reg done,
    output reg [3:0] out_u [0:27],
    output reg [3:0] out_v [0:27]
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] BUILD_ADJ = 4'd2;
    localparam [3:0] DFS_INIT = 4'd3;
    localparam [3:0] DFS_START = 4'd4;
    localparam [3:0] DFS_PROCESS = 4'd5;
    localparam [3:0] CHECK_BRIDGE = 4'd6;
    localparam [3:0] ORIENT_INIT = 4'd7;
    localparam [3:0] BUILD_SPAN_TREE = 4'd8;
    localparam [3:0] ORIENT_EDGES = 4'd9;
    localparam [3:0] FINISH = 4'd10;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers
    reg [2:0] node_idx;          // Node index (0-7)
    reg [4:0] edge_idx;          // Edge index (0-27)
    reg [15:0] cycle_count;
    
    // Adjacency matrix (8x8 bits)
    reg adj [0:7][0:7];
    
    // For DFS bridge detection
    reg [3:0] disc [0:7];        // Discovery times
    reg [3:0] low [0:7];         // Low values
    reg visited [0:7];           // Visited flag
    reg [3:0] parent [0:7];      // Parent node
    reg [3:0] current_node;
    reg [3:0] dfs_stack [0:27];  // Stack for DFS nodes (max 28)
    reg [4:0] stack_ptr;
    reg [4:0] dfs_edge_idx;      // Current edge being processed in DFS
    reg found_bridge;
    
    // For spanning tree
    reg in_tree [0:27];          // Edge is in spanning tree
    reg [3:0] tree_parent [0:7]; // Parent in spanning tree
    reg visited_tree [0:7];      // Visited for spanning tree
    reg [4:0] orient_edge_idx;   // Edge index for orientation
    
    // Cycle counter max
    localparam [15:0] MAX_CYCLES = 16'd1000;

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = BUILD_ADJ;
            end
            BUILD_ADJ: begin
                if (edge_idx >= M) next_state = DFS_INIT;
            end
            DFS_INIT: begin
                next_state = DFS_START;
            end
            DFS_START: begin
                if (current_node >= N) next_state = FINISH;
                else next_state = DFS_PROCESS;
            end
            DFS_PROCESS: begin
                if (stack_ptr == 0) begin
                    if (found_bridge) next_state = FINISH;
                    else next_state = ORIENT_INIT;
                end else if (dfs_edge_idx >= M) begin
                    next_state = CHECK_BRIDGE;
                end else begin
                    next_state = DFS_PROCESS;
                end
            end
            CHECK_BRIDGE: begin
                next_state = DFS_PROCESS;
            end
            ORIENT_INIT: begin
                next_state = BUILD_SPAN_TREE;
            end
            BUILD_SPAN_TREE: begin
                if (orient_edge_idx >= M) next_state = ORIENT_EDGES;
            end
            ORIENT_EDGES: begin
                if (orient_edge_idx >= M) next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            edge_idx <= 5'd0;
            node_idx <= 3'd0;
            found_bridge <= 1'b0;
            stack_ptr <= 5'd0;
            dfs_edge_idx <= 5'd0;
            current_node <= 4'd0;
            orient_edge_idx <= 5'd0;
            
            // Clear arrays
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    adj[i][j] <= 1'b0;
                end
                disc[i] <= 4'd0;
                low[i] <= 4'd0;
                visited[i] <= 1'b0;
                parent[i] <= 4'd0;
                tree_parent[i] <= 4'd0;
                visited_tree[i] <= 1'b0;
            end
            for (i = 0; i < 28; i = i + 1) begin
                out_u[i] <= 4'd0;
                out_v[i] <= 4'd0;
                in_tree[i] <= 1'b0;
            end
        end else begin
            done <= 1'b0;
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                INIT: begin
                    edge_idx <= 5'd0;
                    node_idx <= 3'd0;
                    found_bridge <= 1'b0;
                    stack_ptr <= 5'd0;
                    dfs_edge_idx <= 5'd0;
                    current_node <= 4'd0;
                    orient_edge_idx <= 5'd0;
                    result <= 1'b0;
                end
                
                BUILD_ADJ: begin
                    if (edge_idx < M) begin
                        // Build adjacency matrix (undirected)
                        if (edge_u[edge_idx] < N && edge_v[edge_idx] < N) begin
                            adj[edge_u[edge_idx]][edge_v[edge_idx]] <= 1'b1;
                            adj[edge_v[edge_idx]][edge_u[edge_idx]] <= 1'b1;
                        end
                        edge_idx <= edge_idx + 5'd1;
                    end
                end
                
                DFS_INIT: begin
                    // Reset DFS arrays
                    for (i = 0; i < 8; i = i + 1) begin
                        disc[i] <= 4'd0;
                        low[i] <= 4'd0;
                        visited[i] <= 1'b0;
                        parent[i] <= 4'd0;
                    end
                    current_node <= 4'd0;
                    // Start DFS from node 0
                    if (N > 0) begin
                        visited[0] <= 1'b1;
                        disc[0] <= 4'd1;
                        low[0] <= 4'd1;
                        stack_ptr <= 5'd1;
                        dfs_stack[0] <= 4'd0;
                        current_node <= 4'd0;
                    end
                    dfs_edge_idx <= 5'd0;
                end
                
                DFS_START: begin
                    // Find next unvisited node
                    if (current_node < N && !visited[current_node]) begin
                        visited[current_node] <= 1'b1;
                        disc[current_node] <= 4'd1;
                        low[current_node] <= 4'd1;
                        stack_ptr <= 5'd1;
                        dfs_stack[0] <= current_node;
                    end else if (current_node < N) begin
                        current_node <= current_node + 4'd1;
                    end
                end
                
                DFS_PROCESS: begin
                    if (stack_ptr > 0 && dfs_edge_idx < M) begin
                        // Process edges from top of stack
                        reg [3:0] u;
                        reg [3:0] v;
                        u = dfs_stack[stack_ptr - 5'd1];
                        
                        // Check if edge connects u to v
                        if (edge_u[dfs_edge_idx] == u && edge_v[dfs_edge_idx] < N) begin
                            v = edge_v[dfs_edge_idx];
                            if (!visited[v]) begin
                                visited[v] <= 1'b1;
                                parent[v] <= u;
                                low[v] <= low[u] + 4'd1;
                                disc[v] <= disc[u] + 4'd1;
                                dfs_stack[stack_ptr] <= v;
                                stack_ptr <= stack_ptr + 5'd1;
                                dfs_edge_idx <= 5'd0;
                            end else if (v != parent[u]) begin
                                // Back edge found
                                if (disc[v] < low[u]) begin
                                    low[u] <= disc[v];
                                end
                            end
                        end else if (edge_v[dfs_edge_idx] == u && edge_u[dfs_edge_idx] < N) begin
                            v = edge_u[dfs_edge_idx];
                            if (!visited[v]) begin
                                visited[v] <= 1'b1;
                                parent[v] <= u;
                                low[v] <= low[u] + 4'd1;
                                disc[v] <= disc[u] + 4'd1;
                                dfs_stack[stack_ptr] <= v;
                                stack_ptr <= stack_ptr + 5'd1;
                                dfs_edge_idx <= 5'd0;
                            end else if (v != parent[u]) begin
                                if (disc[v] < low[u]) begin
                                    low[u] <= disc[v];
                                end
                            end
                        end
                        
                        dfs_edge_idx <= dfs_edge_idx + 5'd1;
                    end
                end
                
                CHECK_BRIDGE: begin
                    // Check for bridge (non-root with low[v] >= disc[u])
                    if (stack_ptr > 0) begin
                        reg [3:0] v;
                        reg [3:0] u;
                        v = dfs_stack[stack_ptr - 5'd1];
                        u = parent[v];
                        
                        if (v != 4'd0 && low[v] >= disc[u]) begin
                            found_bridge <= 1'b1;
                        end
                        
                        // Update parent low value
                        if (v != 4'd0 && low[v] < low[u]) begin
                            low[u] <= low[v];
                        end
                        
                        stack_ptr <= stack_ptr - 5'd1;
                    end
                    dfs_edge_idx <= 5'd0;
                end
                
                ORIENT_INIT: begin
                    // Initialize spanning tree flags
                    for (i = 0; i < 28; i = i + 1) begin
                        in_tree[i] <= 1'b0;
                    end
                    for (i = 0; i < 8; i = i + 1) begin
                        tree_parent[i] <= 4'd0;
                        visited_tree[i] <= 1'b0;
                    end
                    // Build spanning tree using parent array from DFS
                    for (i = 0; i < 8; i = i + 1) begin
                        if (parent[i] != 4'd0 || i == 4'd0) begin
                            // Mark edges in tree
                            for (j = 0; j < M; j = j + 1) begin
                                if (((edge_u[j] == parent[i] && edge_v[j] == i) || 
                                     (edge_v[j] == parent[i] && edge_u[j] == i)) &&
                                     parent[i] != 4'd0) begin
                                    in_tree[j] <= 1'b1;
                                end
                            end
                        end
                    end
                    orient_edge_idx <= 5'd0;
                end
                
                BUILD_SPAN_TREE: begin
                    // Already built in ORIENT_INIT
                    orient_edge_idx <= orient_edge_idx + 5'd1;
                end
                
                ORIENT_EDGES: begin
                    if (orient_edge_idx < M) begin
                        if (in_tree[orient_edge_idx]) begin
                            // Tree edge: orient away from root (node 0)
                            // If edge_v is child, orient u->v, else v->u
                            if (parent[edge_v[orient_edge_idx]] == edge_u[orient_edge_idx]) begin
                                out_u[orient_edge_idx] <= edge_u[orient_edge_idx];
                                out_v[orient_edge_idx] <= edge_v[orient_edge_idx];
                            end else begin
                                out_u[orient_edge_idx] <= edge_v[orient_edge_idx];
                                out_v[orient_edge_idx] <= edge_u[orient_edge_idx];
                            end
                        end else begin
                            // Non-tree edge: orient from lower to higher index
                            if (edge_u[orient_edge_idx] <= edge_v[orient_edge_idx]) begin
                                out_u[orient_edge_idx] <= edge_u[orient_edge_idx];
                                out_v[orient_edge_idx] <= edge_v[orient_edge_idx];
                            end else begin
                                out_u[orient_edge_idx] <= edge_v[orient_edge_idx];
                                out_v[orient_edge_idx] <= edge_u[orient_edge_idx];
                            end
                        end
                        orient_edge_idx <= orient_edge_idx + 5'd1;
                    end
                end
                
                FINISH: begin
                    result <= ~found_bridge;
                    done <= 1'b1;
                    cycle_count <= 16'd0;
                end
            endcase
            
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= FINISH;
                result <= 1'b0;
                done <= 1'b1;
            end else begin
                state <= next_state;
            end
        end
    end

endmodule