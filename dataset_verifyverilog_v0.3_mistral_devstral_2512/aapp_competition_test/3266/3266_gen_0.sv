module max_flow_solver #(
    parameter MAX_NODES = 8,
    parameter DATA_WIDTH = 32,
    parameter NODE_WIDTH = 3,
    parameter RESULT_WIDTH = 32,
    parameter MAX_AUGMENTATIONS = 16,
    parameter MAX_CYCLES = 10000
)(
    input clk,
    input rst_n,
    input start,
    
    // Configuration interface
    input [NODE_WIDTH-1:0] src_node,
    input [NODE_WIDTH-1:0] dst_node,
    input [NODE_WIDTH-1:0] edge_u,
    input [NODE_WIDTH-1:0] edge_v,
    input [DATA_WIDTH-1:0] edge_cap,
    input load_edge,
    
    // Results
    output reg done,
    output reg [RESULT_WIDTH-1:0] max_flow,
    
    // Edge flow output interface (activated after done)
    output reg [NODE_WIDTH-1:0] flow_src,
    output reg [NODE_WIDTH-1:0] flow_dst,
    output reg [DATA_WIDTH-1:0] flow_amount,
    output reg flow_valid,
    output reg flow_done
);

// Internal memory for capacity and flow matrices
reg [DATA_WIDTH-1:0] capacity [0:MAX_NODES-1][0:MAX_NODES-1];
reg [DATA_WIDTH-1:0] flow [0:MAX_NODES-1][0:MAX_NODES-1];

// BFS state registers
reg [NODE_WIDTH-1:0] queue [0:MAX_NODES-1];
reg [NODE_WIDTH-1:0] parent [0:MAX_NODES-1];
reg [MAX_NODES-1:0] visited;
reg [NODE_WIDTH-1:0] bfs_head, bfs_tail;
reg [NODE_WIDTH-1:0] path_nodes [0:MAX_NODES-1];  // For path reconstruction

// FSM state definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] LOAD = 4'd1;
localparam [3:0] BFS_INIT = 4'd2;
localparam [3:0] BFS_LOOP = 4'd3;
localparam [3:0] AUGMENT = 4'd4;
localparam [3:0] CHECK = 4'd5;
localparam [3:0] OUTPUT_INIT = 4'd6;
localparam [3:0] OUTPUT_LOOP = 4'd7;
localparam [3:0] COMPLETE = 4'd8;

reg [3:0] state;
reg [3:0] next_state;

// Computation counters
reg [NODE_WIDTH-1:0] current_node;
reg [NODE_WIDTH-1:0] neighbor;
reg [RESULT_WIDTH-1:0] augment_count;
reg [DATA_WIDTH-1:0] bottleneck;
reg [DATA_WIDTH-1:0] residual;

// Output state machine
reg [NODE_WIDTH-1:0] out_i, out_j;
reg [NODE_WIDTH-1:0] next_i, next_j;

// Internal control signals
reg bfs_done;
reg path_found;
reg [NODE_WIDTH-1:0] path_length;
reg [NODE_WIDTH-1:0] path_idx;

// Flow output control
reg output_active;
reg [NODE_WIDTH-1:0] scan_i, scan_j;

// ============================================================================
// STATE MACHINE LOGIC
// ============================================================================

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        // Reset matrices
        integer i, j;
        for (i = 0; i < MAX_NODES; i = i + 1) begin
            for (j = 0; j < MAX_NODES; j = j + 1) begin
                capacity[i][j] <= 0;
                flow[i][j] <= 0;
            end
        end
        // Reset output signals
        done <= 0;
        max_flow <= 0;
        flow_valid <= 0;
        flow_done <= 0;
        flow_src <= 0;
        flow_dst <= 0;
        flow_amount <= 0;
        augment_count <= 0;
        output_active <= 0;
    end else begin
        state <= next_state;
        
        case (state)
            LOAD: begin
                if (load_edge) begin
                    capacity[edge_u][edge_v] <= edge_cap;
                end
            end
            
            BFS_INIT: begin
                // Initialize BFS
                visited <= 0;
                visited[src_node] <= 1'b1;
                parent <= 0;
                parent[src_node] <= src_node;
                queue[0] <= src_node;
                bfs_head <= 0;
                bfs_tail <= 1;
                path_found <= 0;
            end
            
            BFS_LOOP: begin
                if (bfs_head < bfs_tail && !path_found) begin
                    current_node <= queue[bfs_head];
                    bfs_head <= bfs_head + 1;
                end
            end
            
            AUGMENT: begin
                if (path_found) begin
                    // Update flows along path
                    integer i;
                    for (i = 0; i < path_length - 1; i = i + 1) begin
                        flow[path_nodes[i]][path_nodes[i+1]] <= 
                            flow[path_nodes[i]][path_nodes[i+1]] + bottleneck;
                    end
                    max_flow <= max_flow + bottleneck;
                    augment_count <= augment_count + 1;
                end
            end
            
            OUTPUT_INIT: begin
                output_active <= 1'b1;
                scan_i <= 0;
                scan_j <= 0;
                flow_valid <= 0;
                flow_done <= 0;
            end
            
            OUTPUT_LOOP: begin
                if (scan_i < MAX_NODES) begin
                    if (scan_j < MAX_NODES) begin
                        // Output flow if non-zero
                        if (flow[scan_i][scan_j] > 0) begin
                            flow_src <= scan_i;
                            flow_dst <= scan_j;
                            flow_amount <= flow[scan_i][scan_j];
                            flow_valid <= 1'b1;
                        end else begin
                            flow_valid <= 1'b0;
                        end
                        // Increment to next column
                        if (scan_j == MAX_NODES - 1) begin
                            scan_j <= 0;
                            scan_i <= scan_i + 1;
                        end else begin
                            scan_j <= scan_j + 1;
                        end
                    end
                end else begin
                    // Done scanning all edges
                    flow_done <= 1'b1;
                    output_active <= 1'b0;
                end
            end
            
            COMPLETE: begin
                done <= 1'b1;
                flow_valid <= 1'b0;
            end
        endcase
    end
end

// ============================================================================
// NEXT STATE LOGIC
// ============================================================================

always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (load_edge) begin
                next_state = LOAD;
            end else if (start) begin
                next_state = BFS_INIT;
            end
        end
        
        LOAD: begin
            if (!load_edge) begin
                next_state = IDLE;
            end
        end
        
        BFS_INIT: begin
            next_state = BFS_LOOP;
        end
        
        BFS_LOOP: begin
            if (bfs_head >= bfs_tail) begin
                // Queue empty, no path found
                next_state = OUTPUT_INIT;
            end else if (current_node == dst_node) begin
                // Path found
                path_found = 1'b1;
                next_state = AUGMENT;
            end else begin
                // Process neighbors
                // (Neighborhood expansion logic would go here)
                // For simplicity, we assume neighbor processing happens in same cycle
                // In real implementation, this would need more states
                next_state = BFS_LOOP;
            end
        end
        
        AUGMENT: begin
            next_state = CHECK;
        end
        
        CHECK: begin
            if (augment_count >= MAX_AUGMENTATIONS) begin
                next_state = OUTPUT_INIT;
            end else begin
                // Check if more augmenting paths exist
                // For now, assume we continue
                next_state = BFS_INIT;
            end
        end
        
        OUTPUT_INIT: begin
            next_state = OUTPUT_LOOP;
        end
        
        OUTPUT_LOOP: begin
            if (scan_i >= MAX_NODES && scan_j == 0) begin
                next_state = COMPLETE;
            end else begin
                next_state = OUTPUT_LOOP;
            end
        end
        
        COMPLETE: begin
            // Stay in COMPLETE until reset
            next_state = COMPLETE;
        end
    endcase
end

// ============================================================================
// BFS NEIGHBOR PROCESSING (Combinational)
// ============================================================================

integer k;
always @(*) begin
    // Check all neighbors of current_node
    for (k = 0; k < MAX_NODES; k = k + 1) begin
        if (!visited[k] && capacity[current_node][k] > flow[current_node][k]) begin
            // Found reachable neighbor in residual graph
            visited[k] = 1'b1;
            parent[k] = current_node;
            queue[bfs_tail] = k;
            bfs_tail = bfs_tail + 1;
        end
    end
end

// ============================================================================
// PATH RECONSTRUCTION AND BOTTLENECK CALCULATION (Combinational)
// ============================================================================

integer p;
always @(*) begin
    if (path_found) begin
        // Reconstruct path from dst to src
        path_nodes[0] = dst_node;
        path_length = 1;
        path_idx = dst_node;
        
        while (path_idx != src_node && path_length < MAX_NODES) begin
            path_idx = parent[path_idx];
            path_nodes[path_length] = path_idx;
            path_length = path_length + 1;
        end
        
        // Reverse path to be src->dst
        for (p = 0; p < path_length/2; p = p + 1) begin
            path_nodes[p] = path_nodes[path_length-1-p];
            path_nodes[path_length-1-p] = path_nodes[p];
        end
        
        // Calculate bottleneck
        bottleneck = capacity[path_nodes[0]][path_nodes[1]] - flow[path_nodes[0]][path_nodes[1]];
        for (p = 1; p < path_length - 1; p = p + 1) begin
            residual = capacity[path_nodes[p]][path_nodes[p+1]] - flow[path_nodes[p]][path_nodes[p+1]];
            if (residual < bottleneck) bottleneck = residual;
        end
    end else begin
        bottleneck = 0;
        path_length = 0;
    end
end

endmodule