module MaxFlowEdmondsKarp (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] src,
    input wire [2:0] sink,
    input wire edge_valid,
    input wire [2:0] edge_u,
    input wire [2:0] edge_v,
    input wire [7:0] edge_cap,
    output reg [15:0] result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] LOAD_EDGES     = 3'd1;
    localparam [2:0] CHECK_PATH     = 3'd2;
    localparam [2:0] BOTTLENECK     = 3'd3;
    localparam [2:0] UPDATE_RESIDUAL= 3'd4;
    localparam [2:0] FINISH         = 3'd5;

    // Residual capacity matrix: 8x8
    reg [7:0] residual [0:7][0:7];
    
    // BFS queue (circular buffer)
    reg [2:0] queue [0:7];
    reg [2:0] queue_head;
    reg [2:0] queue_tail;
    reg [2:0] queue_count;
    
    // Parent array for path tracking
    reg [2:0] parent [0:7];
    
    // Visited array for BFS
    reg visited [0:7];
    
    // Temp variables
    reg [2:0] current_node;
    reg [2:0] neighbor;
    reg [2:0] path_node;
    reg [15:0] total_flow;
    reg [7:0] min_capacity;
    reg [2:0] bfs_src;
    reg [2:0] bfs_sink;
    reg path_found;
    reg [7:0] iteration_count;
    
    // Helper signals
    reg [2:0] i;
    reg [2:0] j;
    reg [2:0] k;
    
    // State register
    reg [2:0] state;
    reg [2:0] next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            total_flow <= 16'd0;
            iteration_count <= 8'd0;
            queue_head <= 3'd0;
            queue_tail <= 3'd0;
            queue_count <= 3'd0;
            path_found <= 1'b0;
            min_capacity <= 8'd0;
            
            // Reset residual matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    residual[i][j] <= 8'd0;
                end
            end
            
            // Reset visited and parent
            for (k = 0; k < 8; k = k + 1) begin
                visited[k] <= 1'b0;
                parent[k] <= 3'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        total_flow <= 16'd0;
                        iteration_count <= 8'd0;
                        state <= LOAD_EDGES;
                    end
                end
                
                LOAD_EDGES: begin
                    if (edge_valid) begin
                        residual[edge_u][edge_v] <= edge_cap;
                    end
                    if (!edge_valid && start) begin
                        // Edge loading complete, start BFS
                        bfs_src <= src;
                        bfs_sink <= sink;
                        state <= CHECK_PATH;
                    end
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                CHECK_PATH: begin
                    // Initialize BFS
                    for (i = 0; i < 8; i = i + 1) begin
                        visited[i] <= 1'b0;
                        parent[i] <= 3'd0;
                    end
                    visited[bfs_src] <= 1'b1;
                    queue_head <= 3'd0;
                    queue_tail <= 3'd0;
                    queue_count <= 3'd1;
                    queue[0] <= bfs_src;
                    path_found <= 1'b0;
                    state <= BOTTLENECK;
                end
                
                BOTTLENECK: begin
                    // BFS to find augmenting path
                    if (queue_count > 0 && !path_found) begin
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 3'd1;
                        queue_count <= queue_count - 3'd1;
                        
                        // Check all neighbors
                        if (current_node == bfs_sink) begin
                            path_found <= 1'b1;
                            path_node <= bfs_sink;
                        end
                    end else if (queue_count == 0 || path_found) begin
                        if (!path_found) begin
                            // No path found, finish
                            state <= FINISH;
                        end else begin
                            // Find bottleneck capacity
                            min_capacity <= 8'd255;
                            path_node <= bfs_sink;
                            state <= UPDATE_RESIDUAL;
                        end
                    end else begin
                        // Continue BFS - check neighbors
                        neighbor <= neighbor + 3'd1;
                        if (neighbor >= 8'd8) begin
                            neighbor <= 3'd0;
                        end else begin
                            if (!visited[neighbor] && residual[current_node][neighbor] > 0) begin
                                visited[neighbor] <= 1'b1;
                                parent[neighbor] <= current_node;
                                queue[queue_tail] <= neighbor;
                                queue_tail <= queue_tail + 3'd1;
                                queue_count <= queue_count + 3'd1;
                            end
                        end
                    end
                end
                
                UPDATE_RESIDUAL: begin
                    if (path_node != bfs_src) begin
                        // Update residual capacities along path
                        if (residual[parent[path_node]][path_node] < min_capacity) begin
                            min_capacity <= residual[parent[path_node]][path_node];
                        end
                        path_node <= parent[path_node];
                    end else begin
                        // Apply bottleneck to path
                        path_node <= bfs_sink;
                        state <= UPDATE_RESIDUAL;
                        // Start updating residuals
                    end
                    
                    // Update residuals (forward and backward)
                    if (path_node != bfs_src) begin
                        residual[parent[path_node]][path_node] <= 
                            residual[parent[path_node]][path_node] - min_capacity;
                        residual[path_node][parent[path_node]] <= 
                            residual[path_node][parent[path_node]] + min_capacity;
                        path_node <= parent[path_node];
                    end else begin
                        // Update total flow
                        total_flow <= total_flow + min_capacity;
                        
                        // Increment iteration count
                        iteration_count <= iteration_count + 8'd1;
                        
                        // Check if exceeded max iterations
                        if (iteration_count >= 8'd255) begin
                            state <= FINISH;
                        end else begin
                            // Start next BFS
                            state <= CHECK_PATH;
                        end
                    end
                end
                
                FINISH: begin
                    result <= total_flow;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule